% function recv_proc_udp.m
% Jiao Xianjun (putaoshu@msn.com; putaoshu@gmail.com)
% A Example to receive, process, and show signal relaied from rtl-sdr-relay

if ~isempty(who('udp_obj0'))
    fclose(udp_obj0);
    delete(udp_obj0);
    clear udp_obj0;
end

if ~isempty(who('udp_obj1'))
    fclose(udp_obj1);
    delete(udp_obj1);
    clear udp_obj1;
end

udp_obj0 = udp('127.0.0.1', 10000, 'LocalPort', 6666); % for dongle 0
udp_obj1 = udp('127.0.0.1', 10000, 'LocalPort', 6667); % for dongle 1

fread_len = 8192; % max allowed
set(udp_obj0, 'InputBufferSize', fread_len);
set(udp_obj0, 'Timeout', 1);
set(udp_obj1, 'InputBufferSize', fread_len);
set(udp_obj1, 'Timeout', 1);

fopen(udp_obj0);
fopen(udp_obj1);
clf;
close all;
while 1
    [a0, real_count0] = fread(udp_obj0, fread_len, 'uint8');
    [a1, real_count1] = fread(udp_obj1, fread_len, 'uint8');
    if real_count0~=fread_len || real_count1~=fread_len
        disp('Number of read samples is not equal to expectation!');
        continue;
    end

    % process samples from two dongles in varable "a0" and "a1"
    % convert unsigned IQ to normal/signed IQ
    a = a0;
    c = a(1:2:end) + 1i.*a(2:2:end);
    b = c- ( sum(c)./length(c) );
    a0 = b;
    
    a = a1;
    c = a(1:2:end) + 1i.*a(2:2:end);
    b = c- ( sum(c)./length(c) );
    a1 = b;
    
    % show
    subplot(2,2,1); plot(abs(a0));
    subplot(2,2,2); plot(angle(a0));
    
    subplot(2,2,3); plot(abs(a1));
    subplot(2,2,4); plot(angle(a1));

    drawnow;
end

% num_recv = 128;
% a0 = zeros(num_recv, fread_len);
% a1 = zeros(num_recv, fread_len);
% for i=1:num_recv
%     [a0(i,:), ~] = fread(udp_obj0, fread_len, 'uint8');
%     [a1(i,:), ~] = fread(udp_obj1, fread_len, 'uint8');
% end
% 
% a0 = a0';
% a0 = a0(:)';
% a1 = a1';
% a1 = a1(:)';
% subplot(2,1,1); plot(a0);
% subplot(2,1,2); plot(a1);