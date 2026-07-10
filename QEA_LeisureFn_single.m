function leisure=QEA_LeisureFn_single(d,aprime,pvprime,a,pv,ks,z1,z2,w,agej,Jr,J,kappa_j,wg1,wg2,wg3,beta,sj)
% Is LifeCycleModel8_ReturnFn, but modified to include medical expense
% shocks when retired.

single_0=single(0); single_1=single(1);
h=d;
ks_out=d;

leisure=single_0;
if agej<Jr % If working age
    leisure=(single_1-h)*z1*kappa_j;
else % Retirement
    if aprime>=single_0
        leisure=((J-agej)/(J-Jr))*(single(0.5)-z1);
    end
end

% add the warm glow to the return, but only near end of life, and only with positive net worth
networth_prime=aprime+ks*(single_1-ks_out);
if agej-Jr>=10 && networth_prime>single_0
    % Warm glow of bequests: bequest are a luxury good
    warmglow=wg1+wg1*((single_1+networth_prime/wg2)^(single_1-wg3))/(single_1-wg3);
    % Modify for beta and sj (get the warm glow next period if die)
    warmglow=beta*(single_1-sj)*warmglow;
    % add the warm glow to the return
    leisure=leisure+warmglow;
end


end
