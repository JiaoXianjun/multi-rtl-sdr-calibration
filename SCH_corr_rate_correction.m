% Jiao Xianjun (putaoshu@msn.com; putaoshu@gmail.com)
% Estimate sampling rate error and carrier frequency error and compansate them according to GSM SCH detection.
% A script of project: https://github.com/JiaoXianjun/multi-rtl-sdr-calibration

function [pos_info, r, sampling_ppm] = SCH_corr_rate_correction(s, FCCH_pos, sch_training_sequence, oversampling_ratio)
disp(' ');

r = -1;
pos_info = [-1, -1];
sampling_ppm = inf;
if length(FCCH_pos)<5
    disp('SCH: Warning! Length of hits is smaller than 5!');
    return;
end

num_sym_per_slot = 625/4;
num_sym_per_slot_ov = num_sym_per_slot*oversampling_ratio;
num_slot_per_frame = 8;
num_sym_per_frame = num_sym_per_slot*num_slot_per_frame;
num_sym_per_frame_ov = num_sym_per_frame*oversampling_ratio;

len_training_sequence = 64;
len_training_sequence_ov = len_training_sequence*oversampling_ratio;
len_pre_training_sequence = 42;
len_pre_training_sequence_ov = len_pre_training_sequence*oversampling_ratio;
fix_offset_from_fcch_pos = num_sym_per_frame + len_pre_training_sequence;
fix_offset_from_fcch_pos_ov = fix_offset_from_fcch_pos*oversampling_ratio;

num_fcch_hit = length(FCCH_pos);
SCH_pos = inf.*ones(1, num_fcch_hit);

pos_info = -1.*ones(3*num_fcch_hit, 2);

len_s_ov = length(s);

