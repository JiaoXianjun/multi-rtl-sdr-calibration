% Jiao Xianjun (putaoshu@msn.com; putaoshu@gmail.com)
% GSM FCCH detector/verification
% A script of project: https://github.com/JiaoXianjun/multi-rtl-sdr-calibration

function FCCH_demod(s, pos_info, oversampling_ratio, carrier_freq)
disp(' ');

if pos_info==-1
    disp('FCCH demod: Warning! No valid position information!');
    return;
end

len_TB = 3;
len_CW = 142;
len_FCCH_CW = 2*len_TB + len_CW; % GSM spec. 1x rate
fft_len = len_FCCH_CW*oversampling_ratio;

fcch_idx = (pos_info(:,2)==0);
fcch_pos = pos_info(fcch_idx,1);
num_fcch = sum(fcch_idx);

fcch_mat = zeros(fft_len, num_fcch);
for i=1:num_fcch
    sp = fcch_pos(i);
    ep = sp + fft_len - 1;
    fcch_mat(:,i) = s(sp:ep);
end
fd_fcch = abs(fft(fcch_mat, fft_len, 1)).^2;

symbol_rate = (1625/6)*1e3;
sampling_rate = symbol_rate*oversampling_ratio;

fd_fcch = [fd_fcch( ((fft_len/2)+1):end, : ); fd_fcch( 1:(fft_len/2), : )];
[~, max_idx] = max(fd_fcch, [], 1);

int_phase_rotate = 2.*pi.*(max_idx - ((fft_len/2) + 1 ) )./fft_len;
fcch_mat = fcch_mat.*exp( -1i.*((0:(fft_len-1))')*int_phase_rotate );

phase_rotate = exp( 1i.*angle( fcch_mat(2:end,:) ) )./exp( 1i.*angle( fcch_mat(1:(end-1),:) ) );
phase_rotate = angle(mean(phase_rotate,1));

freq = sampling_rate.*(int_phase_rotate + phase_rotate)./(2*pi);
disp(['FCCH demod: FCCH freq ' num2str(freq)]);
mean_freq = mean(freq);
disp(['FCCH demod: mean FCCH freq ' num2str(mean_freq)]);

target_freq = symbol_rate/4;
carrier_ppm = 1e6*(mean_freq - target_freq)/carrier_freq;
disp(['FCCH demod: carrier error ppm ' num2str(carrier_ppm)]);

snr = zeros(1, num_fcch);

half_noise_len = ceil( (fft_len*200e3/sampling_rate)/2 );

sp = ((fft_len/2)+1) - half_noise_len;
ep = ((fft_len/2)+1) + half_noise_len - 1;
for i=1:num_fcch
    signal_power_set = (max_idx(i)-2) : (max_idx(i)+2);
    signal_power_set = mod(signal_power_set-1, fft_len) + 1;
    signal_power = sum(fd_fcch(signal_power_set, i), 1);
    noise_power = sum(fd_fcch(sp:ep,i), 1) - signal_power;
    snr(i) = 10.*log10(signal_power./noise_power);
end

disp(['FCCH demod: SNR ' num2str(snr)]);
disp(['FCCH demod: max idx ' num2str(max_idx - ((fft_len/2) + 1 ))]);
