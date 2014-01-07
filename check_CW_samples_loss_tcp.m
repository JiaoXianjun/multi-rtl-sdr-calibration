% function check_CW_samples_loss_tcp.m
% Jiao Xianjun (putaoshu@msn.com; putaoshu@gmail.com)
% Check if there are some samples lost during the continuous fread operations.
% For example, you have two dongles, please run two rtl_tcp in command line firstly as:
% rtl_tcp -p 1234 -f 915000000 -d 0
% rtl_tcp -p 1235 -f 915000000 -d 1
% receive at 915MHz ISM frequency, where CW is transmitted by your signal generator, with dongle 1 at tcp port 1234 and dongle 2 at tcp port 1235.
% You should replace frequency 915MHz to your local frequency where test CW is transmitted.
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

num_frame = 50; % how many frame we show them together in one draw
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

gain = 49;% 49.6dB is the maximum value for 820T tuner. You should find a appropriate value for your case
set_gain_tcp(tcp_obj0, gain*10); %be careful, in rtl_sdr the 10x is done inside C program, but in rtl_tcp the 10x has to be done here.
set_gain_tcp(tcp_obj1, gain*10);

sample_rate = 1e6;
set_rate_tcp(tcp_obj0, sample_rate);
set_rate_tcp(tcp_obj1, sample_rate);

fread(tcp_obj0, 4*num_frame*fread_len, 'uint8');
fread(tcp_obj1, 4*num_frame*fread_len, 'uint8');
pause(1);

% while 1
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
    
    
%     % show check results
%     subplot(2,1,1); r = CW_check(s(:,1)); plot(r);
%     subplot(2,1,2); r = CW_check(s(:,2)); plot(r);
%     drawnow;
    
    idx = idx + 1;
% end
figure;
subplot(2,1,1); plot(real(s(:,1)));
subplot(2,1,2); plot(real(s(:,2)));

figure;
subplot(2,1,1); r = CW_check(s(:,1)); plot(r);
subplot(2,1,2); r = CW_check(s(:,2)); plot(r);
