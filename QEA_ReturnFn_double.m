function F=QEA_ReturnFn_double(d,aprime,pvprime,a,pv,ks,z1,z2,w,sigma,psi,eta,agej,Jr,pension,r,ks_employee,kappa_j,wg1,wg2,wg3,beta,sj,energy_shock,pv_share_price)
% Is LifeCycleModel8_ReturnFn, but modified to include medical expense
% shocks when retired.

F=double(-Inf);
double_0=double(0); double_1=double(1); double_5=double(5);
h=d;
ks_out=d;

if agej<Jr
    if aprime<double_0 && pvprime>pv % Can't buy PVs using debt
        return
    end
else
    % If retired, cannot take on much debt
    if aprime+ks+100<double_0
        return
    end
end

housing=double(398)*kappa_j; % housing scales with income
utilities=double(80);
food=double(300);
% transport=double(252);
transport_fuel=double(150);
transport_nonfuel=double(252)-transport_fuel;
taxes=double_0; % only pay taxes when employed
discretionary=double(518)*kappa_j; % discretionary scales with income;
w_factor=double_1/double(2668); % unscaled weekly average gross wages

if agej<Jr % If working age
    employment_factor=(z1+double_1)/double(2); % full rate at full employment; half-rate when unemployed
    income=w*kappa_j*z1*h; % If unemployed, z1 product will be 0
    taxes=income*double(591)*w_factor; % taxes scale with income
    % Kiwisaver takes 5% out of income
    c=income*(double_1-ks_employee);
else % Retirement
    employment_factor=double(0.9); % Retirees less active?
    c=pension+ks_out*ks-z1; % Subtract z1 (medical expenses) here
end
if a>=double_0
    % Positive assets pay r interest rate
    c=c+(double_1+r)*a-aprime;
elseif agej==Jr && aprime==double_0
    % Jubilee !!
    c=c+double_1;
else
    % Negative assets pay 2*r loan rate
    c=c+(double_1+2*r)*a-aprime;
end
if c<=double_0 % Early out if cannot meet minimal consumption constraint
    return
end

% We now compute core living expenses to deduct from consumption; convert kiwi stats to model units
nongrid_expenses=housing+food+(transport_nonfuel+discretionary)*employment_factor+taxes;
grid_budget=utilities+transport_fuel*employment_factor;
% Calculate energy expense/income/investment
grid_expenses=grid_budget*(energy_shock*z2+double(~energy_shock));
if pv>double_5
    % grid_income is 1/2 the cost rate once above self-sufficient 5kW+10kWh system
    grid_income=grid_budget*(max(double_1,energy_shock*z2))*(pv-double_5)/10;
    grid_expenses=double_0;
else
    grid_income=double_0;
    grid_expenses=grid_expenses*(double_1-pv/double_5);
end
total_expenses=nongrid_expenses+grid_expenses;
pv_investment=w*(pvprime-pv)*pv_share_price;
c=c+(grid_income-total_expenses)*w_factor-pv_investment;
% Should leave about $529/week for further consumption/investment

if aprime<0
    if c+aprime>double_0 % No new debt for extra consumption
        return
    elseif agej<Jr && h<double(0.6) % No debt if not trying to hustle
        % Note that if unemployed, one can still offer hours, even if they don't count
        return
    end
end

if c>0
    F=(c^(double_1-sigma))/(double_1-sigma) -psi*(h^(double_1+eta))/(double_1+eta); % The utility function
    if aprime<0
        F=F*1e-3+aprime*1e4; % Trivialize calculated F and Disfavor debt so we used the least of it possible
    end
else
    F=(c-double_1)*1e3;
    if aprime<0
        F=F+aprime*1e5; % Trivialize calculated F and Disfavor debt so we used the least of it possible
    end
end


% add the warm glow to the return, but only near end of life
if agej-Jr>=10
    % Warm glow of bequests: bequest are a luxury good
    warmglow=wg1*((double_1+(aprime+ks*(double_1-ks_out))/wg2)^(double_1-wg3))/(double_1-wg3);
    % Modify for beta and sj (get the warm glow next period if die)
    warmglow=beta*(double_1-sj)*warmglow;
    % add the warm glow to the return
    F=F+warmglow;
end

end
