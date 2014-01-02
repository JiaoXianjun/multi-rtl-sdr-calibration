% Jiao Xianjun (putaoshu@msn.com; putaoshu@gmail.com)
% function scan_band_power_spectrum(start_freq, end_freq, freq_step, sample_rate, observe_time)
% all parameters are in Hz or Second.
% If you want to inspect power spectrum in GSM 900 downlink band,
% run command line first: ./rtl-sdr-relay -f 905000000 -s 100000 -b 8192 -l 8192
% Set all parameters like:

start_freq = 935e6; % P GSM
% start_freq = 925e6; % E GSM
% start_freq = 921e6; % R GSM
% start_freq = 915e6; % T GSM

end_freq = 960e6;
freq_step = 100e3;
sample_rate = 100e3; % this value will be set to rtl-sdr-relay via UDP packet
packet_len = 8192; % this value must be comformed with paramter -l of rtl-sdr-relay in command line
observe_time = 100e-3;

num_samples = observe_time*sample_rate;
num_recv = ceil(2*num_samples/packet_len);

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
set(udp_obj0, 'InputBufferSize', 2*num_recv*fread_len);
set(udp_obj0, 'Timeout', 40);
set(udp_obj1, 'InputBufferSize', 2*num_recv*fread_len);
set(udp_obj1, 'Timeout', 40);
time_to_flush_buffer = (2.1*num_recv*fread_len/2)/sample_rate;

fopen(udp_obj0);
fopen(udp_obj1);
clf;
close all;
num_frame = num_recv;

power_spectrum0 = inf.*ones(1, length(start_freq:freq_step:end_freq));
power_spectrum1 = inf.*ones(1, length(start_freq:freq_step:end_freq));
idx = 1;
for freq = start_freq:freq_step:end_freq
    fwrite(udp_obj0, int32(round([freq, 0, sample_rate])), 'int32');
    pause(time_to_flush_buffer);
    a0 = inf.*ones(fread_len, num_frame);
    a1 = inf.*ones(fread_len, num_frame);
    
    i = 1;
    while 1
        [tmp0, real_count0] = fread(udp_obj0, fread_len, 'uint8');
        [tmp1, real_count1] = fread(udp_obj1, fread_len, 'uint8');
        
        if ( real_count0~=fread_len || real_count1~=fread_len )
            disp(num2str([idx i fread_len, real_count0, real_count1]));
            continue;
        end
        
        a0(:, i) = tmp0;
        a1(:, i) = tmp1;
        
        if i == num_frame
            break;
        end
        
        i = i + 1;
    end

    % convert raw unsigned IQ samples to normal IQ samples for signal processing purpose
    s = raw2iq([a0(:), a1(:)]);
    
    % process samples from two dongles in two columns of varable s
    % add your routine here
    power_spectrum0(idx) = 10*log10(mean(abs(s(:,1)).^2));
    power_spectrum1(idx) = 10*log10(mean(abs(s(:,2)).^2));
    idx = idx + 1;
    
    if mod(idx, 50) == 0
        disp(freq);
    end
    
%     % show manitude of signlas from two dongles
%     subplot(2,1,1); plot(abs(s0));
%     subplot(2,1,2); plot(abs(s1));
%     drawnow;
end

plot((start_freq:freq_step:end_freq).*1e-6, power_spectrum0, 'b.-'); hold on;
plot((start_freq:freq_step:end_freq).*1e-6, power_spectrum1, 'r.-'); hold on; grid on;
legend('dongle 0', 'dongle 1');
