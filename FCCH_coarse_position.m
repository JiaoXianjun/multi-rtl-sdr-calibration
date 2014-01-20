function [position, snr] = FCCH_coarse_position(s, decimation_ratio)
num_sym_per_slot = 625/4;
num_slot_per_frame = 8;
num_sym_per_frame = num_sym_per_slot*num_slot_per_frame;

% % method fft
len_FCCH_CW = 148; % GSM spec. 1x rate

fft_len = 2^floor( log2( len_FCCH_CW/decimation_ratio ) );
% fft_len = 16;

len = length(s);
th = 10; %dB. threshold
mv_len = 10*fft_len;
[hit_flag, hit_idx, hit_avg_snr, hit_snr] = move_fft_snr_runtime_avg(s(1:ceil(13*num_sym_per_frame/decimation_ratio)), mv_len, fft_len, th);

if ~hit_flag
%     disp('No FCCH found!');
    position = -1;
    snr = inf;
    return;
end

num_sym_between_FCCH = 10*num_slot_per_frame*num_sym_per_slot;
num_sym_between_FCCH1 = 11*num_slot_per_frame*num_sym_per_slot; % in case the last idle frame of the multiframe

num_sym_between_FCCH_decimate = round(num_sym_between_FCCH/decimation_ratio);
num_sym_between_FCCH_decimate1 = round(num_sym_between_FCCH1/decimation_ratio);

position = hit_idx;
snr = hit_snr;

set_idx = 1;
max_offset = 5;
while 1
    next_position = position(set_idx) + num_sym_between_FCCH_decimate;
    
    if next_position > (len - (fft_len-1)) - max_offset;
        break;
    end

    i_set = next_position + (-max_offset:max_offset);
%     i_set(i_set<1) = 1;
%     i_set(i_set>(len - (fft_len-1))) = (len - (fft_len-1));

    [hit_flag, hit_idx, hit_snr] = specific_fft_snr_fix_avg(s, i_set, fft_len, th, hit_avg_snr);
    
    if hit_flag
        position = [position hit_idx];
        snr = [snr hit_snr];
        set_idx = set_idx + 1;
    else
        next_position = position(set_idx) + num_sym_between_FCCH_decimate1;
        
        if next_position > (len - (fft_len-1)) - max_offset;
            break;
        end

        i_set = next_position + (-max_offset:max_offset);
%         i_set(i_set<1) = 1;
%         i_set(i_set>(len - (fft_len-1))) = (len - (fft_len-1));

        [hit_flag, hit_idx, hit_snr] = specific_fft_snr_fix_avg(s, i_set, fft_len, th, hit_avg_snr);
        
        if hit_flag
            position = [position hit_idx];
            snr = [snr hit_snr];
            set_idx = set_idx + 1;
        else
            break;
        end
    end
end

position = (position-1)*decimation_ratio + 1;
disp(['Find successive ' num2str(length(position)) ' FCCH. position: ' num2str(position)]);
