% Jiao Xianjun (putaoshu@msn.com; putaoshu@gmail.com)
% Estimate carrier frequency error and compansate it.
% A script of project: https://github.com/JiaoXianjun/multi-rtl-sdr-calibration

function [r, carrier_ppm] = carrier_correct_post_SCH(s, pos_info, oversampling_ratio, carrier_freq)
disp(' ');

r = -1;
carrier_ppm = inf;
if pos_info==-1
    disp('post SCH: Warning! No valid position information!');
    return;
end

bcch_idx = (pos_info(:,2)==2);
if sum(bcch_idx) < 4
    disp('post SCH: Warning! The number of BCCH bursts is less than 4!');
    return;
end

symbol_rate = (1625/6)*1e3;
sampling_rate = symbol_rate*oversampling_ratio;
target_freq = symbol_rate/4;

% num_sym_per_slot = 625/4;
% num_sym_per_slot_ov = num_sym_per_slot*oversampling_ratio;
% num_slot_per_frame = 8;
% num_sym_per_frame = num_sym_per_slot*num_slot_per_frame;
% num_sym_per_frame_ov = num_sym_per_frame*oversampling_ratio;

% len_sch_training_sequence = 64;
% len_sch_training_sequence_ov = len_sch_training_sequence*oversampling_ratio;
% len_sch_pre_training_sequence = 42;
% len_sch_pre_training_sequence_ov = len_sch_pre_training_sequence*oversampling_ratio;

% len_normal_training_sequence = 26;
% len_normal_training_sequence_ov = len_normal_training_sequence*oversampling_ratio;
% len_normal_pre_training_sequence = 61;
% len_normal_pre_training_sequence_ov = len_normal_pre_training_sequence*oversampling_ratio;

