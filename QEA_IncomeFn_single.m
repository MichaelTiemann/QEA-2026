function income=QEA_IncomeFn_single(d,aprime,pvprime,a,pv,ks,z1,z2,w,agej,Jr,pension,r,kappa_j,ks_employee,energy_shock)
% Is LifeCycleModel8_ReturnFn, but modified to include medical expense
% shocks when retired.

single_0=single(0); single_1=single(1); single_5=single(5);
h=d;
ks_out=d;

utilities=single(80);
% transport=single(252);
transport_fuel=single(150);
w_factor=single(1/2668); % unscaled weekly average gross wages

if agej<Jr % If working age
    employment_factor=(z1+single_1)*0.5; % full rate at full employment; half-rate when unemployed
    % Kiwisaver takes 5% out of income
    income=w*kappa_j*z1*h*(single_1-ks_employee); % If unemployed, z1 product will be 0
else % Retirement
    employment_factor=single(0.9); % Retirees less active?
    income=pension+ks_out*ks;
end
if a>=single_0
    % Positive assets pay r interest rate
    income=income+(single_1+r)*a;
end

grid_budget=utilities+transport_fuel*employment_factor;
% Calculate energy expense/income/investment
if pv>single_5
    % grid_income is 1/2 the cost rate once above self-sufficient 5kW+10kWh system
    grid_income=grid_budget*(max(single_1,energy_shock*z2))*(pv-single_5)/10;
else
    grid_income=single_0;
end
income=(income+grid_income)*w_factor;


end
