% Jiao Xianjun (putaoshu@msn.com; putaoshu@gmail.com)
% Frequency band scanning and incoherent combination via multiple rtl-sdr dongles.
% A script of project: https://github.com/JiaoXianjun/multi-rtl-sdr-calibration
% Temporary save for another fast scanning method. Not complete yet.

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
start_freq = 910e6; % for test
% start_freq = (1575.42-15)*1e6; % GPS L1
% start_freq = (1207.14-30)*1e6; % COMPASS B2I
% start_freq = (1561.098-30)*1e6; % COMPASS B1I
% start_freq = 935e6; % Beginning of Primary GSM-900 Band downlink
% start_freq = 1.14e9; % Beginning of GNSS(GPS/GLONASS/COMPASS/Galileo) Band

% End of the band you are interested in
end_freq = 920e6; % for test
% end_freq = (1575.42+30)*1e6; % GPS L1
% end_freq = (1207.14+30)*1e6; % COMPASS B2I
% end_freq = (1561.098+30)*1e6; % COMPASS B1I
% end_freq = 960e6; % End of Primary GSM-900 Band downlink
% end_freq = 1.63e9; % Beginning of GNSS(GPS/GLONASS/COMPASS/Galileo) Band

freq_step = 0.1e6; % less step, higher resolution, narrower FIR bandwidth, slower speed

observe_time = 0.2; % observation time at each frequency point. ensure it can capture your signal!

RBW = freq_step; % Resolution Bandwidth each time we inspect

gain = 0; % If this is larger than 0, the fixed gain will be set to dongles

% use high sampling rate and narrow FIR to improve estimation accuracy
sample_rate = 2.048e6; % sampling rate of dongles
% construct a FIR to be used to extract target bandwidth
coef_order = (2^(ceil(log2(sample_rate/RBW))))-1;
coef_order = min(coef_order, 127);
coef_order = max(coef_order, 31);
coef = fir1(coef_order, RBW/sample_rate);
% freqz(coef, 1, 1024);

num_samples = observe_time*sample_rate;

% pre calculate something to be used for extracting multiple freqeuncy channels with in one sampling stream.
clf;
close all;

real_count = zeros(1, num_dongle);
freq = start_freq:freq_step:end_freq;
real_freq_step = sample_rate/4;
real_freq = start_freq:real_freq_step:end_freq;
if real_freq(end)+(real_freq_step/2) < freq(end)
    real_freq = [real_freq, real_freq(end)+real_freq_step];
end

freq_info(1:length(real_freq)) = struct('center_freq', inf, 'num_sub_freq', inf, 'sub_freq_set', inf.*ones(1, ceil(real_freq_step/freq_step)+1), 'relative_sub_freq_set', inf.*ones(1, ceil(real_freq_step/freq_step)+1));

for i=1:length(real_freq)
    freq_info(i).center_freq = real_freq(i);
    freq_start = real_freq(i) - (real_freq_step/2);
    freq_end = real_freq(i) + (real_freq_step/2);
    freq_set = find(freq>freq_start & freq<=freq_end);
    freq_info(i).num_sub_freq = length(freq_set);
    freq_info(i).sub_freq_set(1:length(freq_set)) = freq(freq_set);
    freq_info(i).relative_sub_freq_set(1:length(freq_set)) = freq(freq_set) - real_freq(i);
end
% % % -------------------------------------verify-----------------------------------
% figure;
% plot(freq, 'b.'); hold on; grid on;
% tmp = [];
% for i=1:length(real_freq)
%     tmp = [tmp freq_info(i).center_freq];
% end
% plot(tmp, 'rs');
% tmp = [];
% for i=1:length(real_freq)
%     tmp = [tmp freq_info(i).sub_freq_set(1:freq_info(i).num_sub_freq)];
% end
% plot(tmp, 'kv');
% 
% figure;
% plot(tmp-freq); grid on; hold on;
% tmp = [];
% for i=1:length(real_freq)
%     tmp = [tmp freq_info(i).relative_sub_freq_set(1:freq_info(i).num_sub_freq) + freq_info(i).center_freq];
% end
% plot(tmp-freq, 'r.');
% 
% figure;
% tmp = [];
% for i=1:length(real_freq)
%     tmp = [tmp freq_info(i).num_sub_freq];
% end
% plot(tmp, 'b.'); hold on; grid on;
% % % ----------------------------end of verify-----------------------------------

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

% try to read all frequencies firstly!
s = zeros(2*num_samples, num_dongle);
r_all = zeros(num_samples, num_dongle, length(real_freq));
for real_freq_idx = 1:length(real_freq)
    
    current_freq = real_freq(real_freq_idx);
    
    while 1 % read data
        for i=1:num_dongle
            set_freq_tcp(tcp_obj{i}, current_freq); % set current frequency
            [s(:,i), real_count(i)] = fread(tcp_obj{i}, 2*num_samples, 'uint8');
        end

        if sum(real_count-(2*num_samples)) ~= 0
            disp(num2str([idx 2*num_samples, real_count]));
        else
            break;
        end
    end
    
    % convert raw unsigned IQ samples to normal IQ samples for signal processing purpose
    r_all(:,:,real_freq_idx) = raw2iq(s);
end

for i=1:num_dongle
    fclose(tcp_obj{i});
    delete(tcp_obj{i});
end
clear tcp_obj;

disp('Scanning done!');

idx = 1;
power_spectrum = zeros(num_dongle, length(freq));
for real_freq_idx = 1:length(real_freq)
    % process samples from multiple dongles in multiple columns of varable s
    % add your routine here
    r = r_all(:,:,real_freq_idx);
    for j = 1 : freq_info(real_freq_idx).num_sub_freq % go through sub frequencies around current freqeuncy
        % shifting to target sub frequency
        freq = freq_info(real_freq_idx).relative_sub_freq_set(j);
        phase_rotate = freq*2*pi/sample_rate;
        tmp = r.*kron(ones(1, num_dongle), exp(1i.*(1:num_samples).*phase_rotate)');
        
        % filter target band out
        r_flt = filter(coef, 1, tmp);

        % get averaged power
        for i=1:num_dongle
            power_spectrum(i, idx) = mean(abs(r_flt(:,i)).^2);
        end
        
        disp(num2str([freq_info(real_freq_idx).sub_freq_set(j) power_spectrum(:, idx).']));

        idx = idx + 1;    
    end
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
