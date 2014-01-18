function position = FCCH_coarse_position(s, oversampling_ratio)

% % method fft
len_FCCH_CW = 148; % GSM spec. 1x rate
decimation_ratio = 32; % for lower computation load
s = s(1:decimation_ratio:end);

fft_len = floor( len_FCCH_CW*oversampling_ratio/decimation_ratio );

len = length(s);
th = 8; %dB. threshold
mv_len = 4*fft_len;
[hit_flag, hit_idx, hit_avg_snr] = move_fft_snr_runtime_avg(s, mv_len, fft_len, th);

if ~hit_flag
    disp('No FCCH found!');
    position = -1;
    return;
end

num_sym_per_slot = 625/4;
num_slot_per_frame = 8;
num_sym_between_FCCH = 10*num_slot_per_frame*num_sym_per_slot;
num_sym_between_FCCH1 = 11*num_slot_per_frame*num_sym_per_slot; % in case the last idle frame of the multiframe

num_sym_between_FCCH_oversample = num_sym_between_FCCH*oversampling_ratio;
num_sym_between_FCCH_decimate = round(num_sym_between_FCCH_oversample/decimation_ratio);
num_sym_between_FCCH_oversample1 = num_sym_between_FCCH1*oversampling_ratio;
num_sym_between_FCCH_decimate1 = round(num_sym_between_FCCH_oversample1/decimation_ratio);

position = hit_idx;

set_idx = 1;
max_offset = 1;
while 1
    next_position = position(set_idx) + num_sym_between_FCCH_decimate;
    
    if next_position > (len - (fft_len-1)) - max_offset;
        break;
    end

    i_set = next_position + (-max_offset:max_offset);
    i_set(i_set<1) = 1;
    i_set(i_set>(len - (fft_len-1))) = (len - (fft_len-1));

    [hit_flag, hit_idx] = specific_fft_snr_fix_avg(s, i_set, fft_len, th, hit_avg_snr);
    
    if hit_flag
        position = [position hit_idx];
        set_idx = set_idx + 1;
    else
        next_position = position(set_idx) + num_sym_between_FCCH_decimate1;
        
        if next_position > (len - (fft_len-1)) - max_offset;
            break;
        end

        i_set = next_position + (-max_offset:max_offset);
        i_set(i_set<1) = 1;
        i_set(i_set>(len - (fft_len-1))) = (len - (fft_len-1));

        [hit_flag, hit_idx] = specific_fft_snr_fix_avg(s, i_set, fft_len, th, hit_avg_snr);
        
        if hit_flag
            position = [position hit_idx];
            set_idx = set_idx + 1;
        else
            break;
        end
    end
end

position = (position-1)*decimation_ratio + 1;
disp(['Find successive ' num2str(length(position)) ' FCCH. position:']);
disp(num2str(position));
