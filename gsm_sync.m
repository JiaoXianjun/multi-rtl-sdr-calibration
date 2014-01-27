% Jiao Xianjun (putaoshu@msn.com; putaoshu@gmail.com)
% try to have multiple dongles synchronized to the same GSM downlink FCCH SCH.
% Now only work for control channel multiframe of GSM downlink, which contain CCH, SCH, BCCH, CCCH
% run command line first (depends on how many dongles you have):
% rtl_tcp -p 1234 -d 0
% rtl_tcp -p 1235 -d 1
% rtl_tcp -p 1236 -d 2
% ...

num_dongle = 1;

freq = 940.8e6; % home. Find some GSM downlink signal by multi_rtl_sdr_gsm_FCCH_scanner.m!
% freq = 939e6; % home. Find some GSM downlink signal by multi_rtl_sdr_gsm_FCCH_scanner.m!
% freq = 957.4e6; % office. Find some GSM downlink signal by multi_rtl_sdr_gsm_FCCH_scanner.m!

symbol_rate = (1625/6)*1e3;
oversampling_ratio = 8;
decimation_ratio_for_FCCH_rough_position = 8;
decimation_ratio_from_oversampling = oversampling_ratio*decimation_ratio_for_FCCH_rough_position;

sampling_rate = symbol_rate*oversampling_ratio;

num_frame = 2*51; % two multiframe (each has 51 frames)
num_sym_per_slot = 625/4;
num_slot_per_frame = 8;

num_sample = oversampling_ratio * num_frame * num_slot_per_frame * num_sym_per_slot;
s = zeros(2*num_sample, num_dongle);
real_count = zeros(1, num_dongle);

% GSM channel filter for oversampling
coef = fir1(46, 200e3/sampling_rate);
% freqz(coef, 1, 1024);

% generate SCH training sequence
sch_training_sequence = gsm_SCH_training_sequence_gen(oversampling_ratio);
normal_training_sequence = gsm_normal_training_sequence_gen(oversampling_ratio);

format_string = {'b.-', 'r.-', 'k.-', 'g.-', 'c.-', 'm.-'};
clf;
close all;

if ~isempty(who('tcp_obj'))
    for i=1:length(tcp_obj)
        fclose(tcp_obj{i});
        delete(tcp_obj{i});
    end
    clear tcp_obj;
end

tcp_obj = cell(1, num_dongle);
for i=1:num_dongle
    tcp_obj{i} = tcpip('127.0.0.1', 1233+i); % for dongle i
end

for i=1:num_dongle
    set(tcp_obj{i}, 'InputBufferSize', 8*2*num_sample);
    set(tcp_obj{i}, 'Timeout', 1);
end
for i=1:num_dongle
    fopen(tcp_obj{i});
end

% set sampling rate
for i=1:num_dongle
    set_rate_tcp(tcp_obj{i}, sampling_rate);
end

% set frequency
for i=1:num_dongle
    set_freq_tcp(tcp_obj{i}, freq);
end

% flush
for i=1:num_dongle
    fread(tcp_obj{i}, 2*num_sample, 'uint8');
end

% % % --------------------------- read and processing ----------------------------------
% % % ---------------------------------------------------------------------------------
for idx=1:1
    while 1 % read data from multiple dongles until success
        for i=1:num_dongle
            [s(:, i), real_count(i)] = fread(tcp_obj{i}, 2*num_sample, 'uint8');
        end

        if sum(real_count-(2*num_sample)) ~= 0
            disp(num2str([idx 2*num_samples, real_count]));
        else
            break;
        end
    end

    % convert raw unsigned IQ samples to normal IQ samples for signal processing purpose
    r = raw2iq(s);

    % channel filter
    r = filter(coef, 1, r);
    
%     phase_seq = cell(1,2);
    for i=1:num_dongle
        disp(['dongle ' num2str(i) ' -------------------------------------------------------------------------']);
        FCCH_pos = FCCH_coarse_position(r(1:decimation_ratio_from_oversampling:end,i), decimation_ratio_for_FCCH_rough_position);
        [FCCH_pos, r_correct] = FCCH_fine_correction(r(:,i), FCCH_pos, oversampling_ratio, freq);
        [pos_info, r_correct] = SCH_corr_rate_correction(r_correct, FCCH_pos, sch_training_sequence, oversampling_ratio);
        r_correct = carrier_correct_post_SCH(r_correct, pos_info, oversampling_ratio, freq);
        FCCH_demod(r_correct, pos_info, oversampling_ratio, freq);
%                 disp(['FCCH demod freq ' num2str(fcch_freq)]);
%                 disp(['FCCH demod  snr ' num2str(fcch_snr)]);
%                 [demod_info_sch, chn_fd_sch] = SCH_demod(SCH_burst, sch_training_sequence, oversampling_ratio);
%                 [demod_info_bcch, chn_fd_bcch] = BCCH_demod(BCCH_burst, normal_training_sequence, oversampling_ratio);
%                 tmp = r_correct(1: (2*oversampling_ratio*num_slot_per_frame * num_sym_per_slot));
%                 subplot(num_dongle,1,i); plot(corr_val);
%                 subplot(2,1,i); plot(phase_seq{i});
%                 tmp = angle(tmp(2:end)./tmp(1:end-1));
%                 tmp = angle(tmp);
%                 fo = tmp.*sampling_rate./(2*pi);
%                 subplot(2,1,1); plot(angle(tmp), 'b'); hold on;
%                 subplot(2,1,2); plot(abs(tmp), 'b'); hold on;
%                 drawnow;
    end
%     figure; plot(phase_seq{1} - phase_seq{2});
end
% for i=1:num_dongle
%     figure(i);
%     plot(FCCH_pos(i), 'b*');
% end
% % % ---------------------------------------------------------------------------------
% % % --------------------------- end of read and processing ------------------------------

% close obj
for i=1:num_dongle
    fclose(tcp_obj{i});
end
for i=1:num_dongle
    delete(tcp_obj{i});
end
clear tcp_obj;
