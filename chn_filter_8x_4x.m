function r = chn_filter_8x_4x(s)
persistent coef;

if isempty(coef)
    coef = load('gsm_chn_filter_8x.mat');
    coef = coef.Num;
end

r = filter(coef, 1, s);

r = r(1:2:end, :);
