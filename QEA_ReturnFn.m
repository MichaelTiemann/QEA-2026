function F=QEA_ReturnFn(h,ks_out,aprime,pvprime,a,pv,ks,z1,z2,w,sigma,psi,eta,agej,Jr,pension,r,ks_employee,kappa_j,wg1,wg2,wg3,beta,sj,energy_shock,pv_share_price)
% Is LifeCycleModel8_ReturnFn, but modified to include medical expense
% shocks when retired.

F=single(-Inf);
single_0=single(0); single_1=single(1);

if agej<Jr
    if ks_out>single_0 % If working age, no KiwiSaver withdrawals allowed
        return
    end
    if aprime<0 && pvprime>pv % Can't buy PVs using debt
        return
    end
else
    % If retired, cannot take on debt
    if aprime<0
        return
    end
end

housing=single(398)*kappa_j; % housing scales with income
utilities=single(80);
food=single(300);
transport=single(252);
taxes=single_0; % only pay taxes when employed
discretionary=single(518)*kappa_j; % discretionary scales with income;
w_factor=single_1/single(2668); % unscaled weekly average gross wages

if agej<Jr % If working age
    employment_factor=(z1+single_1)/single(2); % full rate at full employment; half-rate when unemployed
    income=w*kappa_j*z1*h; % If unemployed, z1 product will be 0
    taxes=income*single(591)*w_factor; % taxes scale with income
    % Kiwisaver takes 5% out of income
    c=income*(single_1-ks_employee);
    if a>=single_0
        % Positive assets pay r interest rate
        c=c+(single_1+r)*a-aprime;
    else
        % Negative assets pay 2*r loan rate
        c=c+(single_1+2*r)*a-aprime;
    end
else % Retirement
    employment_factor=single(0.9); % Retirees less active?
    c=pension+ks_out*ks+(single_1+r)*a-z1-aprime; % Subtract z1 (medical expenses) here
end
if c<0
    % Early out if aprime is stupidly large
    % F=c*1e6;
    return
end

% We now compute core living expenses to deduct from consumption; convert kiwi stats to model units
nongrid_expenses=housing+food+discretionary*employment_factor+taxes;
grid_budget=utilities+transport*employment_factor;
% Calculate energy expense/income/investment
grid_expenses=grid_budget*(energy_shock*z2+single(~energy_shock));
if pv>5
    % grid_income is 1/2 the cost rate once above self-sufficient 5kW+10kWh system
    grid_income=grid_budget*(max(single_1,energy_shock*z2))*(pv-single(5))/10;
    grid_expenses=single_0;
else
    grid_income=single_0;
    grid_expenses=grid_expenses*(single_1-pv/5);
end
total_expenses=nongrid_expenses+grid_expenses;
pv_investment=w*(pvprime-pv)*pv_share_price;
c=c+(grid_income-total_expenses)*w_factor-pv_investment;
% Should leave about $529/week for further consumption/investment

if aprime<0
    if c+aprime>0 % No debt for extra consumption
        return
    elseif h < 0.6 % No debt if not trying to hustle
        % Note that if unemployed, one can still offer hours...
        return
    end
end

if c>0
    F=(c^(single_1-sigma))/(single_1-sigma) -psi*(h^(single_1+eta))/(single_1+eta); % The utility function
else
    F=(c-1)*1e3;
end
if aprime<0
    F=F+aprime*1e4; % Disfavor debt so we used the least of it possible
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
