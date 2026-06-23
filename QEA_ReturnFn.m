function F=QEA_ReturnFn(h,ks_out,aprime,pvprime,a,pv,ks_balance,z1,z2,w,sigma,psi,eta,agej,Jr,pension,r,ks_employee,kappa_j,wg1,wg2,wg3,beta,sj,energy_budget,energy_shock,pv_share_price)
% Is LifeCycleModel8_ReturnFn, but modified to include medical expense
% shocks when retired.

F=single(-Inf);
single_0=single(0); single_1=single(1);
if agej<Jr && ks_out>single_0 % If working age, no KiwiSaver redemptions allowed
    return
end

pv_cost_delta=w*(pv-pvprime)*pv_share_price;

% Calculate energy expense/income/investment
energy_cost=energy_budget*(energy_shock*(z2-single_1)+single(~energy_shock));
if pv>5
    energy_income=energy_cost*(pv-single(5))/10;
    energy_cost=single_0;
else
    energy_income=single_0;
    energy_cost=energy_cost*(single_1-pv/5);
end
energy=energy_income-energy_cost+pv_cost_delta;

if agej<Jr % If working age
    income=w*kappa_j*z1*h; % If unemployed, z1 product will be 0
    % Kiwisaver takes 5% out of income
    c=income*(single_1-ks_employee)+energy+(single_1+r)*a-aprime;
else % Retirement
    c=pension+energy+ks_out*ks_balance+(single_1+r)*a-z1-aprime; % Subtract z1 (medical expenses) here
end

if c>0
    F=(c^(single_1-sigma))/(single_1-sigma) -psi*(h^(single_1+eta))/(single_1+eta); % The utility function
end

% add the warm glow to the return, but only near end of life
if agej-Jr>=10
    % Warm glow of bequests: bequest are a luxury good
    warmglow=wg1*((single_1+(aprime+ks_balance*(1-ks_out))/wg2)^(single_1-wg3))/(single_1-wg3);
    % Modify for beta and sj (get the warm glow next period if die)
    warmglow=beta*(single_1-sj)*warmglow;
    % add the warm glow to the return
    F=F+warmglow;
end

end
