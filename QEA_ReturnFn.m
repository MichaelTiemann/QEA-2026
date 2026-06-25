function F=QEA_ReturnFn(h,ks_out,aprime,pvprime,a,pv,ks,z1,z2,w,sigma,psi,eta,agej,Jr,pension,r,ks_employee,kappa_j,wg1,wg2,wg3,beta,sj,energy_shock,pv_share_price)
% Is LifeCycleModel8_ReturnFn, but modified to include medical expense
% shocks when retired.

F=single(-Inf);
single_0=single(0); single_1=single(1);
if agej<Jr && ks_out>single_0 % If working age, no KiwiSaver redemptions allowed
    return
end

housing=single(398);
utilities=single(80);
food=single(300);
transport=single(252);
taxes=single_0; % only pay taxes when employed
discretionary=single(518);
w_factor=single_1/single(2668);

if agej<Jr % If working age
    income=w*kappa_j*z1*h; % If unemployed, z1 product will be 0
    taxes=single(591)*z1;
    % Kiwisaver takes 5% out of income
    c=income*(single_1-ks_employee)+(single_1+r)*a-aprime;
else % Retirement
    c=pension+ks_out*ks+(single_1+r)*a-z1-aprime; % Subtract z1 (medical expenses) here
end
if c<0
    % Early out if aprime is stupidly large
    % F=c*1e6;
    return
end

% We now compute core living expenses to deduct from consumption; convert kiwi stats to model units
employment_factor=(z1+single_1)/single(2); % full rate at full employment; half-rate when unemployed
nongrid_expenses=(housing+food+discretionary*employment_factor+taxes)*w_factor;
grid_budget=(utilities+transport*employment_factor)*w_factor;
% Calculate energy expense/income/investment
grid_expenses=grid_budget*(energy_shock*(z2-single_1)+single(~energy_shock));
if pv>5
    % grid_income is 1/2 the cost rate once above self-sufficient 5kW+10kWh system
    grid_income=grid_budget*(max(single_1,energy_shock*(z2-single_1)))*(pv-single(5))/10;
    grid_expenses=single_0;
else
    grid_income=single_0;
    grid_expenses=grid_expenses*(single_1-pv/5);
end
total_expenses=nongrid_expenses+grid_expenses;
pv_investment=w*(pvprime-pv)*pv_share_price;
c=c+grid_income-total_expenses-pv_investment;
% Should leave about $529/week for further consumption/investment

if c>0
    F=(c^(single_1-sigma))/(single_1-sigma) -psi*(h^(single_1+eta))/(single_1+eta); % The utility function
else
    F=(c-1)*1e3;
end

% add the warm glow to the return, but only near end of life
if agej-Jr>=10
    % Warm glow of bequests: bequest are a luxury good
    warmglow=wg1*((single_1+(aprime+ks*(1-ks_out))/wg2)^(single_1-wg3))/(single_1-wg3);
    % Modify for beta and sj (get the warm glow next period if die)
    warmglow=beta*(single_1-sj)*warmglow;
    % add the warm glow to the return
    F=F+warmglow;
end

end
