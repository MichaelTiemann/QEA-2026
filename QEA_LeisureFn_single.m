function leisure=QEA_LeisureFn_single(d,aprime,pvprime,a,pv,ks,z1,z2,w,agej,Jr,pension,r,kappa_j,ks_employee,wg1,wg2,wg3,beta,sj,energy_shock,pv_share_price)
% Is LifeCycleModel8_ReturnFn, but modified to include medical expense
% shocks when retired.

single_0=single(0); single_1=single(1);
h=d;
ks_out=d;

discretionary=single(518);
w_factor=single(1/2668); % unscaled weekly average gross wages

leisure=single_0;
if agej<Jr % If working age
    discretionary=discretionary*kappa_j; % discretionary scales with income;
    employment_factor=(z1+single_1)*0.5; % full rate at full employment; half-rate when unemployed
    leisure=w*(single_1-h)*z1*kappa_j*2;
else % Retirement
    employment_factor=single(0.9); % Retirees less active?
    if aprime>=single_0 && z1==0
        income=QEA_IncomeFn_single(d,aprime,pvprime,a,pv,ks,z1,z2,w,agej,Jr,pension,r,kappa_j,ks_employee,energy_shock);
        expenses=QEA_ExpensesFn_single(d,aprime,pvprime,a,pv,ks,z1,z2,w,agej,Jr,r,kappa_j,energy_shock,pv_share_price);
        if income>expenses
            leisure=0.5*(income-expenses);
        end
    end
end
leisure=leisure+discretionary*w_factor*employment_factor;

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
