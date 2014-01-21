% Jiao Xianjun (putaoshu@msn.com; putaoshu@gmail.com)
% GSM broadcasting carrier FCCH scanning via multiple rtl-sdr dongles. Each dongle for each sub-band to speedup!
% Learning GSM downlink frame structure from here: http://www.sharetechnote.com/html/FrameStructure_GSM.html
% Tuning detection algorithm parameters in FCCH_coarse_position.m. such as th, max_offset, etc.
% A script of project: https://github.com/JiaoXianjun/multi-rtl-sdr-calibration

% Assume that you have installed rtl-sdr
% (http://sdr.osmocom.org/trac/wiki/rtl-sdr) and have those native utilities run correctly already.

% For example, you have multiple dongles, please run multiple rtl_tcp in multiple shell respectively as:
% rtl_tcp -p 1234 -d 0
% rtl_tcp -p 1235 -d 1
% rtl_tcp -p 1236 -d 2
% ...

% Then run this script in MATLAB.

% ATTENTION! In some computer, every time before you run this script, maybe you need to terminate multiple rtl_tcp and re-launch them again.
% ATTENTION! Please reduce number of inspected points by reducing frequency range or increasing step size, if your computer hasn't enough memory installed. Because all signlas are stored firstly before processing.

% Change following parameters as you need:

% Number of dongles you have connected to your computer
num_dongle = 1; % more dongles, much faster.

% Beginning of the band you are interested in
% start_freq = 910e6; % for test
start_freq = 935e6; % Beginning of Primary GSM-900 Band downlink

% End of the band you are interested in
% end_freq = 940e6; % for test
end_freq = 960e6; % End of Primary GSM-900 Band downlink

freq_step = 0.2e6; % GSM channel spacing

gain = 0; % If this is larger than 0, the fixed gain will be set to dongles

symbol_rate = (1625/6)*1e3; % GSM spec
num_frame = 64; % You'd better have at least 51 frames (one multiframe)
num_sym_per_slot = 625/4; % GSM spec
num_slot_per_frame = 8; % GSM spec

oversampling_ratio = 4;
decimation_ratio_for_FCCH_rough_position = 8;
decimation_ratio_from_oversampling = oversampling_ratio*decimation_ratio_for_FCCH_rough_position;

sampling_rate = symbol_rate*oversampling_ratio;

num_samples = oversampling_ratio * num_frame * num_slot_per_frame * num_sym_per_slot;
observe_time = num_samples/sampling_rate;

% GSM channel filter for 4x oversampling
coef = fir1(30, 200e3/sampling_rate);
% freqz(coef, 1, 1024);

clf;
close all;

% construct freq set for each dongle
freq_orig = start_freq:freq_step:end_freq;
num_freq_per_sub_band = ceil(length(freq_orig)/num_dongle);
num_freq = num_freq_per_sub_band*num_dongle;
num_pad = num_freq - length(freq_orig);
freq = [freq_orig freq_orig(end)+(1:num_pad).*freq_step];
freq = vec2mat(freq, num_freq_per_sub_band);

real_count = zeros(1, num_dongle);
s = zeros(2*num_samples, num_dongle);
s_all = zeros(length(1:decimation_ratio_from_oversampling:num_samples), num_freq);

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
    set_rate_tcp(tcp_obj{i}, sampling_rate);
end

% set different start freq to different dongle
for i=1:num_dongle
    set_freq_tcp(tcp_obj{i}, freq(i,1));
end

% read and discard to flush
for i=1:num_dongle
    fread(tcp_obj{i}, 8*2*num_samples, 'uint8');
end

% capture samples of all frequencies firstly!
tic;
for freq_idx = 1:num_freq_per_sub_band
    while 1 % read data at current frequency until success
        for i=1:num_dongle
            set_freq_tcp(tcp_obj{i}, freq(i, freq_idx)); % set different frequency to different dongle
        end
        for i=1:num_dongle
            fread(tcp_obj{i}, 2*num_samples, 'uint8'); % flush to wait for its stable
        end
        for i=1:num_dongle
            [s(:, i), real_count(i)] = fread(tcp_obj{i}, 2*num_samples, 'uint8'); % read samples from multi-dongles
        end
        
        if sum(real_count-(2*num_samples)) ~= 0
            disp(num2str([idx 2*num_samples, real_count]));
        else
            r = raw2iq(s);
            r = filter(coef, 1, r);
            for i=1:num_dongle
                s_all(:, freq_idx + (i-1)*num_freq_per_sub_band) = r(1:decimation_ratio_from_oversampling:end, i); % store data for FCCH detection
            end
            break;
        end
    end
end
e = toc;
ideal_time_cost = observe_time*num_freq_per_sub_band;

% close TCP
for i=1:num_dongle
    fclose(tcp_obj{i});
    delete(tcp_obj{i});
end
clear tcp_obj;

disp('Scanning done!');
disp(['actual time cost ' num2str(e) ' ideal cost ' num2str(ideal_time_cost) ' efficiency(ideal/actual) ' num2str(ideal_time_cost/e)]);
disp(' ');
disp('Begin process ...');

% Detect GSM FCCH for all frequencies, and save, display quality metric
tic;
snr = zeros(1, num_freq);
num_hit = zeros(1, num_freq);
tmp = freq.'; tmp = tmp(:).';
for i=1:num_freq
    [FCCH_pos, FCCH_snr]= FCCH_coarse_position(s_all(:,i), decimation_ratio_for_FCCH_rough_position); % detect FCCH position and SNR
    if FCCH_pos ~= -1 % find multiple successive FCCH
        disp(['at ' num2str(tmp(i)*1e-6) 'MHz']);
    end
    diff_FCCH_pos = diff(FCCH_pos);
    if length(FCCH_pos)>=3 % at least 3 successive FCCH hits
        a = abs(diff_FCCH_pos - 12500); % intra multiframe
        a = a>50;
        if ~sum(a)
            snr(i) = mean(FCCH_snr);
            num_hit(i) = length(FCCH_pos);
        else
            b = abs( diff_FCCH_pos(a) - (12500+1250) ); % cross multiframe
            b = b>50;
            if ~sum(b)
                snr(i) = mean(FCCH_snr);
                num_hit(i) = length(FCCH_pos);
            else
                disp('Not all detected positions are valid!');
            end
        end
    end
end
e1 = toc;
disp(['time cost ' num2str(e1) ' scan/process ' num2str(e/e1)]);
disp(['total time cost ' num2str(e1+e)]);

% plot FCCH quality metrics
figure;
format_string = {'r', 'k', 'b', 'm', 'g', 'c'};
for i=1:num_dongle
    subplot(2,1,1); bar(freq(i,:).*1e-6, snr( (i-1)*num_freq_per_sub_band+1: i*num_freq_per_sub_band), format_string{i}); hold on;
    subplot(2,1,2); bar(freq(i,:).*1e-6, num_hit( (i-1)*num_freq_per_sub_band+1: i*num_freq_per_sub_band), format_string{i}); hold on;
end

legend_string = cell(1, num_dongle);
for i=1:num_dongle
    legend_string{i} = ['dongle ' num2str(i)];
end
subplot(2,1,1); legend(legend_string); title('FCCH rough SNR(dB) vs frequency'); xlabel('MHz'); ylabel('dB');
subplot(2,1,2); legend(legend_string); title('num FCCH successive hits vs frequency'); xlabel('MHz'); ylabel('hits');

filename = ['FCCH_scan_' num2str(start_freq) '_' num2str(end_freq) '_gain' num2str(gain) '_' num2str(num_dongle) 'dongles.mat'];
save(filename, 'snr', 'num_hit', 'start_freq', 'end_freq', 'freq_step', 'observe_time', 'gain', 'sampling_rate', 'coef', 'freq');