max_offset = 8*oversampling_ratio;
for i=1:num_fcch_hit
    training_sp = FCCH_pos(i) + fix_offset_from_fcch_pos_ov;
    
    if (training_sp+max_offset) > (len_s_ov-len_training_sequence_ov+1); % run out of sampled signal
        SCH_pos = SCH_pos(1:(i-1));
        break;
    end

    sp = training_sp -max_offset;
    ep = training_sp +max_offset-5*oversampling_ratio;

    len = ep - sp + 1;
    
    corr_mat = toeplitz(s(sp:(ep+len_training_sequence_ov-1)), [s(sp) zeros(1, len-1)]);
    corr_mat = corr_mat(len:end, end:-1:1);
    
    corr_val = abs((sch_training_sequence')*corr_mat).^2;
    [~, max_idx] = max(corr_val);
    SCH_pos(i) = sp + max_idx - 1;
    
%     figure; plot(corr_val, 'b.-');
    
    if max_idx==1 || max_idx==len
        disp('SCH:  Warning! No peak around base position is found!');
        pos_info = [-1, -1];
        return;
    end
%     a = diff(corr_val(1:max_idx));
%     if sum(a<0) > 0
%         disp('SCH  Warning! fail in double monotony check first half!');
%         SCH_pos = -1;
%         figure; plot(corr_val, 'b.-');
%         return;
%     end
%     a = diff(corr_val(max_idx:end));
%     if sum(a>0) > 0
%         disp('SCH  Warning! fail in double monotony check second half!');
%         SCH_pos = -1;
%         figure; plot(corr_val, 'b.-');
%         return;
%     end
    
end
disp(['SCH: first round diff ' num2str(diff(SCH_pos))]);

num_sch = length(SCH_pos);
% estimate and correct sampling time error
if num_sch >= 5
%     sp = SCH_pos(1);
%     r = s((sp-fix_offset_from_fcch_pos_ov):end); % begin with FCCH
    r = s;
    first_SCH_pos = SCH_pos(1);
    diff_seq = diff(SCH_pos);
    
    num_sym_between_SCH_ov = 10*num_sym_per_frame_ov;
    num_sym_between_SCH1_ov = 11*num_sym_per_frame_ov; % in case the last idle frame of the multiframe
    
    max_ppm = 400;
    max_th = floor( num_sym_between_SCH_ov*max_ppm*1e-6 );
    max_th1 = floor( num_sym_between_SCH1_ov*max_ppm*1e-6 );
    
    a = diff_seq - num_sym_between_SCH_ov; 
    a_logical = abs(a)<max_th;
    num_distance_a = sum(a_logical);
    
    b = diff_seq - num_sym_between_SCH1_ov;
    b_logical = abs(b)<max_th1;
    num_distance_b = sum(b_logical);
    
    if (num_distance_a + num_distance_b) ~= num_sch-1
        disp('SCH: Warning! Kinds of pos diff more than 2!');
        disp(['Expected len ' num2str(num_sch-1) '. Actual ' num2str([num_distance_a num_distance_b])]);
        disp(['diff intra multiframe max th ' num2str(max_th) ' actual ' num2str(a)]);
        disp(['diff inter multiframe max th ' num2str(max_th1) ' actual ' num2str(b)]);
        return;
    end
    
    expected_distance = sum(a_logical.*num_sym_between_SCH_ov) + sum(b_logical.*num_sym_between_SCH1_ov);
    actual_distance = SCH_pos(end) - SCH_pos(1);
    mean_ex_percent = (actual_distance-expected_distance)/expected_distance;
    sampling_ppm = mean_ex_percent*1e6;
    disp(['SCH: sampling error ppm ' num2str(sampling_ppm)]);
    
    if mean_ex_percent ~= 0
        if mean_ex_percent > 0
            max_len = floor( length(r)/(1+mean_ex_percent) );
        elseif mean_ex_percent < 0
            max_len = length(r);
        end
        interp_seq = (0:(max_len-1))'.*(1+mean_ex_percent);
        r = interp1((0 : (length(r)-1))', r, interp_seq, 'linear');
    end
    
    step_size = zeros(1, num_sch-1);
    step_size(a_logical) = num_sym_between_SCH_ov;
    step_size(b_logical) = num_sym_between_SCH1_ov;
    SCH_pos = cumsum([1 step_size]);
%     disp(num2str(step_size));
    first_SCH_pos = round((first_SCH_pos-1)/(1+mean_ex_percent))+1;
    SCH_pos = SCH_pos + first_SCH_pos - 1;
    
    BCCH_flag = zeros(1, num_sch+1);
    b_idx = find(b_logical);
    BCCH_flag(b_idx+1) = 1;
    BCCH_flag(b_idx(b_idx>=5)-4) = 1;
%     disp(num2str(BCCH_flag));
    
    burst_idx = 1;
    for i=1:num_sch
        sp = SCH_pos(i)-fix_offset_from_fcch_pos_ov;
        pos_info(burst_idx, 1) = sp;
        pos_info(burst_idx, 2) = 0; % type FCCH
        burst_idx = burst_idx + 1;
        
        sp = SCH_pos(i)-len_pre_training_sequence_ov;
        ep = sp + num_sym_per_slot_ov-1;
        if ep<=length(r)
            pos_info(burst_idx, 1) = sp;
            pos_info(burst_idx, 2) = 1; % type SCH
            burst_idx = burst_idx + 1;
        else
            break;
        end
        
        sch_sp = sp;
        if BCCH_flag(i)
            runout_flag = false;
            for idx=1:4
                sp = sch_sp + idx*num_sym_per_frame_ov;
                ep = sp + num_sym_per_slot_ov-1;
                if ep<=length(r)
                    pos_info(burst_idx, 1) = sp;
                    pos_info(burst_idx, 2) = 2; % type BCCH
                    burst_idx = burst_idx + 1;
                else
                    runout_flag = true;
                    break;
                end
            end
            if runout_flag
                break;
            end
        end
    end
    pos_info = pos_info(1:(burst_idx-1),:);
end

% num_sch = length(SCH_pos);
% % estimate phase
% phase_seq = zeros(1, num_sch);
% if num_sch >= 5
%     for i=1:num_sch
%         sp = SCH_pos(i);
%         x = r(sp:(sp+len_training_sequence_ov-1));
%         phase_seq(i) = angle( (sch_training_sequence')*x(:)  );
%     end
% end

