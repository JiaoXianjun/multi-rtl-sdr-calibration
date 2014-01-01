CFLAGS=-O3 -g -Wall -W `pkg-config --cflags librtlsdr`
LIBS=`pkg-config --libs librtlsdr` -lpthread -lm
CC=gcc
PROGNAME=rtl-sdr-relay

all: rtl-sdr-relay

%.o: %.c
	$(CC) $(CFLAGS) -c $<

rtl-sdr-relay: rtl-sdr-relay.o
	$(CC) -g -o rtl-sdr-relay rtl-sdr-relay.o $(LIBS)

clean:
	rm -f *.o rtl-sdr-relay
