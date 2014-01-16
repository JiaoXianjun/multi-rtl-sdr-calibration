function position = FCCH_coarse_position(s, oversampling_ratio)

% % method fft
len_FCCH_CW = 148; % GSM spec. 1x rate
decimation_ratio = 32; % for lower computation load
s = s(1:decimation_ratio:end);

len_CW = floor( len_FCCH_CW*oversampling_ratio/decimation_ratio );
fft_len = len_CW;

len = length(s);
s = [s; zeros(len_CW, 1)];
th = 15; %dB. threshold
hit_flag = 0;
for i=1:len
    chn_tmp = s(i:(i+len_CW-1));
    chn_tmp = abs(fft(chn_tmp, fft_len)).^2;
    signal_power = max(chn_tmp);
    noise_power = sum(chn_tmp) - signal_power;

    if signal_power > noise_power*(10^(th/10));
        hit_flag = 1;
        disp(['FCCH first hit. SNR ' num2str(10.*log10(signal_power/noise_power)) 'dB']);
        break;
    end
end

if hit_flag == 0
    disp('No FCCH found!');
    position = -1;
    return;
end

num_sym_per_slot = 625/4;
num_slot_per_frame = 8;
num_sym_between_FCCH = 10*num_slot_per_frame*num_sym_per_slot;

num_sym_between_FCCH_oversample = num_sym_between_FCCH*oversampling_ratio;
num_sym_between_FCCH_decimate = round(num_sym_between_FCCH_oversample/decimation_ratio);

first_position = i;
target_following_idx = first_position + (1:3).*num_sym_between_FCCH_decimate;

hit_flag = 0;
for i=1:length(target_following_idx)
    i_set = target_following_idx(i) + (-1:1);
    i_set(i_set<1) = 1;
    i_set(i_set>len) = len;
    
    for j=1:length(i_set)
        idx = i_set(j);

        chn_tmp = s(idx:(idx+len_CW-1));
        chn_tmp = abs(fft(chn_tmp, fft_len)).^2;
        signal_power = max(chn_tmp);
        noise_power = sum(chn_tmp) - signal_power;

        if signal_power > noise_power*(10^(th/10));
            hit_flag = hit_flag + 1;
            disp(['FCCH next hit. SNR ' num2str(10.*log10(signal_power/noise_power)) 'dB']);
            break;
        end
    end
end

if hit_flag == length(target_following_idx)
    position = (first_position-1)*decimation_ratio + 1;
    disp(['Find successive ' num2str(hit_flag+1) ' FCCH. First position ' num2str(position)]);
else
    disp(['No enough FCCH found! Only ' num2str(hit_flag+1)]);
    position = -1;
end

