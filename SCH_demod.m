% Jiao Xianjun (putaoshu@msn.com; putaoshu@gmail.com)
% GSM SCH demodulator
% A script of project: https://github.com/JiaoXianjun/multi-rtl-sdr-calibration

function SCH_demod(s, pos_info, training_sequence, oversampling_ratio)
disp(' ');

if pos_info==-1
    disp('SCH demod: Warning! No valid position information!');
    return;
end

sch_idx = (pos_info(:,2)==1);
sch_pos = pos_info(sch_idx, 1);
num_sch = length(sch_pos);

num_sym_per_slot = 625/4;
num_sym_per_slot_ov = num_sym_per_slot*oversampling_ratio;
symbol_rate = (1625/6)*1e3;
sampling_rate = symbol_rate*oversampling_ratio;
len_GP = 8.25;
num_ef_sym_per_slot = round(num_sym_per_slot-len_GP);
num_ef_sym_per_slot_ov = num_ef_sym_per_slot*oversampling_ratio;

len_training_sequence = 64;
len_training_sequence_ov = len_training_sequence*oversampling_ratio;
len_pre_training_sequence = 42;
len_pre_training_sequence_ov = len_pre_training_sequence*oversampling_ratio;

% % % % ----------show self correlation of training sequence------------
% x = [zeros(len_training_sequence_ov-1, 1); training_sequence; zeros(len_training_sequence_ov-1, 1)];
% sp = 1;
% ep = 2*len_training_sequence_ov-1;
% len = ep - sp + 1;
% corr_mat = toeplitz(x(sp:(ep+len_training_sequence_ov-1)), [x(sp) zeros(1, len-1)]);
% corr_mat = corr_mat(len:end, end:-1:1);
% 
% corr_val = abs((training_sequence')*corr_mat).^2;
% figure;
% plot(corr_val);
% % % %-----end of show self correlation of training sequence----------

% max_offset = 8.5*oversampling_ratio;

TracebackDepth = 30;

data = [1, 0, 1, 1, 1, 0, 0, 1, 0, 1, 1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 1, 0, ...
0, 0, 0, 0, 0, 1, 1, 1, 1, 0, 0, 1, 0, 1, 1, 0, 1, 0, 1, 0, 0, 0, ...
1, 0, 1, 0, 1, 1, 1, 0, 1, 1, 0, 0, 0, 0, 1, 1, 0, 1, 1];
data = ~abs(diff([0 data]));
data = 2.*data-1;

ex_len = 8;
len_fde = num_ef_sym_per_slot + 2*ex_len + TracebackDepth;
len_fde_ov = len_fde*oversampling_ratio;
sp_of_training = (ex_len + len_pre_training_sequence)*oversampling_ratio + 1;
td_training_ov = zeros(1, len_fde_ov);
td_training_ov(sp_of_training : (sp_of_training + len_training_sequence_ov - 1)) = training_sequence;
fd_training_ov = fft(td_training_ov);

hDemod = comm.GMSKDemodulator('BitOutput', true, 'BandwidthTimeProduct', 0.3, 'PulseLength', 4, 'SamplesPerSymbol', oversampling_ratio, 'TracebackDepth', TracebackDepth, 'InitialPhaseOffset', 0);

for i=1:num_sch
%     disp(['SCH_demod: ' num2str(i)]);
    
%     sp = sch_pos(i) + (len_pre_training_sequence_ov) - 10*oversampling_ratio;
%     ep = sch_pos(i) + (len_pre_training_sequence_ov) + 10*oversampling_ratio;
% 
%     len = ep - sp + 1;
% 
%     corr_mat = toeplitz(s(sp:(ep+len_training_sequence_ov-1)), [s(sp) zeros(1, len-1)]);
%     corr_mat = corr_mat(len:end, end:-1:1);
% 
%     corr_val = (training_sequence')*corr_mat;
%     len = length(( (sch_pos(i)-8.25*oversampling_ratio) : (sch_pos(i) + num_sym_per_slot*oversampling_ratio-1) ));
%     figure;
%     subplot(3,1,3); plot(1:len, kron(ones(1, len), angle(corr_val)), 'r'); hold on;

    sp = sch_pos(i)-ex_len*oversampling_ratio;
    ep = sp + len_fde_ov - 1;
    x = s(sp:ep);
    
    received_training_ov = zeros(1, len_fde_ov);
    received_training_ov(sp_of_training : (sp_of_training + len_training_sequence_ov - 1)) = x(sp_of_training : (sp_of_training + len_training_sequence_ov - 1));
    fd_received_training = fft(received_training_ov);
    fd_chn = fd_received_training./fd_training_ov;
    
    fd_x = fft(x);
    fd_x = fd_x./(fd_chn.');
    x = ifft(fd_x);
    
    reset(hDemod);
    demod_bits = step(hDemod, x);
    demod_bits = demod_bits((TracebackDepth+ex_len+1) : end).';
    demod_bits = demod_bits(1:num_ef_sym_per_slot);
%     disp([num2str(length(demod_bits)) 'bits: ' num2str(demod_bits)]);
    
    bits_to_decoder = abs(diff([0 ~demod_bits]));
    % % % --------test if it is self consistent ------------------
    tmp = ~abs(diff([0 bits_to_decoder]));
%     disp(['test anti-diff decoder cosistency: ' num2str(sum(abs(tmp - demod_bits)))]);
    % % % --------end of test if it is self consistent ------------------
    
    demod_bits = 2.*demod_bits - 1;
    
    sp = 1;
    ep = num_ef_sym_per_slot - len_training_sequence + 1;
    len = ep - sp + 1;
    corr_mat = toeplitz(demod_bits(sp:(ep+len_training_sequence-1)), [demod_bits(sp) zeros(1, len-1)]);
    corr_mat = corr_mat(len:end, end:-1:1);

    corr_val = data*corr_mat;
%     figure;
%     subplot(3,1,1); plot(corr_val);
%     x = x((ex_len*oversampling_ratio+1):(ex_len*oversampling_ratio+num_sym_per_slot_ov));
%     subplot(3,1,2); plot(abs(x));
%     freq = sampling_rate.*angle(x(2:end)./x(1:end-1))./(2.*pi);
%     subplot(3,1,3); plot(freq); hold on;
% %     figure;
% %     plot(corr_val);
end
