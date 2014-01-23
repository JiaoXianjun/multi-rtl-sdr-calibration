function s = gsm_SCH_training_sequence_gen(oversampling_ratio)
sample_per_symbol = oversampling_ratio;
pulse_length = 4;
mod_idx = 0.25; % GSM spec
BT = 0.3; % GSM spec

hMod = comm.CPMModulator(2, 'BitInput', true, 'SymbolMapping', 'Gray', 'ModulationIndex', mod_idx, 'FrequencyPulse', 'Gaussian', 'BandwidthTimeProduct', BT, 'PulseLength', pulse_length, 'SamplesPerSymbol', sample_per_symbol);

data = [1, 0, 1, 1, 1, 0, 0, 1, 0, 1, 1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 1, 0, ...
0, 0, 0, 0, 0, 1, 1, 1, 1, 0, 0, 1, 0, 1, 1, 0, 1, 0, 1, 0, 0, 0, ...
1, 0, 1, 0, 1, 1, 1, 0, 1, 1, 0, 0, 0, 0, 1, 1, 0, 1, 1].';

s = step(hMod, data);

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
