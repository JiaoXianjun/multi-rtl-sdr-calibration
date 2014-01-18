function [hit_flag, hit_idx, hit_avg_snr] = move_fft_snr_runtime_avg(s, mv_len, fft_len, th)
hit_flag = false;
hit_idx = -1;
hit_avg_snr = inf;

store_for_moving_avg = 999.*ones(1, mv_len);
sum_snr = sum(store_for_moving_avg);

len = length(s);
tmp = zeros(1, len - (fft_len-1));

for i=1:(len - (fft_len-1))
    chn_tmp = s(i:(i+fft_len-1));
    chn_tmp = abs(fft(chn_tmp, fft_len)).^2;
    signal_power = max(chn_tmp);
    noise_power = sum(chn_tmp) - signal_power;
    snr = 10.*log10(signal_power/noise_power);
    
    peak_to_avg = snr - (sum_snr/mv_len);

    if peak_to_avg > th
        hit_flag = true;
        disp(['Hit. idx ' num2str(i) '; SNR ' num2str(snr) 'dB; peak SNR to avg SNR ' num2str(peak_to_avg) 'dB']);
        break;
    else
        sum_snr = sum_snr - store_for_moving_avg(end);
        sum_snr = sum_snr + snr;
        
        store_for_moving_avg(2:end) = store_for_moving_avg(1:(end-1));
        store_for_moving_avg(1) = snr;
    end
    
    tmp(i) = snr;
end

if hit_flag
    hit_idx = i;
    hit_avg_snr = snr - peak_to_avg;
end
