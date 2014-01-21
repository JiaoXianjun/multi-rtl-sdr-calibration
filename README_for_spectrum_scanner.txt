Multiple rtl-sdr(rtl_tcp) dongles based Matlab frequency scanner. (putaoshu@gmail.com; putaoshu@msn.com)
1. multi_rtl_sdr_split_scanner.m
Have multiple dongles run concurrently to speedup scanning wide band by scanning different sub-band with different dongle.
2. multi_rtl_sdr_diversity_scanner.m
All dongles scan the same band, and then results from different dongles are combined incoherently.

Scripts of project: https://github.com/JiaoXianjun/multi-rtl-sdr-calibration

------------Usage------------
1. Assume that you have installed rtl-sdr
(http://sdr.osmocom.org/trac/wiki/rtl-sdr) and have those native utilities run correctly already.

For example, you have multiple dongles, please run multiple rtl_tcp in multiple shell respectively as:
rtl_tcp -p 1234 -d 0
rtl_tcp -p 1235 -d 1
rtl_tcp -p 1236 -d 2
...

2. Then run script multi_rtl_sdr_split_scanner.m or multi_rtl_sdr_diversity_scanner.m in MATLAB.

ATTENTION! In some computer, each time before you run script, maybe you need to terminate multiple rtl_tcp and re-launch them again.
ATTENTION! Please reduce number of inspected points by reducing frequency range or increasing step size, if your computer hasn't enough memory installed. Because all signals are stored firstly before processing.

Change following parameters in the script as you need:

num_dongle = 1;
start_freq = 935e6;
end_freq = 960e6;
freq_step = 0.05e6;
observe_time = 0.1;
gain = 0;
sample_rate = 2.048e6;
...

------------Algorithm------------
Use high sampling rate for each frequency point. Then Auto generated narrow FIR is used to suppress noise and extract signal.
At last, power of signal at each frequency is estimated and spectrum of all frequencies is generated.
