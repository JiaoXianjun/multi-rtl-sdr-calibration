function freq = FCCH_demod(burst, oversampling_ratio)
len_TB = 3;
len_CW = 142;
fft_len = len_CW*oversampling_ratio;

freq = 0;
