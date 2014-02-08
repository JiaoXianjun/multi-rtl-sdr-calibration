% Jiao Xianjun (putaoshu@msn.com; putaoshu@gmail.com)
% GSM single rate channel filter which works on 4X oversampling rate
% A script of project: https://github.com/JiaoXianjun/multi-rtl-sdr-calibration

function r = chn_filter_4x(s)
persistent coef;

if isempty(coef)
    coef = load('gsm_chn_filter_4x.mat');
    coef = coef.Num;
end

r = filter(coef, 1, s);

