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
#include <unistd.h>
#include <fcntl.h>

#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>

#include "rtl-sdr.h"

#define VERBOSE_UDP_SET_INFO

#ifdef VERBOSE_UDP_SET_INFO
  #define SHOW_UDP_RECV(CODE) CODE
#else
  #define SHOW_UDP_RECV(CODE)
#endif

#define MAX_NUM_PARA 7
#define MAX_NUM_DEV 4
#define DEFAULT_FREQ 1090000000
#define DEFAULT_GAIN 0
//#define DEFAULT_SAMPLE_RATE		2048000
#define DEFAULT_SAMPLE_RATE		3000000
#define MINIMAL_BUF_LENGTH		512
#define MAXIMAL_BUF_LENGTH		(256 * 16384)
//#define MAXIMAL_BUF_LENGTH		8192
#define DEFAULT_BUF_LENGTH		(16 * 16384)
//#define DEFAULT_BUF_LENGTH		8192

#define LEN_UDP_PACKET 32768
//#define LEN_UDP_PACKET 8192
#define DEFAULT_BEGIN_PORT 6666
#define DEFAULT_LOCAL_PORT 13485

// command line parameters types definitions
#define DEV 1001
#define PORT 1002
#define FREQ 1003
#define GAIN 1004
#define RATE 1005
#define BUF 1006
#define LEN 1007

static int do_exit = 0;
static rtlsdr_dev_t *dev[MAX_NUM_DEV] = { NULL };

int fd = 0;
struct sockaddr_in remote_addr[MAX_NUM_DEV];
struct sockaddr_in local_addr;
uint32_t sendto_flag = 0;

int real_device_count = 0;
int target_device_count = 0;

uint32_t frequency[MAX_NUM_DEV] = { DEFAULT_FREQ };
int gain[MAX_NUM_DEV] = {0};
uint32_t samp_rate[MAX_NUM_DEV] = { DEFAULT_SAMPLE_RATE };
uint32_t dev_index[MAX_NUM_DEV] = {0};
uint32_t udp_port[MAX_NUM_DEV] = {0};
uint32_t out_block_size[MAX_NUM_DEV] = { DEFAULT_BUF_LENGTH };
uint32_t sendto_len[MAX_NUM_DEV] = { LEN_UDP_PACKET };

// catch user's Ctrl+C event
static void sighandler(void)
{
	fprintf(stderr, "Signal caught, exiting!\n");
	do_exit = 1;
}

// display usage information and then exit program.
void usage(void)
{
	printf(
		"\nrtl-sdr-relay, a UDP I/Q relay for multiple RTL2832 based DVB-T receivers\n\n"
		"example: ./rtl-sdr-relay -f 409987500 1090000000 -g 30 50 -s 2000000 1000000 -d 0 1 -p 6666 6667 -b 65536 131072 -l 16384 32768\n\n"
		"Usage:\t-f: multi-frequencies for multi-dongles[Hz]. If not specified, 1090000000 will be set as default.\n"
		"\t-g: multi-gains for multi-dongles[dB]. If not specified, automatic gain will be set as default.\n"
		"\t-s: multi-sample-rates for multi-dongles[Hz]. If not specified, 3000000 will be set as default.\n"
		"\t-d: device IDs. If not specified, all detected dongles will be involved.\n"
		"\t-p: UDP ports. If not specified, ports will be used begining with 6666,\n"
		"\t    for example, 6666, 6667, 6668.... The number of ports must be equal to the number of dongles or\n"
		"\t    the number of dongles counted from -d option.\n"
		"\t-b: multi-buffer-lengths for reading IQ from multi-dongles. If not specified, default value is 262144.\n"
		"\t-l: multi-length-of-UDP-packets for multi-dongles. If not specified, default value is 32768.\n"
		"\tSome parameters can be set by receiving UDP instruction packet. See README.\n"
		"\n\tPress Ctrl+C to exit the relay program\n\n");
	exit(1);
}

