% Jiao Xianjun (putaoshu@msn.com; putaoshu@gmail.com)
% Frequency band scanning and incoherent combination via multiple rtl-sdr dongles.
% A script of project: https://github.com/JiaoXianjun/multi-rtl-sdr-calibration

% Assume that you have installed rtl-sdr
% (http://sdr.osmocom.org/trac/wiki/rtl-sdr) and have those native utilities run correctly already.

% For example, you have multiple dongles, please run multiple rtl_tcp in multiple shell respectively as:
% rtl_tcp -p 1234 -d 0
% rtl_tcp -p 1235 -d 1
% rtl_tcp -p 1236 -d 3
% ...

% Then run this script in MATLAB.

% ATTENTION! In some computer, every time before you run this script, maybe you need to terminate multiple rtl_tcp and re-launch them again.

% Change following parameters as you need:

% Number of dongles you have connected to your computer
num_dongle = 1;

% Beginning of the band you are interested in
% start_freq = 910e6; % for test
start_freq = 935e6; % Beginning of Primary GSM-900 Band downlink
% start_freq = (1575.42-15)*1e6; % GPS L1
% start_freq = (1207.14-30)*1e6; % COMPASS B2I
% start_freq = (1561.098-30)*1e6; % COMPASS B1I
% start_freq = 1.14e9; % Beginning of GNSS(GPS/GLONASS/COMPASS/Galileo) Band

% End of the band you are interested in
% end_freq = 920e6; % for test
end_freq = 960e6; % End of Primary GSM-900 Band downlink
% end_freq = (1575.42+30)*1e6; % GPS L1
% end_freq = (1207.14+30)*1e6; % COMPASS B2I
% end_freq = (1561.098+30)*1e6; % COMPASS B1I
% end_freq = 1.63e9; % Beginning of GNSS(GPS/GLONASS/COMPASS/Galileo) Band

freq_step = 0.05e6; % less step, higher resolution, narrower FIR bandwidth, slower speed

observe_time = 0.2; % observation time at each frequency point. ensure it can capture your signal!

RBW = freq_step; % Resolution Bandwidth each time we inspect

gain = 0; % If this is larger than 0, the fixed gain will be set to dongles

% use high sampling rate and FIR to improve estimation accuracy
sample_rate = 2.048e6; % sampling rate of dongles

coef_order = (2^(ceil(log2(sample_rate/RBW))))-1;
coef_order = min(coef_order, 127);
coef_order = max(coef_order, 31);
coef = fir1(coef_order, RBW/sample_rate);
% freqz(coef, 1, 1024);

num_samples = observe_time*sample_rate;

clf;
close all;

real_count = zeros(1, num_dongle);
freq = start_freq:freq_step:end_freq;

s_all = uint8( zeros(2*num_samples, length(freq), num_dongle) );
decimate_ratio = floor(sample_rate/(2*RBW));

% check if previous tce objects existed. if so clear them
if ~isempty(who('tcp_obj'))
    for i=1:length(tcp_obj)
        fclose(tcp_obj{i});
        delete(tcp_obj{i});
    end
    clear tcp_obj;
end

% construct tcp objects
tcp_obj = cell(1, num_dongle);
for i=1:num_dongle
    tcp_obj{i} = tcpip('127.0.0.1', 1233+i); % for dongle i
end

% set some parameters to tcp objects, and open them.
for i=1:num_dongle
    set(tcp_obj{i}, 'InputBufferSize', 8*2*num_samples);
    set(tcp_obj{i}, 'Timeout', 60);
    fopen(tcp_obj{i});
end

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
    fread(tcp_obj{i}, 8*2*num_samples, 'uint8');
end

% capture samples of all frequencies firstly!
for freq_idx = 1:length(freq)
    current_freq = freq(freq_idx);
    
    while 1 % read data at current frequency until success
        for i=1:num_dongle
            set_freq_tcp(tcp_obj{i}, current_freq); % set current frequency
            [s_all(:,freq_idx,i), real_count(i)] = fread(tcp_obj{i}, 2*num_samples, 'uint8');
        end

        if sum(real_count-(2*num_samples)) ~= 0
            disp(num2str([idx 2*num_samples, real_count]));
        else
            break;
        end
    end
end

% close TCP
for i=1:num_dongle
    fclose(tcp_obj{i});
    delete(tcp_obj{i});
end
clear tcp_obj;

disp('Scanning done!');
disp(' ');
disp('Begin process ...');

% generate power spectrum
power_spectrum = zeros(num_dongle, length(freq));
for i=1:num_dongle
    r = raw2iq( double( s_all(:,:,i) ) ); % remove DC. complex number constructed.
    r_flt = filter(coef, 1, r);% filter target band out
    r_flt = r_flt(1:decimate_ratio:end, :);% decimation
    power_spectrum(i, :) = mean(abs(r_flt).^2, 1);% get averaged power
end

% plot power spectrum (converted to dB)
figure;
format_string = {'b.-', 'r.-', 'k.-', 'm.-'};
for i=1:num_dongle
    plot((start_freq:freq_step:end_freq).*1e-6, 10.*log10(power_spectrum(i,:)), format_string{i}); hold on;
end

legend_string = cell(1, num_dongle);
for i=1:num_dongle
    legend_string{i} = ['dongle ' num2str(i)];
end
legend(legend_string);

% plot combined power spectrum (converted to dB)
figure;
power_spectrum_combine = mean(power_spectrum, 1);
plot((start_freq:freq_step:end_freq).*1e-6, 10.*log10(power_spectrum_combine), 'b.-');

filename = ['scan_' num2str(start_freq) '_' num2str(end_freq) '_gain' num2str(gain) '_' num2str(num_dongle) 'dongles.mat'];
save(filename, 'power_spectrum', 'power_spectrum_combine', 'start_freq', 'end_freq', 'freq_step', 'observe_time', 'RBW', 'gain', 'sample_rate', 'coef');
