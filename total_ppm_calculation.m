function ppm_out = total_ppm_calculation(ppm_in)

orig_num = ppm_in*1e-6;

orig_num = 1 + orig_num;

orig_num = prod(orig_num);

orig_num = orig_num - 1;

ppm_out = orig_num * 1e6;
