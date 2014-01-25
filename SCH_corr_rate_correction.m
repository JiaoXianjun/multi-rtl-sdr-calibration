function [SCH_pos, sampling_ppm, corr_val, phase_seq, r] = SCH_corr_rate_correction(s, FCCH_pos, sch_training_sequence, oversampling_ratio)
s = s(:);
phase_seq = 0;
sampling_ppm = -1;
r = 0;

num_sym_per_slot = 625/4;
num_slot_per_frame = 8;
num_sym_per_frame = num_sym_per_slot*num_slot_per_frame;

len_training_sequence = 64;
len_training_sequence_ov = len_training_sequence*oversampling_ratio;
len_pre_training_sequence = 42;
fix_offset_from_fcch_pos = num_sym_per_frame + len_pre_training_sequence;
fix_offset_from_fcch_pos_ov = fix_offset_from_fcch_pos*oversampling_ratio;

num_fcch_hit = length(FCCH_pos);
SCH_pos = inf.*ones(1, num_fcch_hit);

len_s_ov = length(s);
len_s = floor( len_s_ov/oversampling_ratio );

max_offset = 3*oversampling_ratio;
for i=1:num_fcch_hit
    training_sp = FCCH_pos(i) + fix_offset_from_fcch_pos_ov;
    
    if (training_sp+max_offset) > (len_s_ov-len_training_sequence_ov+1); % run out of sampled signal
        break;
    end

    sp = training_sp -max_offset;
    ep = training_sp +max_offset-3*oversampling_ratio;

    len = ep - sp + 1;
    
    corr_mat = toeplitz(s(sp:(ep+len_training_sequence_ov-1)), [s(sp) zeros(1, len-1)]);
    corr_mat = corr_mat(len:end, end:-1:1);
    
    corr_val = abs((sch_training_sequence')*corr_mat).^2;
    [~, max_idx] = max(corr_val);
    SCH_pos(i) = sp + max_idx - 1;
    if max_idx==1 || max_idx==len
        disp('SCH  Warning! no peak around base position is found!');
        SCH_pos = -1;
        return;
    end
    a = diff(corr_val(1:max_idx));
    if sum(a<0) > 0
        disp('SCH  Warning! fail in double monotony check first half!');
        SCH_pos = -1;
        return;
    end
    a = diff(corr_val(max_idx:end));
    if sum(a>0) > 0
        disp('SCH  Warning! fail in double monotony check second half!');
        SCH_pos = -1;
        return;
    end
    
end

num_sch = length(SCH_pos);
% estimate and correct sampling time error
if num_sch >= 5
    sp = SCH_pos(1);
    r = s(sp:end);
    diff_seq = diff(SCH_pos);
    
    num_sym_per_slot = 625/4;
    num_slot_per_frame = 8;
    num_sym_per_frame = num_sym_per_slot*num_slot_per_frame;
    
    num_sym_between_SCH_ov = 10*num_sym_per_frame*oversampling_ratio;
    num_sym_between_SCH1_ov = 11*num_sym_per_frame*oversampling_ratio; % in case the last idle frame of the multiframe
    
    max_ppm = 50;
    max_th = floor( num_sym_between_SCH_ov*max_ppm*1e-6 );
    max_th1 = floor( num_sym_between_SCH1_ov*max_ppm*1e-6 );
    
    a = diff_seq - num_sym_between_SCH_ov; 
    a_logical = abs(a)<max_th;
    num_distance_a = sum(a_logical);
    
    b = diff_seq - num_sym_between_SCH1_ov;
    b_logical = abs(b)<max_th1;
    num_distance_b = sum(b_logical);
    
    if (num_distance_a + num_distance_b) ~= num_sch-1
        disp('SCH Warning! Kinds of pos diff more than 2!');
        disp(['Expected len ' num2str(num_sch-1) '. Actual ' num2str([num_distance_a num_distance_b])]);
        disp(['diff intra multiframe max th ' num2str(max_th) ' actual ' num2str(a)]);
        disp(['diff inter multiframe max th ' num2str(max_th1) ' actual ' num2str(b)]);
        SCH_pos = -1;
        return;
    end
    
    expected_distance = sum(a_logical.*num_sym_between_SCH_ov) + sum(b_logical.*num_sym_between_SCH1_ov);
    actual_distance = SCH_pos(end) - SCH_pos(1);
    mean_ex_percent = (actual_distance-expected_distance)/expected_distance;
    sampling_ppm = mean_ex_percent*1e6;
    
    if mean_ex_percent >= 0
        max_len = floor( length(r)/(1+mean_ex_percent) );
    else
        max_len = length(r);
    end
    interp_seq = (0:(max_len-1)).*(1+mean_ex_percent);
    
    r = interp1((0 : (length(r)-1)), r, interp_seq, 'linear');
    
    step_size = zeros(1, num_sch-1);
    step_size(a_logical) = num_sym_between_SCH_ov;
    step_size(b_logical) = num_sym_between_SCH1_ov;
    SCH_pos = cumsum([1 step_size]);
    
    if (SCH_pos(end) + len_training_sequence_ov-1) > length(r)
        SCH_pos = SCH_pos(1:(end-1));
    end
end

num_sch = length(SCH_pos);
% estimate phase
phase_seq = zeros(1, num_sch);
if num_sch >= 5
    for i=1:num_sch
        sp = SCH_pos(i);
        x = r(sp:(sp+len_training_sequence_ov-1));
        phase_seq(i) = angle( (sch_training_sequence')*x(:)  );
    end
end

