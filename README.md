multi-rtl-sdr-udp-relay README
By a enthusiast of Software Defined Radio.
putaoshu@msn.com
putaoshu@gmail.com
=======================
Relay multiple rtl-sdr dongles IQ samples out by UDP packets for easy real-time use in Matlab or other program.
Different dongles IQ samples are sent through different UDP ports.
Currently, it is only tested in Ubuntu Linux (12.04 LTS), and only relay to localhost/host-computer.
Some codes are copied/modified from rtl-sdr: http://sdr.osmocom.org/trac/wiki/rtl-sdr

Build
=======================
Open a shell/command-line, and enter the directory where there is Makefile.
Type "make".


Usage
=======================
./rtl-sdr-relay -f 409987500 -g 30 -d 0 1 -p 6666 6667 -b 65536 -l 16384
-f: frequency in Hz. If not specified, 1090000000 will be set as default.
-g: gain value. If not specified, maximum gain will be set as default.
-d: device IDs. If not specified, all detected dongles will be involved.
-p: UDP ports. If not specified, ports will be used begining with 6666, for example, 6666, 6667, 6668.... The number of ports must be equal to the number of dongles or the number of dongles counted from -d option.
-b: buffer length for reading IQ from dongle. If not specified, default value is 262144.
-l: length of UDP packet. If not specified, default value is 32768.

./rtl-sdr-relay
display help/usage

In matlab, you may receive and process UDP packets like this:

udp_obj = udp('127.0.0.1', 10000, 'LocalPort', 6666);
fread_len = 8192; % max allowed
set(udp_obj, 'InputBufferSize', fread_len);
set(udp_obj, 'Timeout', 1);
fopen(udp_obj);
while 1
    [a, real_count] = fread(udp_obj, fread_len, 'uint8');
    if real_count<fread_len
        continue;
    end

    //process samples in varable "a"
    ....
end

See detail script in recv_proc_udp.m

Contributing
=======================
multi-rtl-sdr-udp-relay was written during the end of 2013 in my spare time. 
You are welcome to send pull requests in order to improve the project.
See TODO list included in the source distribution first (If you want).
