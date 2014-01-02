% function recv_proc_udp.m
% Jiao Xianjun (putaoshu@msn.com; putaoshu@gmail.com)
% A Example to receive, process, and show signal relaied from multiple dongles by rtl-sdr-relay
% Please run the C program firstly as: ./rtl-sdr-relay -f 905000000 -s 3000000 -b 8192 -l 8192
% receive at 905MHz GSM uplink bursts at 3Msps sampling rate with rtl-sdr buffer size and UPD packet size both are 8192 bytes.
% You should replace frequency 905MHz to your local frequency with strong power, such as GSM uplink or downlink.
% Then run this script.

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

udp_obj0 = udp('127.0.0.1', 13485, 'LocalPort', 6666); % for dongle 0
udp_obj1 = udp('127.0.0.1', 13485, 'LocalPort', 6667); % for dongle 1

num_frame = 5; % how many frame we show them together in one draw
fread_len = 8192; % max allowed
% fread_len = 512;
set(udp_obj0, 'InputBufferSize', 4*num_frame*fread_len);
set(udp_obj0, 'Timeout', 10);
set(udp_obj1, 'InputBufferSize', 4*num_frame*fread_len);
set(udp_obj1, 'Timeout', 10);

fopen(udp_obj0);
fopen(udp_obj1);
clf;
close all;
idx = 1;
while 1
    a0 = inf.*ones(fread_len, num_frame);
    a1 = inf.*ones(fread_len, num_frame);
    for i=1:num_frame  % get many frame in one signal sequence
        [tmp0, real_count0] = fread(udp_obj0, fread_len, 'uint8');
        [tmp1, real_count1] = fread(udp_obj1, fread_len, 'uint8');
        
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

% num_recv = 30;
% a0 = zeros(num_recv, fread_len);
% a1 = zeros(num_recv, fread_len);
% for i=1:num_recv
%     [a0(i,:), x] = fread(udp_obj0, fread_len, 'uint8');
%     [a1(i,:), x] = fread(udp_obj1, fread_len, 'uint8');
% end
% 
% 
% a1 = a1';
% a1 = a1(:)';
% 
% a = a0;
% c = a(1:2:end) + 1i.*a(2:2:end);
% b = c- ( sum(c)./length(c) );
% a0 = b;
% 
% a = a1;
% c = a(1:2:end) + 1i.*a(2:2:end);
% b = c- ( sum(c)./length(c) );
% a1 = b;
% %     subplot(2,1,1); plot(abs(a0));
% %     subplot(2,1,2); plot(abs(a1));
% 
% plot(abs(a0)); hold on;
% plot(abs(a1), 'r');
% legend('dongle 0', 'dongle 1');

% if ~isempty(dir('tmp.mat'))
%     load tmp.mat;
%     sp = 286156;
%     ep = 286348;
%     s = a0(sp:ep);
%     figure;
%     corr_val = conv(a1, conj(s(end:-1:1)));
%     plot(abs(corr_val));
% end