% function recv_proc_tcp.m
% Jiao Xianjun (putaoshu@msn.com; putaoshu@gmail.com)
% A Example to receive, process, and show signal relaied from multiple dongles.
% For example, you have two dongles, please run two rtl_tcp in command line firstly as:
% rtl_tcp -p 1234 -f 905000000 -d 0
% rtl_tcp -p 1235 -f 905000000 -d 1
% receive at 905MHz GSM uplink bursts at default sampling rate with dongle 1 at tcp port 1234 and dongle 2 at tcp port 1235.
% You should replace frequency 905MHz to your local frequency with strong power, such as GSM uplink or downlink.
% Then run this script.
% ATTENTION! every time before you run this script, please terminate two rtl_tcp and re-launch them again.

if ~isempty(who('tcp_obj0'))
    fclose(tcp_obj0);
    delete(tcp_obj0);
    clear tcp_obj0;
end

if ~isempty(who('tcp_obj1'))
    fclose(tcp_obj1);
    delete(tcp_obj1);
    clear tcp_obj1;
end

tcp_obj0 = tcpip('127.0.0.1', 1234); % for dongle 0
tcp_obj1 = tcpip('127.0.0.1', 1235); % for dongle 1

num_frame = 5; % how many frame we show them together in one draw
fread_len = 8192;
% fread_len = 512;
set(tcp_obj0, 'InputBufferSize', 4*num_frame*fread_len);
set(tcp_obj0, 'Timeout', 10);
set(tcp_obj1, 'InputBufferSize', 4*num_frame*fread_len);
set(tcp_obj1, 'Timeout', 10);

fopen(tcp_obj0);
fopen(tcp_obj1);
clf;
close all;
idx = 1;
while 1
    a0 = inf.*ones(fread_len, num_frame);
    a1 = inf.*ones(fread_len, num_frame);
    for i=1:num_frame  % get many frame in one signal sequence
        [tmp0, real_count0] = fread(tcp_obj0, fread_len, 'uint8');
        [tmp1, real_count1] = fread(tcp_obj1, fread_len, 'uint8');
        
        if ( real_count0~=fread_len || real_count1~=fread_len )
            disp(num2str([idx i fread_len, real_count0, real_count1]));
            continue;
        end
        
        a0(:, i) = tmp0;
        a1(:, i) = tmp1;
    end

    % convert raw unsigned IQ samples to normal IQ samples for signal processing purpose
    s = raw2iq([a0(:), a1(:)]);
    
    % process samples from two dongles in varable s, each column is from each dongle
    % add your routine here
    % ...
    
    
    % show manitude of signlas from two dongles
    subplot(2,1,1); plot(abs(s(:,1)));
    subplot(2,1,2); plot(abs(s(:,2)));
    drawnow;
    
    idx = idx + 1;
end
