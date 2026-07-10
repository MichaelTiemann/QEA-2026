function expenses=QEA_ExpensesFn_double(d,aprime,pvprime,a,pv,ks,z1,z2,w,agej,Jr,r,kappa_j,energy_shock,pv_share_price)
% Is LifeCycleModel8_ReturnFn, but modified to include medical expense
% shocks when retired.

double_0=double(0); double_1=double(1); double_5=double(5);
h=d;

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
    taxes=income*591*w_factor; % taxes scale with income
    expenses=double_0;
else % Retirement
    employment_factor=double(0.9); % Retirees less active?
    expenses=z1; % Subtract z1 (medical expenses) here
end
if a<0
    % Negative assets pay 2*r loan rate
    expenses=expenses-(double_1+2*r)*a;
end

% We now compute core living expenses to deduct from consumption; convert kiwi stats to model units
nongrid_expenses=housing+food+(transport_nonfuel+discretionary)*employment_factor+taxes;
grid_budget=utilities+transport_fuel*employment_factor;
% Calculate energy expense/income/investment
grid_expenses=grid_budget*(energy_shock*z2+double(~energy_shock));
if pv>double_5
    % grid_income is 1/2 the cost rate once above self-sufficient 5kW+10kWh system
    grid_expenses=double_0;
else
    grid_expenses=grid_expenses*(double_1-pv/double_5);
end
total_expenses=nongrid_expenses+grid_expenses;
pv_investment=w*(pvprime-pv)*pv_share_price;
expenses=expenses+total_expenses*w_factor+pv_investment;


end
