function [position, metric_data] = FCCH_coarse_position(s, sampling_rate)

% % method fft
len_FCCH_CW = 148;
decimation_ratio = 16;
s = s(1:decimation_ratio:end, :);
step_size = 16/decimation_ratio;

len_CW = len_FCCH_CW*4/decimation_ratio;
fft_len = len_CW;

[len, num_chn] = size(s);
len_metric = length(1:step_size:len);
metric_data = zeros(len_metric, num_chn);
s = [s; zeros(len_CW, num_chn)];
idx = 1;
for i=1:step_size:len
    tmp = s(i:(i+len_CW-1), :);
    tmp = abs(fft(tmp, fft_len, 1)).^2;
    [~, max_idx] = max(tmp, [], 1);
    
    for chn_idx = 1 : num_chn
        chn_tmp = tmp(:, chn_idx);
        
        sp = max(max_idx(chn_idx)-4, 1);
        ep = min(max_idx(chn_idx)+3, fft_len);

        signal_power = sum( chn_tmp(sp:ep) );
        chn_tmp(sp:ep) = [];
        noise_power = mean(chn_tmp);
        metric_data(idx, chn_idx) = 10*log10(signal_power/noise_power);
    end
    idx = idx+1;
end

% % % method accumulation
% len = length(s);
% 
% FCCH_freq = (1625/24)*1e3; % Hz
% phase_per_sample = FCCH_freq*2*pi/sampling_rate;
% s = s.*exp(-1i.*(1:len).*phase_per_sample);
% 
% len_FCCH_CW = 148;
% len_sum = len_FCCH_CW*4/4;
% 
% step_size = 8;
% len_metric = length(1:step_size:len);
% metric_data = zeros(1, len_metric);
% s = [s zeros(1, len_sum)];
% idx = 1;
% for i=1:step_size:len
%     tmp = s(i:(i+len_sum-1));
%     metric_data(idx) = abs(sum(tmp));
%     idx = idx+1;
% end


position = zeros(1, num_chn);