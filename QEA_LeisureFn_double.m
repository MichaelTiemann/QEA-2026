function leisure=QEA_LeisureFn_double(d,aprime,pvprime,a,pv,ks,z1,z2,w,agej,Jr,J,kappa_j,wg1,wg2,wg3,beta,sj)
% Is LifeCycleModel8_ReturnFn, but modified to include medical expense
% shocks when retired.

double_0=double(0); double_1=double(1);
h=d;
ks_out=d;

leisure=double_0;
if agej<Jr % If working age
    leisure=(double_1-h)*z1*kappa_j;
else % Retirement
    if aprime>=double_0
        leisure=((J-agej)/(J-Jr))*(double(0.5)-z1);
    end
end

% add the warm glow to the return, but only near end of life, and only with positive net worth
networth_prime=aprime+ks*(double_1-ks_out);
if agej-Jr>=10 && networth_prime>double_0
    % Warm glow of bequests: bequest are a luxury good
    warmglow=wg1+wg1*((double_1+networth_prime/wg2)^(double_1-wg3))/(double_1-wg3);
    % Modify for beta and sj (get the warm glow next period if die)
    warmglow=beta*(double_1-sj)*warmglow;
    % add the warm glow to the return
    leisure=leisure+warmglow;
end


end
