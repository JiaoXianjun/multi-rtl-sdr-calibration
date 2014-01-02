function r = chn_filter_4x(s)
persistent coef;

if isempty(coef)
    coef = load('gsm_chn_filter_4x.mat');
    coef = coef.Num;
end

r = filter(coef, 1, s);

