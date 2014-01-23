function [FCCH_pos, FCCH_snr, r] = FCCH_fine_correction(s, base_position, oversampling_ratio)
symbol_rate = (1625/6)*1e3;
sampling_rate = symbol_rate*oversampling_ratio;

len_FCCH_CW = 148; % GSM spec. 1x rate
fft_len = len_FCCH_CW*oversampling_ratio;

num_fcch_hit = length(base_position);
FCCH_pos = inf.*ones(1, num_fcch_hit);

len_s_ov = length(s);
len_s = floor( len_s_ov/oversampling_ratio );

max_offset = 32;
las_idx = 0;
for i=1:num_fcch_hit
    position = base_position(i);
    
    if (position+max_offset) > (len_s-len_FCCH_CW+1); % run out of sampled signal
        last_idx = i-1;
        break;
    end

    sp = position - max_offset;
    ep = position + max_offset;
    
    sp = (sp - 1)*oversampling_ratio + 1;
    ep = (ep - 1)*oversampling_ratio + 1;

    len = ep - sp + 1;
    
    fft_peak_val = zeros(1, len);
    for idx=sp:ep
        fft_peak_val(idx-sp+1) = max( abs( fft(s(idx:(idx+fft_len-1))) ) );
    end
    [~, max_idx] = max(fft_peak_val);
    FCCH_pos(i) = sp + max_idx - 1;
    if max_idx==1 || max_idx==len
        disp('FCCH Warning! no peak around base position is found!');
    end
    last_idx = i;
end
FCCH_pos = FCCH_pos(1:last_idx);

FCCH_snr = 0;
r = 0;
