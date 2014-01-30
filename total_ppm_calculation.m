function ppm_out = total_ppm_calculation(ppm_in)

if ppm_in == inf
    disp('total PPM calculation: No valid PPM input!');
    ppm_out = inf;
    return;
end

orig_num = ppm_in*1e-6;

orig_num = 1 + orig_num;

orig_num = prod(orig_num);

orig_num = orig_num - 1;

ppm_out = orig_num * 1e6;
