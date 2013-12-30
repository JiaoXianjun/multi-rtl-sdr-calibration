function b = raw2iq(a)
c = a(1:2:end) + 1i.*a(2:2:end);
b = c- ( sum(c)./length(c) );
