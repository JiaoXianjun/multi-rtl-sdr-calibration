% Jiao Xianjun (putaoshu@msn.com; putaoshu@gmail.com)
% A test script to study GMSK demodulation
% A script of project: https://github.com/JiaoXianjun/multi-rtl-sdr-calibration

% function test_diff_GMSK_mod_demod
clear all;
close all;
sample_per_symbol = 8;
pulse_length = 4;
BT = 0.3; % GSM spec
InitialPhaseOffset = 0;
hMod = comm.GMSKModulator('BitInput', true, 'BandwidthTimeProduct', BT, 'PulseLength', pulse_length, 'SamplesPerSymbol', sample_per_symbol, 'InitialPhaseOffset', InitialPhaseOffset);

TracebackDepth = 5;

s_bit = [0 1 0 1 1 0 1 0   1 1 0 1 1];
gmsk_s_bit = ~abs(diff([1 s_bit]));
disp(num2str(gmsk_s_bit));
s = step(hMod, gmsk_s_bit.');

phase_trace = unwrap(angle(s));
idx = 0 : (length(phase_trace)-1);
idx = idx./sample_per_symbol;
phase_trace = phase_trace./pi;
plot(idx, phase_trace); grid on;

InitialPhaseOffset = 0;
hDemod = comm.GMSKDemodulator('BitOutput', true, 'BandwidthTimeProduct', BT, 'PulseLength', pulse_length, 'SamplesPerSymbol', sample_per_symbol, 'TracebackDepth', TracebackDepth, 'InitialPhaseOffset', InitialPhaseOffset);

r = s;

gmsk_r_bit = step(hDemod, r);
gmsk_r_bit = gmsk_r_bit((TracebackDepth+1) : end).';

disp(num2str( gmsk_r_bit - gmsk_s_bit(1:length(gmsk_r_bit)) ));

r_bit = ~gmsk_r_bit;
tmp = [0 r_bit];
for i=1:length(r_bit)
    tmp(i+1) = xor( tmp(i), tmp(i+1) );
end

r_bit = tmp(2:end);

disp(num2str( r_bit - s_bit(1:length(r_bit)) ));
