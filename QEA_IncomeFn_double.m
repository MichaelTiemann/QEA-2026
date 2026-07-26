function income=QEA_IncomeFn_double(d,aprime,pvprime,a,pv,ks,z1,z2,w,agej,Jr,pension,r,kappa_j,ks_employee,energy_shock)
% Is LifeCycleModel8_ReturnFn, but modified to include medical expense
% shocks when retired.

double_0=double(0); double_1=double(1); double_5=double(5);
h=d;
ks_out=d;

utilities=double(80);
% transport=double(252);
transport_fuel=double(150);
w_factor=double(1/2668); % unscaled weekly average gross wages

if agej<Jr % If working age
    employment_factor=(z1+double_1)*0.5; % full rate at full employment; half-rate when unemployed
    % Kiwisaver takes 5% out of income
    income=w*kappa_j*z1*h*(double_1-ks_employee); % If unemployed, z1 product will be 0
else % Retirement
    employment_factor=double(0.9); % Retirees less active?
    income=pension+ks_out*ks;
end
if a>=double_0
    % Positive assets pay r interest rate
    income=income+r*a;
    if a>aprime
        income=income+a-aprime;
    end
end

grid_budget=utilities+transport_fuel*employment_factor;
% Calculate energy expense/income/investment
if pv>double_5
    % grid_income is 1/2 the cost rate once above self-sufficient 5kW+10kWh system
    grid_income=grid_budget*(max(double_1,energy_shock*z2))*(pv-double_5)/10;
else
    grid_income=double_0;
end
income=income+grid_income*w_factor;


end
