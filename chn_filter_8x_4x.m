% Jiao Xianjun (putaoshu@msn.com; putaoshu@gmail.com)
% GSM decimation channel filter which works on 8X oversampling input and generates 4X oversampling output
% A script of project: https://github.com/JiaoXianjun/multi-rtl-sdr-calibration

function r = chn_filter_8x_4x(s)
persistent coef;

if isempty(coef)
    coef = load('gsm_chn_filter_8x.mat');
    coef = coef.Num;
end

r = filter(coef, 1, s);

r = r(1:2:end, :);
