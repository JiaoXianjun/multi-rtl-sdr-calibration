% Jiao Xianjun (putaoshu@msn.com; putaoshu@gmail.com)
% Find out coarse sample index of beginning of GSM FCCH
% A script of project: https://github.com/JiaoXianjun/multi-rtl-sdr-calibration

function [position, snr] = FCCH_coarse_position(s, decimation_ratio)
disp(' ');
position = -1;
snr = -1;

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

% find out first FCCH in first 23 frames by moving FFT
[hit_flag, hit_idx, hit_avg_snr, hit_snr] = move_fft_snr_runtime_avg(s(1:ceil(23*num_sym_per_frame/decimation_ratio)), mv_len, fft_len, th);

if ~hit_flag
    disp('FCCH coarse: No FCCH found!');
    return;
end

num_sym_between_FCCH = 10*num_slot_per_frame*num_sym_per_slot;
num_sym_between_FCCH1 = 11*num_slot_per_frame*num_sym_per_slot; % in case the last idle frame of the multiframe

num_sym_between_FCCH_decimate = round(num_sym_between_FCCH/decimation_ratio);
num_sym_between_FCCH_decimate1 = round(num_sym_between_FCCH1/decimation_ratio);

max_num_fcch = ceil(len/(10*num_sym_per_frame/decimation_ratio));
position = zeros(1, max_num_fcch);
snr = zeros(1, max_num_fcch);
position(1) = hit_idx;
snr(1) = hit_snr;

set_idx = 1;
max_offset = 5;
while 1
    next_position = position(set_idx) + num_sym_between_FCCH_decimate; % predicted position of next FCCH in the same multiframe
    
    if next_position > (len - (fft_len-1)) - max_offset; % run out of sampled signal
        break;
    end

%     i_set = next_position + (-max_offset:max_offset);
%     i_set(i_set<1) = 1;
%     i_set(i_set>(len - (fft_len-1))) = (len - (fft_len-1));
    i_set = next_position + [-max_offset, max_offset];

    [hit_flag, hit_idx, hit_snr] = specific_fft_snr_fix_avg(s, i_set, fft_len, th, hit_avg_snr); % fft detection at specific position
    
    if hit_flag
        set_idx = set_idx + 1;
        position(set_idx) = hit_idx;
        snr(set_idx) = hit_snr;
    else
        next_position = position(set_idx) + num_sym_between_FCCH_decimate1;% predicted position of next FCCH in the next multiframe
        
        if next_position > (len - (fft_len-1)) - max_offset; % run out of sampled signal
            break;
        end

%         i_set = next_position + (-max_offset:max_offset);
%         i_set(i_set<1) = 1;
%         i_set(i_set>(len - (fft_len-1))) = (len - (fft_len-1));
        i_set = next_position + [-max_offset, max_offset];
        
        [hit_flag, hit_idx, hit_snr] = specific_fft_snr_fix_avg(s, i_set, fft_len, th, hit_avg_snr); % fft detection at specific position
        
        if hit_flag
            set_idx = set_idx + 1;
            position(set_idx) = hit_idx;
            snr(set_idx) = hit_snr;
        else
            break;
        end
    end
end

position = position(1:set_idx);
snr = snr(1:set_idx);

position = (position-1)*decimation_ratio + 1;
disp(['FCCH coarse: hit successive ' num2str(length(position)) ' FCCH. pos ' num2str(position)]);
disp(['FCCH coarse: pos diff ' num2str(diff(position))]);
disp(['FCCH coarse: SNR ' num2str(snr)]);
