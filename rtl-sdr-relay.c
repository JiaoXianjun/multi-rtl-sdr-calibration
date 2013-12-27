// Jiao Xianjun (putaoshu@msn.com; putaoshu@gmail.com)
//
// Relay multiple rtl-sdr dongles IQ samples out by UDP packets for easy real-time use in Matlab or other program.
// Different dongles IQ samples are sent through different UDP ports.
// Currently, it is only tested in Ubuntu Linux (12.04 LTS), and only relay to localhost/host-computer.
// Some codes are copied/modified from rtl-sdr: http://sdr.osmocom.org/trac/wiki/rtl-sdr

// original rtl-sdr header
/*
 * rtl-sdr, turns your Realtek RTL2832 based DVB dongle into a SDR receiver
 * Copyright (C) 2012 by Steve Markgraf <steve@steve-m.de>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

#include <errno.h>
#include <signal.h>
#include <string.h>
#include <stdio.h>
#include <stdlib.h>
//-----------------------
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
//-----------------------

#include "rtl-sdr.h"

#define MAX_NUM_PARA 7
#define MAX_NUM_DEV 8
#define DEFAULT_FREQ 1090000000
#define DEFAULT_GAIN 0
#define DEFAULT_SAMPLE_RATE		2048000
#define DEFAULT_BUF_LENGTH		(16 * 16384)
#define MINIMAL_BUF_LENGTH		512
#define MAXIMAL_BUF_LENGTH		(256 * 16384)

#define LEN_UDP_PACKET 32768
#define DEFAULT_BEGIN_PORT 6666

static int do_exit = 0;
static uint32_t bytes_to_read = 0;
static rtlsdr_dev_t *dev[MAX_NUM_DEV] = { NULL };

//---------------------------------------------
int fd = 0;
struct sockaddr_in addr = {0};
uint32_t buf_offset = 0;
uint32_t sendto_flag = 0;

//---------------------------------------------

void usage(void)
{
	fprintf(stderr,
		"\nrtl-sdr-relay, a UDP I/Q relay for multiple RTL2832 based DVB-T receivers\n\n"
		"example: ./rtl-sdr-relay -f 409987500 1090000000 -g 30 50 -s 2000000 1000000 -d 0 1 -p 6666 6667 -b 65536 131072 -l 16384 32768\n\n"
		"Usage:\t-f: multi-frequencies for multi-dongles[Hz]. If not specified, 1090000000 will be set as default.\n"
		"\t-g: multi-gains for multi-dongles[dB]. If not specified, automatic gain will be set as default.\n"
		"\t-s: multi-sample-rates for multi-dongles[Hz]. If not specified, 2048000 will be set as default.\n"
		"\t-d: device IDs. If not specified, all detected dongles will be involved.\n"
		"\t-p: UDP ports. If not specified, ports will be used begining with 6666,\n"
		"\t    for example, 6666, 6667, 6668.... The number of ports must be equal to the number of dongles or\n"
		"\t    the number of dongles counted from -d option.\n"
		"\t-b: multi-buffer-lengths for reading IQ from multi-dongles. If not specified, default value is 262144.\n"
		"\t-l: multi-length-of-UDP-packets for multi-dongles. If not specified, default value is 32768.\n\n");
	exit(1);
}

//static void rtlsdr_callback(unsigned char *buf, uint32_t len, void *ctx)
//{
//	if (ctx) {
//		if (do_exit)
//			return;
//
//		if ((bytes_to_read > 0) && (bytes_to_read < len)) {
//			len = bytes_to_read;
//			do_exit = 1;
//			rtlsdr_cancel_async(dev);
//		}
//
////		if (fwrite(buf, 1, len, (FILE*)ctx) != len) {
//
////    buf_offset=0;
////    while (buf_offset<len) // len always is 262144
////    {
////      sendto_len = ( (buf_offset+LEN_UDP_PACKET) <= len)? LEN_UDP_PACKET : (len-buf_offset);
////
//////      fprintf(stderr, "%u %u %u\n", len, buf_offset, sendto_len);
////
////      if ( ( sendto_flag=sendto(fd, buf + buf_offset, sendto_len, 0, (struct sockaddr*)&addr,sizeof(addr)) ) != sendto_len) {
////        fprintf(stderr, "Short write, samples lost, exiting! %u %u %u\n", sendto_len, sendto_flag, buf_offset);
////        rtlsdr_cancel_async(dev);
////        break;
////      }
////      buf_offset = buf_offset + sendto_len;
////    }
//
//    sendto_len = LEN_UDP_PACKET;
//    if ( ( sendto_flag=sendto(fd, buf, sendto_len, 0, (struct sockaddr*)&addr,sizeof(addr)) ) != sendto_len) {
//      fprintf(stderr, "Short write, samples lost, exiting! %u %u\n", sendto_len, sendto_flag);
//      rtlsdr_cancel_async(dev);
//    }
//
//		if (bytes_to_read > 0)
//			bytes_to_read -= len;
//	}
//}

int real_device_count = 0;
int target_device_count = 0;

uint32_t frequency[MAX_NUM_DEV] = { DEFAULT_FREQ };
int gain[MAX_NUM_DEV] = {0};
uint32_t samp_rate[MAX_NUM_DEV] = { DEFAULT_SAMPLE_RATE };
uint32_t dev_index[MAX_NUM_DEV] = {0};
uint32_t udp_port[MAX_NUM_DEV] = {0};
uint32_t out_block_size[MAX_NUM_DEV] = { DEFAULT_BUF_LENGTH };
uint32_t sendto_len[MAX_NUM_DEV] = { LEN_UDP_PACKET };

// TYPE definition
#define DEV 1001
#define PORT 1002
#define FREQ 1003
#define GAIN 1004
#define RATE 1005
#define BUF 1006
#define LEN 1007

void parse_arg(int argc, char **argv)
{
  int i = 0;
  int j = 0;
  int para_idx_set[MAX_NUM_PARA+1] = {-1};
  int num_val_set[MAX_NUM_PARA+1] = {-1};
  long int para_val_set[MAX_NUM_PARA+1][MAX_NUM_DEV] = {-1};
  int para_type_set[MAX_NUM_PARA+1] = {-1};

  int para_count = 0;
  for ( i = 1; i < argc; i++ )
  {
    if ( argv[i][0] == '-' )
    {
      if ( para_count == MAX_NUM_PARA )
      {
        printf("Maximum allowed number of input parameters is 7!\n\n");
        usage();
      }

      switch (argv[i][1]) {
      case 'd':
        {
          para_idx_set[para_count] = i;
          para_type_set[para_count] = DEV;
        }
        break;
      case 'p':
        {
          para_idx_set[para_count] = i;
          para_type_set[para_count] = PORT;
        }
        break;
      case 'f':
        {
          para_idx_set[para_count] = i;
          para_type_set[para_count] = FREQ;
        }
        break;
      case 'g':
        {
          para_idx_set[para_count] = i;
          para_type_set[para_count] = GAIN;
        }
        break;
      case 's':
        {
          para_idx_set[para_count] = i;
          para_type_set[para_count] = RATE;
        }
        break;
      case 'b':
        {
          para_idx_set[para_count] = i;
          para_type_set[para_count] = BUF;
        }
        break;
      case 'l':
        {
          para_idx_set[para_count] = i;
          para_type_set[para_count] = LEN;
        }
        break;
      default:
        printf("Invalid parameters!\n\n");
        printf("They should be from -d, -p, -f, -g, -s, -b, or -l!\n\n");
        usage();
        break;
      }

      para_count ++ ;

    }
  }

  printf("Number of input types of parameters: %d\n", para_count);

  // virtual one for convenience
  para_idx_set[para_count] = argc;
  para_type_set[para_count] = -1;

  for ( i = 0; i < para_count; i++ )
  {
    int start_idx = para_idx_set[i] + 1;
    int end_idx = para_idx_set[i+1];

    num_val_set[i] = 0;
    for ( j = start_idx; j < end_idx; j++ )
    {
      para_val_set[i][ num_val_set[i] ] = (long int)atof(argv[j]);
      num_val_set[i]++;
    }

    if (num_val_set[i] == 0)
    {
      printf("Some values of specific parameter are missing!\n");
      usage();
    }
  }

  // set device idx information
  for ( i = 0; i < para_count; i++ )
  {
    if (para_type_set[i] == DEV)
      break;
  }

  if ( i == para_count )
  {
    target_device_count = real_device_count;
    for ( j = 0; j < target_device_count; j++ )
    {
      dev_index[j] = (uint32_t)j;
    }
  }
  else
  {
    target_device_count = num_val_set[i];
    if ( target_device_count > real_device_count )
    {
      printf("The number of attached dongles is less than your expectation!\n");
      usage();
    }

    for ( j = 0; j < num_val_set[i]; j++ )
    {
      if ( para_val_set[i][j] >= real_device_count )
      {
        printf("Given device idx exceeds the actual attached dongles!\n");
        usage();
      }
      dev_index[j] = para_val_set[i][j];
    }
  }

  // set UDP ports information
  for ( i = 0; i < para_count; i++ )
  {
    if (para_type_set[i] == PORT)
      break;
  }
  if ( i == para_count )
  {
    for ( j = 0; j < target_device_count; j++ )
    {
      udp_port[j] = DEFAULT_BEGIN_PORT + j;
    }
  }
  else
  {
    for ( j = 0; j < num_val_set[i]; j++ )
    {
      udp_port[j] = para_val_set[i][j];
    }
    for ( ; j < target_device_count; j++ )
    {
      udp_port[j] = udp_port[j-1]+1;
    }
  }

  // set frequencies information
  for ( i = 0; i < para_count; i++ )
  {
    if (para_type_set[i] == FREQ)
      break;
  }
  if ( i == para_count )
  {
    for ( j = 0; j < target_device_count; j++ )
    {
      frequency[j] = DEFAULT_FREQ;
    }
  }
  else
  {
    for ( j = 0; j < num_val_set[i]; j++ )
    {
      frequency[j] = para_val_set[i][j];
    }
    for ( ; j < target_device_count; j++ )
    {
      frequency[j] = frequency[j-1];
    }
  }

  // set gains information
  for ( i = 0; i < para_count; i++ )
  {
    if (para_type_set[i] == GAIN)
      break;
  }
  if ( i == para_count )
  {
    for ( j = 0; j < target_device_count; j++ )
    {
      gain[j] = DEFAULT_GAIN*10;
    }
  }
  else
  {
    for ( j = 0; j < num_val_set[i]; j++ )
    {
      gain[j] = para_val_set[i][j]*10;
    }
    for ( ; j < target_device_count; j++ )
    {
      gain[j] = gain[j-1];
    }
  }

  // set sampling rate information
  for ( i = 0; i < para_count; i++ )
  {
    if (para_type_set[i] == RATE)
      break;
  }
  if ( i == para_count )
  {
    for ( j = 0; j < target_device_count; j++ )
    {
      samp_rate[j] = DEFAULT_SAMPLE_RATE;
    }
  }
  else
  {
    for ( j = 0; j < num_val_set[i]; j++ )
    {
      samp_rate[j] = para_val_set[i][j];
    }
    for ( ; j < target_device_count; j++ )
    {
      samp_rate[j] = samp_rate[j-1];
    }
  }

  // set rtl-sdr buffer size information
  for ( i = 0; i < para_count; i++ )
  {
    if (para_type_set[i] == BUF)
      break;
  }
  if ( i == para_count )
  {
    for ( j = 0; j < target_device_count; j++ )
    {
      out_block_size[j] = DEFAULT_BUF_LENGTH;
    }
  }
  else
  {
    for ( j = 0; j < num_val_set[i]; j++ )
    {
      out_block_size[j] = para_val_set[i][j];

      if(out_block_size[j] < MINIMAL_BUF_LENGTH ||
         out_block_size[j] > MAXIMAL_BUF_LENGTH ){
        fprintf(stderr,
          "Output block size (rtl-sdr buffer size) wrong value, falling back to default\n");
        fprintf(stderr,
          "Minimal length: %u\n", MINIMAL_BUF_LENGTH);
        fprintf(stderr,
          "Maximal length: %u\n", MAXIMAL_BUF_LENGTH);
        out_block_size[j] = DEFAULT_BUF_LENGTH;
      }
    }
    for ( ; j < target_device_count; j++ )
    {
      out_block_size[j] = out_block_size[j-1];
    }
  }

  // set udp packet length information
  for ( i = 0; i < para_count; i++ )
  {
    if (para_type_set[i] == LEN)
      break;
  }
  if ( i == para_count )
  {
    for ( j = 0; j < target_device_count; j++ )
    {
      sendto_len[j] = LEN_UDP_PACKET;
    }
  }
  else
  {
    for ( j = 0; j < num_val_set[i]; j++ )
    {
      sendto_len[j] = para_val_set[i][j];

      if(sendto_len[j] <= 0 ||
         sendto_len[j] > LEN_UDP_PACKET ){
        fprintf(stderr,
          "UDP packet size wrong value, falling back to default\n");
        fprintf(stderr,
          "Minimal length: %u\n", 1);
        fprintf(stderr,
          "Maximal length: %u\n", LEN_UDP_PACKET);
        sendto_len[j] = LEN_UDP_PACKET;
      }
    }
    for ( ; j < target_device_count; j++ )
    {
      sendto_len[j] = sendto_len[j-1];
    }
  }

  // show parse results
  printf("\n-----------------------------------------\n");
  printf("         Frequencies ");
  for ( i = 0; i < target_device_count; i++ )
  {
    printf("%13d ", frequency[i]);
  }
  printf("\n");

  printf("               Gains ");
  for ( i = 0; i < target_device_count; i++ )
  {
    printf("%13d ", gain[i]/10);
  }
  printf("\n");

  printf("      Sampling rates ");
  for ( i = 0; i < target_device_count; i++ )
  {
    printf("%13d ", samp_rate[i]);
  }
  printf("\n");

  printf("      Device indexes ");
  for ( i = 0; i < target_device_count; i++ )
  {
    printf("%13d ", dev_index[i]);
  }
  printf("\n");

  printf("           UDP ports ");
  for ( i = 0; i < target_device_count; i++ )
  {
    printf("%13d ", udp_port[i]);
  }
  printf("\n");

  printf("rtl-sdr buffer sizes ");
  for ( i = 0; i < target_device_count; i++ )
  {
    printf("%13d ", out_block_size[i]);
  }
  printf("\n");

  printf("  UDP packet lengths ");
  for ( i = 0; i < target_device_count; i++ )
  {
    printf("%13d ", sendto_len[i]);
  }
  printf("\n");
  printf("\n-----------------------------------------\n");
}

int main(int argc, char **argv)
{
  const char *default_inet_addr = "127.0.0.1";
  int i;
	int n_read;
	int r, opt;
	uint8_t *buffer[MAX_NUM_DEV];
	int device_count;
	char vendor[256], product[256], serial[256];

	real_device_count = rtlsdr_get_device_count();
	if (!real_device_count) {
		fprintf(stderr, "No supported devices found.\n");
		usage();
		exit(1);
	}

	parse_arg(argc, argv);

  for ( i = 0; i < target_device_count; i++ )
  {
    buffer[i] = malloc(out_block_size[i] * sizeof(uint8_t));
  }

	device_count = target_device_count;

	fprintf(stderr, "Will proceed with %d device(s):\n", device_count);
	for (i = 0; i < device_count; i++) {
		rtlsdr_get_device_usb_strings(dev_index[i], vendor, product, serial);
		fprintf(stderr, "  %d:  %s, %s, SN: %s\n", dev_index[i], vendor, product, serial);
	}
	fprintf(stderr, "\n");

  for (i = 0; i < device_count; i++) {
    fprintf(stderr, "Using device %d: %s\n",
      dev_index[i], rtlsdr_get_device_name(dev_index[i]));
  }

//--------------------------------------------------
  fd = socket(AF_INET,SOCK_DGRAM,0);
  if(fd==-1)
  {
      perror("socket");
      exit(-1);
  }
  fprintf(stderr, "create socket OK!\n");

  //create an send address
  addr.sin_family = AF_INET;
  addr.sin_port = htons(udp_port[0]); // will be set runtimely in following program
  addr.sin_addr.s_addr=inet_addr(default_inet_addr);
//--------------------------------------------------

  for (i = 0; i < device_count; i++) {
    r = rtlsdr_open(&(dev[i]), dev_index[i]);
    if (r < 0) {
      fprintf(stderr, "Failed to open rtlsdr device #%d.\n", dev_index[i]);
      exit(1);
    }

    /* Set the sample rate */
    r = rtlsdr_set_sample_rate(dev[i], samp_rate[i]);
    if (r < 0)
      fprintf(stderr, "WARNING: Failed to set sample rate.\n");

    /* Set the frequency */
    r = rtlsdr_set_center_freq(dev[i], frequency[i]);
    if (r < 0)
      fprintf(stderr, "WARNING: Failed to set center freq.\n");
    else
      fprintf(stderr, "Tuned to %u Hz.\n", frequency[i]);

    /* Set the gain */
    if (0 == gain[i]) {
       /* Enable automatic gain */
      r = rtlsdr_set_tuner_gain_mode(dev[i], 0);
      if (r < 0)
        fprintf(stderr, "WARNING: Failed to enable automatic gain.\n");
    } else {
      /* Enable manual gain */
      r = rtlsdr_set_tuner_gain_mode(dev[i], 1);
      if (r < 0)
        fprintf(stderr, "WARNING: Failed to enable manual gain.\n");

      /* Set the tuner gain */
      r = rtlsdr_set_tuner_gain(dev[i], gain[i]);
      if (r < 0)
        fprintf(stderr, "WARNING: Failed to set tuner gain.\n");
      else
        fprintf(stderr, "Tuner gain set to %f dB.\n", gain[i]/10.0);
    }

    /* Reset endpoint before we start reading from it (mandatory) */
    r = rtlsdr_reset_buffer(dev[i]);
    if (r < 0)
      fprintf(stderr, "WARNING: Failed to reset buffers.\n");

  }

  fprintf(stderr, "Reading samples in sync mode...\n");

//  while (!do_exit) {
//    r = rtlsdr_read_sync(dev, buffer, out_block_size, &n_read);
//    if (r < 0) {
//      fprintf(stderr, "WARNING: sync read failed.\n");
//      break;
//    }
//
//    if ((bytes_to_read > 0) && (bytes_to_read < (uint32_t)n_read)) {
//      n_read = bytes_to_read;
//      do_exit = 1;
//    }
//
//    if ((uint32_t)n_read < out_block_size) {
//      fprintf(stderr, "Short read, samples lost, exiting!\n");
//      break;
//    }
//
//    if (bytes_to_read > 0)
//      bytes_to_read -= n_read;
//  }

	if (do_exit)
		fprintf(stderr, "\nUser cancel, exiting...\n");
	else
		fprintf(stderr, "\nLibrary error %d, exiting...\n", r);

  for (i = 0; i < device_count; i++) {
    rtlsdr_close(dev[i]);
    free (buffer[i]);
    close(fd);
	}

  return(-1);
}
