function [SCH_pos, r] = SCH_corr_rate_correction(s, FCCH_pos, sch_training_sequence, oversampling_ratio)
num_sym_per_slot = 625/4;
num_slot_per_frame = 8;
num_sym_per_frame = num_sym_per_slot*num_slot_per_frame;

len_training_sequence = 64;
len_training_sequence_ov = len_training_sequence*oversampling_ratio;
len_pre_training_sequence = 42;
fix_offset_from_fcch_pos = num_sym_per_frame + len_pre_training_sequence;

num_fcch_hit = length(FCCH_pos);
SCH_pos = inf.*ones(1, num_fcch_hit);

len_s_ov = length(s);
len_s = floor( len_s_ov/oversampling_ratio );

max_offset = 5;
for i=1:num_fcch_hit
    training_sp = FCCH_pos(i) + fix_offset_from_fcch_pos;
    
    if (training_sp+max_offset) > (len_s-len_training_sequence+1); % run out of sampled signal
        break;
    end

    interest_set = training_sp + (-max_offset:max_offset);

    interest_set = (interest_set - 1)*oversampling_ratio + 1;
    
    corr_val = zeros(1, length(interest_set));
    for idx=1:length(interest_set)
        sp = interest_set(idx);
        corr_val(idx) = abs( sum((sch_training_sequence')*s(sp:(sp+len_training_sequence_ov-1))) );
    end
    [~, max_idx] = max(corr_val);
    SCH_pos(i) = interest_set(max_idx);
end
r = 0;
