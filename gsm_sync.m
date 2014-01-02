% Jiao Xianjun (putaoshu@msn.com; putaoshu@gmail.com)
% try to have two dongles synchronized to the same GSM downlink FCCH SCH
% run command line first: ./rtl-sdr-relay -b 8192 -l 8192

% freq = 957.4e6;
freq = 957.6e6;
% freq = 957.8e6;

% freq = 956.2e6;
% freq = 956.4e6;
% freq = 956.6e6;

% freq = 942.6e6;
% freq = 939.2e6;
% freq = 942.8e6;
% freq = 958.8e6;

symbol_rate = (1625/6)*1e3;
oversampling_ratio = 4;
sampling_rate = symbol_rate*oversampling_ratio;

inspection_time = 200e-3; % unit: second
packet_len = 8192; % this value must be comformed with paramter -l of rtl-sdr-relay in command line

num_frame = ceil( (inspection_time*sampling_rate*2)/packet_len );

if ~isempty(who('udp_obj0'))
    fclose(udp_obj0);
    delete(udp_obj0);
    clear udp_obj0;
end

if ~isempty(who('udp_obj1'))
    fclose(udp_obj1);
    delete(udp_obj1);
    clear udp_obj1;
end

udp_obj0 = udp('127.0.0.1', 13485, 'LocalPort', 6666); % for dongle 0
udp_obj1 = udp('127.0.0.1', 13485, 'LocalPort', 6667); % for dongle 1

fread_len = packet_len;
set(udp_obj0, 'InputBufferSize', 2*num_frame*fread_len);
set(udp_obj0, 'Timeout', 40);
set(udp_obj1, 'InputBufferSize', 2*num_frame*fread_len);
set(udp_obj1, 'Timeout', 40);
% time_to_flush_buffer = (2.1*num_frame*fread_len/2)/sample_rate;

fopen(udp_obj0);
fopen(udp_obj1);
clf;
close all;

% set frequency gain and sampling rate
fwrite(udp_obj0, int32(round([freq, 0, sampling_rate])), 'int32');
pause(time_to_flush_buffer);

sampling_rate_4x = sampling_rate;
idx = 1;
while 1
%     % set frequency gain and sampling rate
%     fwrite(udp_obj0, int32(round([freq, 0, sampling_rate])), 'int32');
%     pause(time_to_flush_buffer);
    
    a0 = inf.*ones(fread_len, num_frame);
    a1 = inf.*ones(fread_len, num_frame);
    good_flag = true;
    for i=1:num_frame  % get many frame in one signal sequence
        [tmp0, real_count0] = fread(udp_obj0, fread_len, 'uint8');
        [tmp1, real_count1] = fread(udp_obj1, fread_len, 'uint8');
        
        if ( real_count0~=fread_len || real_count1~=fread_len )
            good_flag = false;
            disp(num2str([idx i fread_len, real_count0, real_count1]));
            break;
        end
        
        a0(:, i) = tmp0;
        a1(:, i) = tmp1;
    end

    if good_flag
        % convert raw unsigned IQ samples to normal IQ samples for signal processing purpose
        s = raw2iq([a0(:), a1(:)]);

        % process signal
%         s = chn_filter_8x_4x(s);
        s = chn_filter_4x(s);

        [FCCH_pos, metric_data] = FCCH_coarse_position(s, sampling_rate_4x);

        subplot(2,2,1); plot(FCCH_pos(:,1));
        subplot(2,2,2); plot(metric_data(:,1));
        subplot(2,2,3); plot(FCCH_pos(:,2));
        subplot(2,2,4); plot(metric_data(:,2));
        drawnow;
    end
    idx = idx + 1;
end
