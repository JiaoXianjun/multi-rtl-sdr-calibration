% Jiao Xianjun (putaoshu@msn.com; putaoshu@gmail.com)
% Frequency band scanning and incoherent combination via multiple rtl-sdr dongles.

% Assume that you have installed rtl-sdr
% (http://sdr.osmocom.org/trac/wiki/rtl-sdr) and have those native utilities run correctly already.

% For example, you have multiple dongles, please run multiple rtl_tcp in multiple shell respectively as:
% rtl_tcp -p 1234 -d 0
% rtl_tcp -p 1235 -d 1
% rtl_tcp -p 1236 -d 3
% ...

% Then run this script in MATLAB.

% ATTENTION! In some computer, every time before you run this script, maybe you need to terminate two rtl_tcp and re-launch them again.

% Change following parameters as you need:

% Number of dongles you have connected to your computer
num_dongle = 1;

% Beginning of the band you are interested in
% start_freq = 935e6;
% start_freq = (1575.42-15)*1e6; % GPS L1
% start_freq = (1207.14-30)*1e6; % COMPASS B2I
% start_freq = (1561.098-30)*1e6; % COMPASS B1I
% start_freq = 935e6; % Beginning of Primary GSM-900 Band
start_freq = 1.14e9; % Beginning of GNSS(GPS/GLONASS/COMPASS/Galileo) Band

% End of the band you are interested in
% end_freq = 940e6;
% end_freq = (1575.42+30)*1e6; % GPS L1
% end_freq = (1207.14+30)*1e6; % COMPASS B2I
% end_freq = (1561.098+30)*1e6; % COMPASS B1I
% end_freq = 960e6; % End of Primary GSM-900 Band
end_freq = 1.63e9; % Beginning of GNSS(GPS/GLONASS/COMPASS/Galileo) Band

freq_step = 0.25e6;

observe_time = 0.2; % observation time at each frequency point

RBW = freq_step; % Resolution Bandwidth each time we inspect

gain = 49; % If this is larger than 0, the fixed gain will be set to dongles

sample_rate = 2.048e6; % sampling rate of dongles

coef_order = (2^(ceil(log2(sample_rate/RBW))))-1;
coef_order = min(coef_order, 127);
coef_order = max(coef_order, 31);
coef = fir1(coef_order, RBW/sample_rate);
% freqz(coef, 1, 1024);

num_samples = observe_time*sample_rate;

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
    set(tcp_obj{i}, 'InputBufferSize', 8*2*num_samples);
    set(tcp_obj{i}, 'Timeout', 60);
    fopen(tcp_obj{i});
end

clf;
close all;

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
    fread(tcp_obj{i}, 8*2*num_samples, 'uint8');
end

idx = 1;
s = zeros(2*num_samples, num_dongle);
real_count = zeros(1, num_dongle);
for freq = start_freq:freq_step:end_freq
%     % read and discard to flush
%     for i=1:num_dongle
%         fread(tcp_obj{i}, num_recv*fread_len, 'uint8');
%     end

    while 1
        for i=1:num_dongle
            set_freq_tcp(tcp_obj{i}, freq); % set current frequency
            [s(:,i), real_count(i)] = fread(tcp_obj{i}, 2*num_samples, 'uint8');
            [s(:,i), real_count(i)] = fread(tcp_obj{i}, 2*num_samples, 'uint8');
        end
        
        if sum(real_count-(2*num_samples)) ~= 0
            disp(num2str([idx 2*num_samples, real_count]));
        else
            break;
        end
    end
    
    % convert raw unsigned IQ samples to normal IQ samples for signal processing purpose
    r = raw2iq(s);
    
    % process samples from two dongles in two columns of varable s
    % add your routine here
    r = filter(coef, 1, r);

    % get averaged power and convert it to dB
    for i=1:num_dongle
        power_spectrum(i, idx) = mean(abs(r(:,i)).^2);
    end
    
    disp(num2str([freq power_spectrum(:, idx).']));
    
    idx = idx + 1;    
end

% plot power spectrum
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

% plot combined power spectrum
figure;
power_spectrum_combine = mean(power_spectrum, 1);
plot((start_freq:freq_step:end_freq).*1e-6, 10.*log10(power_spectrum_combine), 'b.-');

for i=1:num_dongle
    fclose(tcp_obj{i});
    delete(tcp_obj{i});
end
clear tcp_obj;

filename = ['scan_' num2str(start_freq) '_' num2str(end_freq) '_gain' num2str(gain) '_' num2str(num_dongle) 'dongles.mat'];
save(filename, 'power_spectrum', 'power_spectrum_combine', 'start_freq', 'end_freq', 'freq_step', 'observe_time', 'RBW', 'gain', 'sample_rate', 'coef');
