function SCH_demod(s, pos_info, training_sequence, oversampling_ratio)
disp(' ');

if pos_info==-1
    disp('SCH demod: Warning! No valid position information!');
    return;
end

sch_idx = (pos_info(:,2)==1);
sch_pos = pos_info(sch_idx, 1);
num_sch = length(sch_pos);

len_training_sequence = 64;
len_training_sequence_ov = len_training_sequence*oversampling_ratio;
len_pre_training_sequence = 42;
len_pre_training_sequence_ov = len_pre_training_sequence*oversampling_ratio;

max_offset = 8.5*oversampling_ratio;
for i=1:num_sch
    sp = sch_pos(i) + (len_pre_training_sequence_ov) - max_offset;
    ep = sch_pos(i) + (len_pre_training_sequence_ov) + max_offset;

    len = ep - sp + 1;

    corr_mat = toeplitz(s(sp:(ep+len_training_sequence_ov-1)), [s(sp) zeros(1, len-1)]);
    corr_mat = corr_mat(len:end, end:-1:1);

    corr_val = abs((training_sequence')*corr_mat).^2;
    figure;
    plot(corr_val);
end