// fill frequency, gain, samp_rate, dev_index, udp_port, out_block_size, sendto_len by parsing command line parameters
void parse_arg(int argc, char **argv)
{
  int i = 0;
  int j = 0;
  int para_idx_set[MAX_NUM_PARA+1] = {-1};
  int num_val_set[MAX_NUM_PARA+1] = {-1};
  long int para_val_set[MAX_NUM_PARA+1][MAX_NUM_DEV];
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
        printf("Output block size (rtl-sdr buffer size) wrong value, falling back to default\n");
        printf("Minimal length: %u\n", MINIMAL_BUF_LENGTH);
        printf("Maximal length: %u\n", MAXIMAL_BUF_LENGTH);
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
        printf("UDP packet size wrong value, falling back to default\n");
        printf("Minimal length: %u\n", 1);
        printf("Maximal length: %u\n", LEN_UDP_PACKET);
        sendto_len[j] = LEN_UDP_PACKET;
      }
    }
    for ( ; j < target_device_count; j++ )
    {
      sendto_len[j] = sendto_len[j-1];
    }
  }

  for ( i = 0; i < target_device_count; i++ )
  {
    if ( out_block_size[i]%sendto_len[i] != 0 )
    {
      printf("rtl-sdr buffer size must be integer times of UDP packet length!\n");
      printf("Actual: buffer size %d packet length %d\n", out_block_size[i], sendto_len[i]);
      usage();
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
  struct sigaction sigact;
  const char *default_inet_addr = "127.0.0.1";
  int i;
	int n_read_set[MAX_NUM_DEV];
	int r, r_set[MAX_NUM_DEV];
	uint8_t *buffer[MAX_NUM_DEV];
	int device_count;
	char vendor[256], product[256], serial[256];

	real_device_count = rtlsdr_get_device_count(); // real_device_count will be used in parse_arg()
	if (!real_device_count) {
		printf("No supported devices found.\n");
		usage();
		exit(1);
	}

	parse_arg(argc, argv);

  for ( i = 0; i < target_device_count; i++ )
  {
    buffer[i] = malloc(out_block_size[i] * sizeof(uint8_t));
  }

	device_count = target_device_count; // get actual number of dongles we want to use

	printf("Will proceed with %d device(s):\n", device_count);
	for (i = 0; i < device_count; i++) {
		rtlsdr_get_device_usb_strings(dev_index[i], vendor, product, serial);
		printf("  %d:  %s, %s, SN: %s\n", dev_index[i], vendor, product, serial);
	}
	printf("\n");

  for (i = 0; i < device_count; i++) {
    printf("Using device %d: %s\n",
      dev_index[i], rtlsdr_get_device_name(dev_index[i]));
  }

  // create socket for UDP
  fd = socket(AF_INET,SOCK_DGRAM,0);
  if(fd==-1)
  {
      perror("socket");
      exit(-1);
  }

  // set socket to non blocking mode to ensure UDP recvfrom won't affect performance.
  int nFlags = fcntl(fd, F_GETFL, 0);
  nFlags |= O_NONBLOCK;
  if (fcntl(fd, F_SETFL, nFlags) == -1)
  {
    perror("Set socket to non blocking.");
    exit(-1);
  }
  printf("create socket OK!\n");

  //create send addresses for multiple devices
  for ( i = 0; i < target_device_count; i++ ){
    remote_addr[i].sin_family = AF_INET;
    remote_addr[i].sin_port = htons(udp_port[i]);
    remote_addr[i].sin_addr.s_addr=inet_addr(default_inet_addr);
  }
  local_addr.sin_family = AF_INET;
  local_addr.sin_port = htons( DEFAULT_LOCAL_PORT );
  local_addr.sin_addr.s_addr=inet_addr(default_inet_addr);

  if (bind(fd, (struct sockaddr *)&local_addr, sizeof(local_addr)) < 0) {
    perror("bind failed");
    exit(-1);
  }
  printf("Bind socket to local_addr successfully!\n");

  sigact.sa_handler = (__sighandler_t)sighandler;
	sigemptyset(&sigact.sa_mask);
	sigact.sa_flags = 0;
	sigaction(SIGINT, &sigact, NULL);
	sigaction(SIGTERM, &sigact, NULL);
	sigaction(SIGQUIT, &sigact, NULL);
	sigaction(SIGPIPE, &sigact, NULL);

  // open and set multiple dongles
  for (i = 0; i < device_count; i++) {
    r = rtlsdr_open(&(dev[i]), dev_index[i]);
    if (r < 0) {
      printf("Failed to open rtlsdr device #%d.\n", dev_index[i]);
      exit(1);
    }

    /* Set the sample rate */
    r = rtlsdr_set_sample_rate(dev[i], samp_rate[i]);
    if (r < 0)
      printf("WARNING: Failed to set sample rate. Device %d\n", i);
    else
      printf("Sampling rate set to %d Hz. Device %d\n", samp_rate[i], i);

    /* Set the frequency */
    r = rtlsdr_set_center_freq(dev[i], frequency[i]);
    if (r < 0)
      printf("WARNING: Failed to set center freq. Device %d\n", i);
    else
      printf("Tuned to %u Hz. Device %d\n", frequency[i], i);

    /* Set the gain */
    if (0 == gain[i]) {
       /* Enable automatic gain */
      r = rtlsdr_set_tuner_gain_mode(dev[i], 0);
      if (r < 0)
        printf("WARNING: Failed to enable automatic gain. Device %d\n", i);
      else
        printf("Automatic gain. Device %d\n", i);
    } else {
      /* Enable manual gain */
      r = rtlsdr_set_tuner_gain_mode(dev[i], 1);
      if (r < 0)
        printf("WARNING: Failed to enable manual gain. Device %d\n", i);

      /* Set the tuner gain */
      r = rtlsdr_set_tuner_gain(dev[i], gain[i]);
      if (r < 0)
        printf("WARNING: Failed to set tuner gain. Device %d\n", i);
      else
        printf("Tuner gain set to %f dB. Device %d\n", gain[i]/10.0, i);
    }

    /* Reset endpoint before we start reading from it (mandatory) */
    r = rtlsdr_reset_buffer(dev[i]);
    if (r < 0)
      printf("WARNING: Failed to reset buffers. Device %d\n", i);

  }

  printf("Reading samples in sync mode...\n");
  printf("\nPress Ctrl+C to exit.\n");

  socklen_t addrlen = sizeof(remote_addr[0]);

  // array to store received UPD config packet
  // 3 stands for frequency gain samp_rate
  int recv_val[3*MAX_NUM_DEV] = { 0 };

  while (!do_exit) {
    // receive frequency gain and samp_rate values from remote and set to corresponding dongles
    int recvlen = recvfrom(fd, recv_val, sizeof(int)*3*device_count, 0, (struct sockaddr*)&(remote_addr[0]), &addrlen);

    int set_flag = 0;
    // all dongles will be set with the same configuration
    if ( recvlen == 3*sizeof(int) )
    {
      int recv_val_freq = ntohl(recv_val[0]);
      int recv_val_gain = ntohl(recv_val[1]);
      int recv_val_rate = ntohl(recv_val[2]);

      for (i = 0; i < device_count; i++) {
        frequency[i] = recv_val_freq;
        gain[i] = 10*recv_val_gain;
        samp_rate[i] = recv_val_rate;
      }
      set_flag = 1;
    }
    else if ( recvlen == (int)(3*sizeof(int)*device_count) ) // each dongle will get its own configuration
    {
      int j = 0;
      for (i = 0; i < device_count; i++) {
        frequency[i] = ntohl(recv_val[j++]);
        gain[i] = 10*ntohl(recv_val[j++]);
        samp_rate[i] = ntohl(recv_val[j++]);
      }
      set_flag = 1;
    }

    if (set_flag)
    {
      /* Set the frequency gain and sampling rate*/
      for (i = 0; i < device_count; i++) {
        /* Set the frequency */
        r = rtlsdr_set_center_freq(dev[i], frequency[i]);
        if (r < 0)
          printf("WARNING: Failed to set center freq. Device %d\n", i);
        else
          SHOW_UDP_RECV( printf("Tuned to %u Hz. Device %d\n", frequency[i], i); )

        /* Set the gain */
        if (0 == gain[i]) {
           /* Enable automatic gain */
          r = rtlsdr_set_tuner_gain_mode(dev[i], 0);
          if (r < 0)
            printf("WARNING: Failed to enable automatic gain. Device %d\n", i);
          SHOW_UDP_RECV( else )
            SHOW_UDP_RECV( printf("Automatic gain. Device %d\n", i); )
        } else {
          /* Enable manual gain */
          r = rtlsdr_set_tuner_gain_mode(dev[i], 1);
          if (r < 0)
            printf("WARNING: Failed to enable manual gain. Device %d\n", i);

          /* Set the tuner gain */
          r = rtlsdr_set_tuner_gain(dev[i], gain[i]);
          if (r < 0)
            printf("WARNING: Failed to set tuner gain. Device %d\n", i);
          SHOW_UDP_RECV( else )
            SHOW_UDP_RECV( printf("Tuner gain set to %f dB. Device %d\n", gain[i]/10.0, i); )
        }

        /* Set the sample rate */
        r = rtlsdr_set_sample_rate(dev[i], samp_rate[i]);
        if (r < 0)
          printf("WARNING: Failed to set sample rate. Device %d\n", i);
        else
          SHOW_UDP_RECV( printf("Sampling rate set to %d Hz. Device %d\n", samp_rate[i], i); )

        r = rtlsdr_reset_buffer(dev[i]);
        if (r < 0)
          printf("WARNING: Failed to reset buffers. Device %d\n", i);
      }
    }

    // read multiple dongles I&Q data into multiple buffers
    for (i = 0; i < device_count; i++) {
      r_set[i] = rtlsdr_read_sync(dev[i], buffer[i], out_block_size[i], &(n_read_set[i]));
    }

    // check if read operation is normal
    int r_flag = 0;
    for (i = 0; i < device_count; i++) {
      r_flag = r_flag + (r_set[i] < 0);
    }
    if (r_flag) {
      printf("WARNING: sync read failed.\n");
      break;
    }

    // check if read operation is normal
    int n_read_flag = 0;
    for (i = 0; i < device_count; i++) {
      n_read_flag = n_read_flag + ((uint32_t)n_read_set[i] < out_block_size[i]);
    }
    if (n_read_flag) {
      printf("Short read, samples lost, exiting!\n");
      //break;
    }

    // send different buffers data through different UDP ports to localhost
    int send_send_flag = 0;
    for (i = 0; i < device_count; i++) {
      uint32_t buf_position = 0;
      int send_flag = 0;
      // because buffer length is bigger than UDP packet length, the data from one buffer will be sent by multiple times.
      for ( buf_position = 0; buf_position < out_block_size[i]; buf_position = buf_position + sendto_len[i]) {
        uint32_t sendto_flag = sendto(fd, buffer[i]+buf_position, sendto_len[i], 0, (struct sockaddr*)&(remote_addr[i]), sizeof(remote_addr[i]));
        send_flag = send_flag + ( sendto_flag != sendto_len[i]);
      }
      send_send_flag = send_send_flag + send_flag;
    }
    // check if send operation is normal
    if (send_send_flag) {
      printf( "Short write, samples lost, exiting!\n");
      //break;
    }
  }

  if (do_exit)
    printf("\nwhile(1) loop exits by user. exiting...\n");
  else
    printf("\nwhile(1) loop exits abnormally. exiting...\n");

  for (i = 0; i < device_count; i++) {
    rtlsdr_close(dev[i]);
    free (buffer[i]);
	}

  close(fd);

  printf("Done!\n");

  return(0);
}
