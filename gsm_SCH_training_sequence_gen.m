% Jiao Xianjun (putaoshu@msn.com; putaoshu@gmail.com)
% Generate GSM SCH channel training sequences according to GSM spec
% A script of project: https://github.com/JiaoXianjun/multi-rtl-sdr-calibration

function s = gsm_SCH_training_sequence_gen(oversampling_ratio)
filename = ['gsm_SCH_training_sequence_' num2str(oversampling_ratio) 'x.mat'];

if isempty(dir(filename))
    sample_per_symbol = oversampling_ratio;
    pulse_length = 4;
    % mod_idx = 0.25; % GSM spec
    BT = 0.3; % GSM spec

    hMod = comm.GMSKModulator('BitInput', true, 'BandwidthTimeProduct', BT, 'PulseLength', pulse_length, 'SamplesPerSymbol', sample_per_symbol);

    % extended training sequence bits
    data = [1, 0, 1, 1, 1, 0, 0, 1, 0, 1, 1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 1, 0, ...
    0, 0, 0, 0, 0, 1, 1, 1, 1, 0, 0, 1, 0, 1, 1, 0, 1, 0, 1, 0, 0, 0, ...
    1, 0, 1, 0, 1, 1, 1, 0, 1, 1, 0, 0, 0, 0, 1, 1, 0, 1, 1].';

    % 
    % % CTS synchronization
    % data = [1, 1, 1, 0, 1, 1, 1, 0, 0, 1, 1, 0, 1, 0, 1, 1, 0, 0, 1, 0, 1, 0, 0, 0, ...
    % 0, 0, 1, 1, 1, 1, 1, 0, 1, 1, 1, 1, 0, 1, 0, 0, 0, 1, 1, 1, 1, 1, 1, 0, ...
    % 1, 1, 0, 0, 1, 0, 1, 1, 0, 0, 0, 1, 0, 1, 0, 1].';

    % % COMPACT synchronization
    % data = [1, 1, 1, 0, 1, 1, 0, 0, 0, 0, 1, 1, 0, 1, 1, 1, 0, 1, 0, 1, 0, 0, 0, 1, 0, 1, ...
    % 0, 1, 1, 0, 1, 0, 0, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1, 1, 0, 1, 0, 0, 1, 1, 1, 0].';

    % data = ~abs(diff([data(end:-1:1); 0]));
    data = ~abs(diff([0; data]));
    % data = [1; data];
    % for i=2:length(data)
    %     data(i) = xor(data(i), data(i-1));
    % end
    % data = ~data(2:end);

    s = step(hMod, data); 
    save(filename, 's');
    
else
    s = load(filename);
    s = s.s;
end

% % ---------test another method and compare it with formal method----------------
% mod_idx = 0.5;
% BT = 0.3;
% pulse_length = 4;
% sample_per_symbol = oversampling_ratio;
% 
% hMod = comm.CPMModulator(2, 'BitInput', true, 'SymbolMapping', 'Gray', 'ModulationIndex', mod_idx, 'FrequencyPulse', 'Gaussian', 'BandwidthTimeProduct', BT, 'PulseLength', pulse_length, 'SamplesPerSymbol', sample_per_symbol);
% data = [1, 0, 1, 1, 1, 0, 0, 1, 0, 1, 1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 1, 0, ...
%     0, 0, 0, 0, 0, 1, 1, 1, 1, 0, 0, 1, 0, 1, 1, 0, 1, 0, 1, 0, 0, 0, ...
%     1, 0, 1, 0, 1, 1, 1, 0, 1, 1, 0, 0, 0, 0, 1, 1, 0, 1, 1].';
% data = ~abs(diff([0; data]));
% x = step(hMod, data); 
% subplot(2,1,1); plot(real(s)); hold on; plot(real(x),'r.');
% subplot(2,1,2); plot(imag(s)); hold on; plot(imag(x),'r.');

% % --------end of test another method and compare it with formal method----------

% % --------------------useless-------------------------------------------------------
% hMod = comm.CPMModulator(2, 'BitInput', true, 'SymbolMapping', 'Gray', 'ModulationIndex', mod_idx, 'FrequencyPulse', 'Gaussian', 'BandwidthTimeProduct', BT, 'PulseLength', pulse_length, 'SamplesPerSymbol', sample_per_symbol);
% 
% data = [1 1 1 1 1 1 1 1 1, 0, 1, 1, 1, 0, 0, 1, 0, 1, 1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 1, 0, ...
% 0, 0, 0, 0, 0, 1, 1, 1, 1, 0, 0, 1, 0, 1, 1, 0, 1, 0, 1, 0, 0, 0, ...
% 1, 0, 1, 0, 1, 1, 1, 0, 1, 1, 0, 0, 0, 0, 1, 1, 0, 1, 1].';
% 
% s1 = step(hMod, data);
% s1 = s1(8*4+1 : end);
% 
% figure;
% plot(abs(s-s1));
% 
% figure;
% subplot(2,1,1); plot(abs(s));
% subplot(2,1,2); plot(angle(s));
% 
% symbole_rate = (1625/6)*1e3;
% modSignal = s;
% sample_rate = sample_per_symbol*symbole_rate;
% 
% r = modSignal;
% rad_per_sample = angle( exp(1i.*angle(r(2:end)))./exp(1i.*angle(r(1:end-1))) );
% 
% freq_dev = sample_rate.*rad_per_sample./(2.*pi);
% figure;
% plot(freq_dev./1e3);
