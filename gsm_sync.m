% Jiao Xianjun (putaoshu@msn.com; putaoshu@gmail.com)
% try to have multiple dongles synchronized to the same GSM downlink FCCH SCH
% run command line first (depends on how many dongles you have):
% rtl_tcp -p 1234 -d 0
% rtl_tcp -p 1235 -d 1
% rtl_tcp -p 1236 -d 2
% ...

num_dongle = 2;

freq = 957.4e6; % find some GSM like signal by scan_band_power_spectrum_tcp.m!

symbol_rate = (1625/6)*1e3;
oversampling_ratio = 4;
sampling_rate = symbol_rate*oversampling_ratio;

inspection_time = 200e-3; % unit: second
packet_len = 8192; % this value must be comformed with paramter -l of rtl-sdr-relay in command line

num_frame = ceil( (inspection_time*sampling_rate*2)/packet_len );

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

fread_len = packet_len;
for i=1:num_dongle
    set(tcp_obj{i}, 'InputBufferSize', 4*num_frame*fread_len);
    set(tcp_obj{i}, 'Timeout', 40);
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

% % read and discard to flush
% for i=1:num_dongle
%     fread(tcp_obj{i}, 4*num_frame*fread_len, 'uint8');
% end
% 
% % read and discard to flush
% for i=1:num_dongle
%     fread(tcp_obj{i}, 4*num_frame*fread_len, 'uint8');
% end
% 
% pause(1);

sampling_rate_4x = sampling_rate;
idx = 1;
s = zeros(num_frame*fread_len, num_dongle);
tmp = zeros(fread_len, num_dongle);
real_count = zeros(1, num_dongle);
while 1
    good_flag = true;
    for frame_idx=1:num_frame  % get many frame in one signal sequence
        for i=1:num_dongle
            [tmp(:,i), real_count(i)] = fread(tcp_obj{i}, fread_len, 'uint8');
        end
        
        if sum(real_count-fread_len) ~= 0
            good_flag = false;
            disp(num2str([idx frame_idx fread_len, real_count]));
            break;
        end
        
        for i=1:num_dongle
            s( ((frame_idx-1)*fread_len + 1) : (frame_idx*fread_len), i) = tmp(:,i);
        end
    end

    if good_flag
        % convert raw unsigned IQ samples to normal IQ samples for signal processing purpose
        s = raw2iq(s);

        % process signal
%         s = chn_filter_8x_4x(s);
        s = chn_filter_4x(s);

        [FCCH_pos, metric_data] = FCCH_coarse_position(s, sampling_rate_4x);

        for i=1:num_dongle
            figure(i);
            subplot(2,1,1); plot(FCCH_pos(:,i));
            subplot(2,1,2); plot(metric_data(:,i));
        end
        drawnow;
    end
    idx = idx + 1;
end

for i=1:num_dongle
    fclose(tcp_obj{i});
    delete(tcp_obj{i});
end
clear tcp_obj;
