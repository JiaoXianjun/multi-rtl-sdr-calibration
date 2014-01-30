% Jiao Xianjun (putaoshu@msn.com; putaoshu@gmail.com)
% try to have multiple dongles synchronized to the same GSM downlink FCCH SCH.
% Now only work for control channel multiframe of GSM downlink, which contain CCH, SCH, BCCH, CCCH
% run command line first (depends on how many dongles you have):
% rtl_tcp -p 1234 -d 0
% rtl_tcp -p 1235 -d 1
% rtl_tcp -p 1236 -d 2
% ...

num_dongle = 2;

% freq = 940.8e6; % home. Find some GSM downlink signal by multi_rtl_sdr_gsm_FCCH_scanner.m!
% freq = 939e6; % home. Find some GSM downlink signal by multi_rtl_sdr_gsm_FCCH_scanner.m!
freq = 957.4e6; % office. Find some GSM downlink signal by multi_rtl_sdr_gsm_FCCH_scanner.m!

symbol_rate = (1625/6)*1e3;
oversampling_ratio = 8;
decimation_ratio_for_FCCH_rough_position = 8;
decimation_ratio_from_oversampling = oversampling_ratio*decimation_ratio_for_FCCH_rough_position;

sampling_rate = symbol_rate*oversampling_ratio;

num_frame = 2*51; % two multiframe (each has 51 frames)
num_sym_per_slot = 625/4;
num_slot_per_frame = 8;
num_sym_per_frame = num_sym_per_slot*num_slot_per_frame;
num_sym_per_frame_ov = num_sym_per_frame * oversampling_ratio;

num_sample = num_sym_per_frame_ov * num_frame;
s = zeros(2*num_sample, num_dongle);
real_count = zeros(1, num_dongle);

% GSM channel filter for oversampling
coef = fir1(46, 200e3/sampling_rate);
% freqz(coef, 1, 1024);

% generate SCH training sequence
sch_training_sequence = gsm_SCH_training_sequence_gen(oversampling_ratio);
normal_training_sequence = gsm_normal_training_sequence_gen(oversampling_ratio);

sampling_ppm = zeros(1,2);
carrier_ppm = zeros(1,2);
pos_info = cell(1, num_dongle);
num_pos = zeros(1, num_dongle);

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

% set gain
for i=1:num_dongle
    set_gain_tcp(tcp_obj{i}, 0);
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
    
    for i=1:num_dongle
        disp(' ');
        disp(['dongle ' num2str(i) ' -------------------------------------------------------------------------']);
        
        % % -----------do synchronization by FCCH and SCH------------------------------------------
        FCCH_pos = FCCH_coarse_position(r(1:decimation_ratio_from_oversampling:end,i), decimation_ratio_for_FCCH_rough_position);
        [FCCH_pos, r_correct, sampling_ppm(1), carrier_ppm(1)] = FCCH_fine_correction(r(:,i), FCCH_pos, oversampling_ratio, freq);
        [pos_info{i}, r_correct, sampling_ppm(2)] = SCH_corr_rate_correction(r_correct, FCCH_pos, sch_training_sequence, oversampling_ratio);
        [r_correct, carrier_ppm(2)] = carrier_correct_post_SCH(r_correct, pos_info{i}, oversampling_ratio, freq);
        
        % % -----------calculate and display total sampling PPM and carrier PPM of each dongle------
        sampling_ppm = total_ppm_calculation(sampling_ppm);
        carrier_ppm = total_ppm_calculation(carrier_ppm);
        disp(' ');
        disp(['Total sampling PPM ' num2str(sampling_ppm) ' Total carrier PPM ' num2str(carrier_ppm) ]);
        
        % % -----------display FCCH, SCH and BCCH position of each dongle----------------------------
        subplot(num_dongle+1,1,i);
        pos_tmp = pos_info{i}; num_pos(i) = length(pos_tmp(:,1));
        a = NaN(1, max(round( pos_tmp(:,1)./num_sym_per_frame_ov )));
        a(round(pos_tmp(pos_tmp(:,2)==0,1)./num_sym_per_frame_ov)) = 0;
        a(round(pos_tmp(pos_tmp(:,2)==1,1)./num_sym_per_frame_ov)) = 1;
        a(round(pos_tmp(pos_tmp(:,2)==2,1)./num_sym_per_frame_ov)) = 2;
        b = [a;a]; pcolor(b); colorbar;
        if i==1
            xlabel('GSM frame index. (8 slot per frame; FCCH/SCH/BCCH only in 1st slot)');
        end
        if i==1
            title('color 0 -- FCCH; color 1 -- SCH; color 2 -- BCCH');
        end
        
        % % -----------demodulation is still under development---------------------------------------
%         FCCH_demod(r_correct, pos_info, oversampling_ratio, freq);
        SCH_demod(r_correct, pos_info{i}, sch_training_sequence, oversampling_ratio);
%         BCCH_demod(BCCH_burst, normal_training_sequence, oversampling_ratio);
    end
    
    % % ----------display sampling phase difference between two dongles------------------------------
    subplot(num_dongle+1,1,num_dongle+1);
    if num_dongle==2
        [num_pos, min_idx] = min(num_pos);
        pos_tmp1 = pos_info{1}; pos_tmp1 = pos_tmp1(1:num_pos,1);
        pos_tmp2 = pos_info{2}; pos_tmp2 = pos_tmp2(1:num_pos,1);
        pos_tmp = pos_info{min_idx};
        plot(round(pos_tmp(:,1)./num_sym_per_frame_ov), pos_tmp2 - pos_tmp1, 'b.'); colorbar;
        ylabel(['diff(1/' num2str(oversampling_ratio) ')']); xlabel('GSM frame index');
        title(['sampling phase difference between two dongles (' num2str(oversampling_ratio) 'X oversampling)']);
    else
        text(0.05,0.5,'Sampling phase difference is only displayed for two dongles case!');
    end
    
end
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
