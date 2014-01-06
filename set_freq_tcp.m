% Jiao Xianjun (putaoshu@msn.com; putaoshu@gmail.com)
% parameter setting via tcp to rtl_tcp

function tcp_obj = set_freq_tcp(tcp_obj, freq)
fwrite(tcp_obj, 1, 'uint8');
fwrite(tcp_obj, uint32(freq), 'uint32');
