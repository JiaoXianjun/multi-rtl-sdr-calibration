% Jiao Xianjun (putaoshu@msn.com; putaoshu@gmail.com)
% try to have multiple dongles synchronized to the same GSM downlink FCCH SCH
% run command line first (depends on how many dongles you have):
% rtl_tcp -p 1234 -d 0
% rtl_tcp -p 1235 -d 1
% rtl_tcp -p 1236 -d 2
% ...

num_dongle = 1;

freq = 939e6;
% freq = 957.4e6; % find some GSM downlink signal by multi_rtl_sdr_diversity_scanner.m!

symbol_rate = (1625/6)*1e3;
oversampling_ratio = 4;
sampling_rate = symbol_rate*oversampling_ratio;

num_frame = 51;
num_sym_per_slot = 625/4;
num_slot_per_frame = 8;

num_sample = oversampling_ratio * num_frame * num_slot_per_frame * num_sym_per_slot;

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
    set(tcp_obj{i}, 'InputBufferSize', 4*num_sample);
    set(tcp_obj{i}, 'Timeout', 60);
    fopen(tcp_obj{i});
end

clf;
close all;

% set frequency gain and sampling rate
% set sampling rate
for i=1:num_dongle
    set_rate_tcp(tcp_obj{i}, sampling_rate);
end

% set frequency
for i=1:num_dongle
    set_freq_tcp(tcp_obj{i}, freq);
end

sampling_rate_4x = sampling_rate;
idx = 1;
s = zeros(2*num_sample, num_dongle);
real_count = zeros(1, num_dongle);
while 1
    while 1 % read data at current frequency until success
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

    % process signal
%         s = chn_filter_8x_4x(s);
    r = chn_filter_4x(r);

    [FCCH_pos, metric_data] = FCCH_coarse_position(r, sampling_rate_4x);

    for i=1:num_dongle
        figure(i);
        subplot(2,1,1); plot(FCCH_pos(:,i));
        subplot(2,1,2); plot(metric_data(:,i));
    end
    drawnow;
    
    idx = idx + 1;
end

for i=1:num_dongle
    fclose(tcp_obj{i});
    delete(tcp_obj{i});
end
clear tcp_obj;