% % % show bursts in color series
% tmp = round( diff((pos_info(:,1).')./num_sym_per_frame_ov) );
% tmp = cumsum([1 tmp]);
% a = -1*ones(1, max(tmp));
% a(tmp) = pos_info(:,2).';
% b = -1*ones(1, max(tmp));
% pcolor([a;b]); colorbar; %shading flat; 
% % % disp( num2str( diff(pos_info(:,1).')./num_sym_per_frame_ov ) );
% % % disp( num2str( pos_info(:,2).' ) );

fcch_idx = (pos_info(:,2)==0);
fcch_pos = pos_info(fcch_idx,1);
num_fcch = length(fcch_pos);

len_FCCH_CW = 148; % GSM spec. 1x rate
fft_len = len_FCCH_CW*oversampling_ratio;

fcch_mat = zeros(fft_len, num_fcch);
for i=1:num_fcch
    sp = fcch_pos(i);
    fcch_mat(:,i) = s(sp:(sp+fft_len-1));
end
fd_fcch = abs(fft(fcch_mat, fft_len, 1)).^2;
fd_fcch = [fd_fcch( ((fft_len/2)+1):end, : ); fd_fcch( 1:(fft_len/2), : )];
[~, max_idx] = max(fd_fcch, [], 1);

int_phase_rotate = 2.*pi.*(max_idx - ((fft_len/2) + 1 ) )./fft_len;
fcch_mat = fcch_mat.*exp( -1i.*((0:(fft_len-1))')*int_phase_rotate );

phase_rotate = exp( 1i.*angle( fcch_mat(2:end,:) ) )./exp( 1i.*angle( fcch_mat(1:(end-1),:) ) );
phase_rotate = angle(mean(phase_rotate,1));
fo = sampling_rate.*(int_phase_rotate + phase_rotate)./(2*pi);
disp(['post SCH: FCCH freq ' num2str(fo)]);

fo = mean(fo);
disp(['post SCH: mean FCCH freq ' num2str(fo)]);

carrier_ppm = 1e6*(fo - target_freq)/carrier_freq;
disp(['post SCH: carrier error ppm ' num2str(carrier_ppm)]);

comp_freq = target_freq - fo;
comp_phase_rotate = comp_freq*2*pi/sampling_rate;
r = s.*exp(1i.*(0:(length(s)-1))'.*comp_phase_rotate);

% % fine residual frequency error estimation by 1 SCH + 4 BCCH
% % I find that the frequency error is very very very small. No need to estimate and compansate.
% num_bcch_used = 4;
% % num_sch_used = 1;
% % phase_vec = zeros(1, num_sch_used+num_bcch_used);
% 
% bcch_pos = pos_info(bcch_idx, 1);
% % tmp = find(bcch_idx, 1, 'first');
% % sch_pos = pos_info(tmp-1, 1);
% 
% % sp = sch_pos + len_sch_pre_training_sequence_ov;
% % phase_vec(1) = angle((sch_training_sequence')*r(sp: (sp+len_sch_training_sequence_ov-1)));
% 
% corr_mat = zeros(len_normal_training_sequence_ov, num_bcch_used);
% for i=1:num_bcch_used
%     sp = bcch_pos(i) + len_normal_pre_training_sequence_ov;
%     ep = sp + len_normal_training_sequence_ov - 1;
%     corr_mat(:,i) = r(sp:ep);
% end
% corr_val = (normal_training_sequence')*corr_mat;
% 
% [~, max_idx] = max(abs(corr_val), [], 1);
% if sum( abs(max_idx - mean(max_idx)) ) == 0
%     disp(['Normal training sequence idx (BCCH) ' num2str(max_idx(1))]);
%     normal_training_sequence_idx = max_idx(1);
% else
%     disp('Fail to identity normal training sequence idx (BCCH).');
%     return;
% end
% % phase_vec(2:end) = angle(corr_val(max_idx(i),:));
% % plot(angle(phase_vec(2:end)./phase_vec(1:end-1)));
% 
% % sch_idx = (pos_info(:,2)==1);
% % sch_pos = pos_info(sch_idx,1);
% % num_sch = length(sch_pos);
% % 
% % sp = sch_pos(1);
% % ep = sp + (num_sym_per_slot_ov-len_sch_training_sequence_ov);
% % len = ep - sp + 1;
% % corr_mat = toeplitz(r(sp:(ep+len_sch_training_sequence_ov-1)), [r(sp) zeros(1, len-1)]);
% % corr_mat = corr_mat(len:end, end:-1:1);
% % 
% % corr_val = abs((sch_training_sequence')*corr_mat).^2;
% % figure;
% % plot(corr_val');

% disp('post SCH: -------------------------test freq----------------------------')
% fcch_mat = zeros(fft_len, num_fcch);
% for i=1:num_fcch
%     sp = fcch_pos(i);
%     fcch_mat(:,i) = r(sp:(sp+fft_len-1));
% end
% fd_fcch = abs(fft(fcch_mat, fft_len, 1)).^2;
% fd_fcch = [fd_fcch( ((fft_len/2)+1):end, : ); fd_fcch( 1:(fft_len/2), : )];
% [~, max_idx] = max(fd_fcch, [], 1);
% 
% int_phase_rotate = 2.*pi.*(max_idx - ((fft_len/2) + 1 ) )./fft_len;
% fcch_mat = fcch_mat.*exp( -1i.*((0:(fft_len-1))')*int_phase_rotate );
% 
% phase_rotate = exp( 1i.*angle( fcch_mat(2:end,:) ) )./exp( 1i.*angle( fcch_mat(1:(end-1),:) ) );
% phase_rotate = angle(mean(phase_rotate,1));
% fo = sampling_rate.*(int_phase_rotate + phase_rotate)./(2*pi);
% disp(['post SCH: FCCH freq ' num2str(fo)]);
% 
% fo = mean(fo);
% disp(['post SCH: mean FCCH freq ' num2str(fo)]);
% 
% carrier_ppm = 1e6*(fo - target_freq)/carrier_freq;
% disp(['post SCH: carrier error ppm ' num2str(carrier_ppm)]);
