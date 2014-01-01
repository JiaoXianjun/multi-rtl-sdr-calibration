% Jiao Xianjun (putaoshu@msn.com; putaoshu@gmail.com)
% try to have two dongles synchronized to the same GSM downlink FCCH SCH
% run command line first: ./rtl-sdr-relay -b 512 -l 512

freq = 956.4e6;
% freq = 942.6e6;
% freq = 957.8e6;
% freq = 939.2e6;
% freq = 942.8e6;
% freq = 958.8e6;

symbol_rate = (1625/6)*1e3;
oversampling_ratio = 8;
sampling_rate = symbol_rate*oversampling_ratio;

packet_len = 512; % this value must be comformed with paramter -l of rtl-sdr-relay in command line

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
set(udp_obj0, 'InputBufferSize', fread_len);
set(udp_obj0, 'Timeout', 40);
set(udp_obj1, 'InputBufferSize', fread_len);
set(udp_obj1, 'Timeout', 40);

fopen(udp_obj0);
fopen(udp_obj1);
clf;
close all;

% set frequency gain and sampling rate
fwrite(udp_obj0, int32(round([freq, 0, sample_rate])), 'int32');

while 1

    [tmp0, real_count0] = fread(udp_obj0, fread_len, 'uint8');
    [tmp1, real_count1] = fread(udp_obj1, fread_len, 'uint8');

    if ( real_count0~=fread_len || real_count1~=fread_len )
        continue;
    end

    % convert raw unsigned IQ samples to normal IQ samples for signal processing purpose
    s0 = a0';
    s0 = raw2iq(s0(:)');
    s1 = a1';
    s1 = raw2iq(s1(:)');

end
