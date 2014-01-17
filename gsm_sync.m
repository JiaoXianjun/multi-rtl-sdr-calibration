% Jiao Xianjun (putaoshu@msn.com; putaoshu@gmail.com)
% try to have multiple dongles synchronized to the same GSM downlink FCCH SCH.
% Now only work control channel multiframe of GSM downlink, which contain CCH, SCH, BCCH, CCCH
% run command line first (depends on how many dongles you have):
% rtl_tcp -p 1234 -d 0
% rtl_tcp -p 1235 -d 1
% rtl_tcp -p 1236 -d 2
% ...

num_dongle = 1;

% freq = 939e6; % home
freq = 957.4e6; % office. find some GSM downlink signal by multi_rtl_sdr_diversity_scanner.m!

symbol_rate = (1625/6)*1e3;
oversampling_ratio = 4;
sampling_rate = symbol_rate*oversampling_ratio;

num_frame = 51; % at least 51 frame to ensure FCCH is there.
num_sym_per_slot = 625/4;
num_slot_per_frame = 8;

num_sample = oversampling_ratio * num_frame * num_slot_per_frame * num_sym_per_slot;
s = zeros(2*num_sample, num_dongle);
real_count = zeros(1, num_dongle);

clf;
close all;

if ~isempty(who('tcp_obj'))
    for i=1:length(tcp_obj)
        fclose(tcp_obj{i});
        pause(1);
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
fread(tcp_obj{i}, 2*num_sample, 'uint8');

% % % --------------------------- read and processing ----------------------------------
% % % ---------------------------------------------------------------------------------
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
r = chn_filter_4x(r);

for i=1:num_dongle
    FCCH_pos = FCCH_coarse_position(r(:,i), oversampling_ratio);
    [SCH_pos, r_rate_correct] = SCH_corr_rate_correction(r(FCCH_pos:end,i), oversampling_ratio);
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
    pause(1);
    delete(tcp_obj{i});
end
clear tcp_obj;
