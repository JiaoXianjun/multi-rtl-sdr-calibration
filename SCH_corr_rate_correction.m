function [SCH_pos, r] = SCH_corr_rate_correction(s, FCCH_pos, sch_training_sequence, oversampling_ratio)
s = s(:);

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

max_offset = 4*oversampling_ratio;
for i=1:num_fcch_hit
    training_sp = FCCH_pos(i) + fix_offset_from_fcch_pos_ov;
    
    if (training_sp+max_offset) > (len_s_ov-len_training_sequence_ov+1); % run out of sampled signal
        break;
    end

    sp = training_sp -max_offset;
    ep = training_sp +max_offset;

    len = ep - sp + 1;
    
    corr_val = zeros(1, len);
    for idx=sp:ep
        corr_val(idx - sp + 1) = abs( sum((sch_training_sequence')*s(idx:(idx+len_training_sequence_ov-1))) );
    end
    [~, max_idx] = max(corr_val);
    SCH_pos(i) = sp + max_idx - 1;
    if max_idx==1 || max_idx==len
        disp('SCH  Warning! no peak around base position is found!');
    end
end
r = 0;
