% function CW_check.m
% Jiao Xianjun (putaoshu@msn.com; putaoshu@gmail.com)
% check if there are discontinuous samples in a segment of CW signal

function r = CW_check(s)

phase_rotate = angle( mean( s(2:end)./s(1:(end-1)) ) );

r = angle( s(2:end)./s(1:(end-1)) ) - phase_rotate;
