% Jiao Xianjun (putaoshu@msn.com; putaoshu@gmail.com)
% function scan_band_power_spectrum_tcp(start_freq, end_freq, freq_step, RBW, gain, observe_time)
% all parameters are in Hz or Second.
% For example, you have two dongles, please run two rtl_tcp in command line firstly as:
% rtl_tcp -p 1234 -d 0
% rtl_tcp -p 1235 -d 1
% ATTENTION! every time before you run this script, please terminate two rtl_tcp and re-launch them again.
% Then set all parameters like:

% start_freq = 930e6;
% end_freq = 932e6;

start_freq = 935e6; % P GSM
% start_freq = 925e6; % E GSM
% start_freq = 921e6; % R GSM
% start_freq = 915e6; % T GSM
end_freq = 960e6;

freq_step = 100e3;

RBW = 50e3;

gain = 49; % 49.6dB is the maximum value for 820T tuner. You should find a appropriate value for your case

observe_time = 500e-3; % observation time at each frequency point

sample_rate = 1e6;

coef = fir1(31, RBW/sample_rate);

packet_len = 8192;

num_samples = observe_time*sample_rate;
num_recv = ceil(2*num_samples/packet_len);

if ~isempty(who('tcp_obj0'))
    fclose(tcp_obj0);
    delete(tcp_obj0);
    clear tcp_obj0;
end

if ~isempty(who('tcp_obj1'))
    fclose(tcp_obj1);
    delete(tcp_obj1);
    clear tcp_obj1;
end

tcp_obj0 = tcpip('127.0.0.1', 1234); % for dongle 0
tcp_obj1 = tcpip('127.0.0.1', 1235); % for dongle 1

fread_len = packet_len;
set(tcp_obj0, 'InputBufferSize', 4*num_recv*fread_len);
set(tcp_obj0, 'Timeout', 40);
set(tcp_obj1, 'InputBufferSize', 4*num_recv*fread_len);
set(tcp_obj1, 'Timeout', 40);

fopen(tcp_obj0);
fopen(tcp_obj1);
clf;
close all;
num_frame = num_recv;

power_spectrum0 = inf.*ones(1, length(start_freq:freq_step:end_freq));
power_spectrum1 = inf.*ones(1, length(start_freq:freq_step:end_freq));

set_gain_tcp(tcp_obj0, gain*10); %be careful, in rtl_sdr the 10x is done inside C program, but in rtl_tcp the 10x has to be done here.
set_gain_tcp(tcp_obj1, gain*10);

set_rate_tcp(tcp_obj0, sample_rate);
set_rate_tcp(tcp_obj1, sample_rate);

set_freq_tcp(tcp_obj0, start_freq);
set_freq_tcp(tcp_obj1, start_freq);
fread(tcp_obj0, 4*num_recv*fread_len, 'uint8');
fread(tcp_obj1, 4*num_recv*fread_len, 'uint8');
pause(1);

idx = 1;
for freq = start_freq:freq_step:end_freq
    set_freq_tcp(tcp_obj0, freq);
    set_freq_tcp(tcp_obj1, freq);

    a0 = inf.*ones(fread_len, num_frame);
    a1 = inf.*ones(fread_len, num_frame);
    
    i = 1;
    while 1
        [tmp0, real_count0] = fread(tcp_obj0, fread_len, 'uint8');
        [tmp1, real_count1] = fread(tcp_obj1, fread_len, 'uint8');
        
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
    s = filter(coef, 1, s);

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

fclose(tcp_obj0);
delete(tcp_obj0);
clear tcp_obj0;

fclose(tcp_obj1);
delete(tcp_obj1);
clear tcp_obj1;
