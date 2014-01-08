% Jiao Xianjun (putaoshu@msn.com; putaoshu@gmail.com)
% function scan_band_power_spectrum_tcp(start_freq, end_freq, freq_step, RBW, gain, observe_time)
% all parameters are in Hz or Second.
% For example, you have two dongles, please run two rtl_tcp in command line firstly as:
% rtl_tcp -p 1234 -d 0
% rtl_tcp -p 1235 -d 1
% ATTENTION! every time before you run this script, please terminate two rtl_tcp and re-launch them again.
% Then set all parameters like:

num_dongle = 2; % change it according to the number of dongles you have

% start_freq = 913e6;
% end_freq = 917e6;

% start_freq = 1875e6;
% end_freq = 1905e6;

start_freq = 935e6; % P GSM
% start_freq = 925e6; % E GSM
% start_freq = 921e6; % R GSM
% start_freq = 915e6; % T GSM
end_freq = 960e6;

freq_step = 100e3;

RBW = 50e3; % resolution bandwidth each time we inspect

gain = 49; % 49.6dB is the maximum value for 820T tuner. You should find a appropriate value for your case

observe_time = 1; % observation time at each frequency point

sample_rate = 2.048e6;

coef = fir1(31, RBW/sample_rate);

packet_len = 8192;

num_samples = observe_time*sample_rate;
num_recv = ceil(2*num_samples/packet_len);

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
    set(tcp_obj{i}, 'InputBufferSize', 4*num_recv*fread_len);
    set(tcp_obj{i}, 'Timeout', 40);
    fopen(tcp_obj{i});
end

clf;
close all;

num_frame = num_recv;

power_spectrum = inf.*ones(num_dongle, length(start_freq:freq_step:end_freq));

% set gain
for i=1:num_dongle
    set_gain_tcp(tcp_obj{i}, gain*10); %be careful, in rtl_sdr the 10x is done inside C program, but in rtl_tcp the 10x has to be done here.
end

% set sampling rate
for i=1:num_dongle
    set_rate_tcp(tcp_obj{i}, sample_rate);
end

% set frequency
for i=1:num_dongle
    set_freq_tcp(tcp_obj{i}, start_freq);
end

% read and discard to flush
for i=1:num_dongle
    fread(tcp_obj{i}, 4*num_recv*fread_len, 'uint8');
end

% read and discard to flush
for i=1:num_dongle
    fread(tcp_obj{i}, 4*num_recv*fread_len, 'uint8');
end

pause(1);

idx = 1;
s = zeros(num_frame*fread_len, num_dongle);
tmp = zeros(fread_len, num_dongle);
real_count = zeros(1, num_dongle);
for freq = start_freq:freq_step:end_freq
    % set target frequency
    for i=1:num_dongle
        set_freq_tcp(tcp_obj{i}, freq);
    end
    
    % read and discard to flush
    for i=1:num_dongle
        fread(tcp_obj{i}, num_recv*fread_len, 'uint8');
    end

    frame_idx = 1;
    while 1
        for i=1:num_dongle
            [tmp(:,i), real_count(i)] = fread(tcp_obj{i}, fread_len, 'uint8');
        end
        
        if sum(real_count-fread_len) ~= 0
            disp(num2str([idx frame_idx fread_len, real_count]));
            continue;
        end
        
        for i=1:num_dongle
            s( ((frame_idx-1)*fread_len + 1) : (frame_idx*fread_len), i) = tmp(:,i);
        end
        
        if frame_idx == num_frame
            break;
        end
        
        frame_idx = frame_idx + 1;
    end
    
    % convert raw unsigned IQ samples to normal IQ samples for signal processing purpose
    s = raw2iq(s);
    
    % process samples from two dongles in two columns of varable s
    % add your routine here
    s = filter(coef, 1, s);

    % get averaged power and convert it to dB
    for i=1:num_dongle
        power_spectrum(i, idx) = 10*log10(mean(abs(s(:,i)).^2));
    end

    idx = idx + 1;
    
    if mod(idx, 50) == 0
        disp(freq);
    end
    
%     % show manitude of signlas from two dongles
%     subplot(2,1,1); plot(abs(s0));
%     subplot(2,1,2); plot(abs(s1));
%     drawnow;
end

% plot power spectrum
format_string = {'b.-', 'r.-', 'k.-', 'm.-'};
for i=1:num_dongle
    plot((start_freq:freq_step:end_freq).*1e-6, power_spectrum(i,:), format_string{i}); hold on;
end

legend_string = cell(1, num_dongle);
for i=1:num_dongle
    legend_string{i} = ['dongle ' num2str(i)];
end
legend(legend_string);

for i=1:num_dongle
    fclose(tcp_obj{i});
    delete(tcp_obj{i});
end
clear tcp_obj;
