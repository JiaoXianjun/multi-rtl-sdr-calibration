Multiple rtl-sdr(rtl_tcp) dongles based GSM FCCH scanner. (putaoshu@gmail.com; putaoshu@msn.com)

multi_rtl_sdr_gsm_FCCH_scanner.m
Have multiple dongles run concurrently to speedup detecting FCCH(Frequency correction channel) burst in wide GSM band by scanning different sub-band with different dongle.

This is a sub script of project: https://github.com/JiaoXianjun/multi-rtl-sdr-calibration

------------Purpose------------
The original purpose of project multi-rtl-sdr-calibration is that calibrating multiple dongles by the common GSM source.
So the first thing need to do is that finding out where is the strongest GSM signal in the air.
This script can identify GSM downlink broadcasting carrier by detecting successive multiple FCCH burst.
I learn knowledge of GSM frame structure from here: http://www.sharetechnote.com/html/FrameStructure_GSM.html
After the script is run, quality metrics of detected FCCH channel will be displayed: SNR and number of detected FCCH burst (num of hits).
Note: for speedup detection algorithm, a large decimation ratio is used, thus shown SNR may be lower than actual SNR. But it is enough to help us idendify which frequency is best.

-------------Usage-------------
1. Assume that you have installed rtl-sdr
(http://sdr.osmocom.org/trac/wiki/rtl-sdr) and have those native utilities run correctly already.

For example, you have multiple dongles, please run multiple rtl_tcp in multiple shell respectively as:
rtl_tcp -p 1234 -d 0
rtl_tcp -p 1235 -d 1
rtl_tcp -p 1236 -d 2
...

2. Then run multi_rtl_sdr_gsm_FCCH_scanner.m in MATLAB.

ATTENTION! In some computer, each time before you run script, maybe you need to terminate multiple rtl_tcp and re-launch them again.
ATTENTION! Please reduce number of inspected points by reducing frequency range, if your computer hasn't enough memory installed. Because all sigals are stored firstly before processing.

Change following parameters in the script as you need:

num_dongle = 1; % number of dongles you installed
start_freq = 935e6;
end_freq = 960e6;
freq_step = 0.2e6; % GSM channel spacing
gain = 0;
...

Some key parameters:
% how long signal we try to find multiple FCCH bursts in
num_frame = 64; % roughly speaking, there are 1 FCCH burst per 10 frames, but 50 frames plus 1 idle frame construct one multiframe

FCCH_coarse_position.m
th = 10; % Peak to average threshold of detecting FCCH in moving averaging SNR(estimated by FFT) stream.
max_offset = 5; % +/- range of predicted next postion of FCCH burst.

------------Algorithm------------
Because FCCH actually is a period of CW signal, we can use FFT to see if there is sharp peak in frequency domain.
For the first FCCH detection, a continuous moving FFT is performed. After the first FCCH is hit, the following FCCH will be only detected at predicted position (+/- small range) according to GSM frame structure.
At least 3 successive FCCH need to be detected for we to ensure one donwlink broadcasting carrier is there. See details in FCCH_coarse_position.m.

