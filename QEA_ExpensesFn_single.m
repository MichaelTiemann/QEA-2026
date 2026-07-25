function expenses=QEA_ExpensesFn_single(d,aprime,pvprime,a,pv,ks,z1,z2,w,agej,Jr,r,kappa_j,energy_shock,pv_share_price)
% Is LifeCycleModel8_ReturnFn, but modified to include medical expense
% shocks when retired.

single_0=single(0); single_1=single(1); single_5=single(5);
h=d;

housing=single(398);
utilities=single(80);
food=single(300);
% transport=single(252);
transport_fuel=single(150);
transport_nonfuel=single(252)-transport_fuel;
taxes=single_0; % only pay taxes when employed
discretionary=single(518);
w_factor=single_1/single(2668); % unscaled weekly average gross wages

if agej<Jr % If working age
    housing=housing*kappa_j; % housing scales with income
    discretionary=discretionary*kappa_j; % discretionary scales with income;
    employment_factor=(z1+single_1)/single(2); % full rate at full employment; half-rate when unemployed
    income=w*kappa_j*z1*h; % If unemployed, z1 product will be 0
    taxes=income*591*w_factor; % taxes scale with income
    expenses=single_0;
else % Retirement
    employment_factor=single(0.9); % Retirees less active?
    housing=housing*employment_factor;
    expenses=z1; % Subtract z1 (medical expenses) here
end
if a<0
    % Negative assets pay 2*r loan rate
    expenses=expenses-(single_1+2*r)*a;
end
if aprime>a
    expenses=expenses-aprime-a;
end

% We now compute core living expenses to deduct from consumption; convert kiwi stats to model units
nongrid_expenses=housing+food+(transport_nonfuel+discretionary)*employment_factor+taxes;
grid_budget=utilities+transport_fuel*employment_factor;
% Calculate energy expense/income/investment
grid_expenses=grid_budget*(energy_shock*z2+single(~energy_shock));
if pv>single_5
    % grid_income is 1/2 the cost rate once above self-sufficient 5kW+10kWh system
    grid_expenses=single_0;
else
    grid_expenses=grid_expenses*(single_1-pv/single_5);
end
total_expenses=nongrid_expenses+grid_expenses;
pv_investment=w*(pvprime-pv)*pv_share_price;
expenses=expenses+total_expenses*w_factor+pv_investment;


end
