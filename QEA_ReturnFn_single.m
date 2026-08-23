function F=QEA_ReturnFn_single(d,aprime,pvprime,a,pv,ks,z1,z2,w,sigma,psi,eta,agej,Jr,pension,r,ks_employee,kappa_j,wg1,wg2,wg3,beta,sj,energy_shock,pv_share_price)

single_0=single(0); single_1=single(1); single_5=single(5);
labor_h=d;
ks_out=d;

% 1. The Dimension Enforcer
% VFIToolkit passes these as correctly aligned multi-dimensional grids.
% Adding 0 * [every state/choice] forces Octave to expand 'c' to the full
% state space immediately, guaranteeing it matches VFIToolkit's expected size.
dim_enforcer = 0.*d + 0.*aprime + 0.*pvprime + 0.*a + 0.*pv + 0.*ks + 0.*z1 + 0.*z2;

housing=single(398);
utilities=single(80);
food_fuel=single(75);
food_nonfuel=single(225);
transport_fuel=single(150);
transport_nonfuel=single(252)-transport_fuel;
taxes=single_0;
discretionary=single(518);
w_factor=single(1/2668);

if agej<Jr
    housing=housing.*kappa_j;
    discretionary=discretionary.*kappa_j;
    employment_factor=(z1+single_1).*0.5;

    % Initialize income with the enforcer
    income=w.*kappa_j.*z1.*labor_h + dim_enforcer;
    taxes=income.*591.*w_factor;
    c=income.*(single_1-ks_employee);

    % Now add asset returns/drawdowns (no shiftdim needed)
    c = c + (single_1+r+r.*(a<0)).*a - aprime + 0.*pvprime.*ks;
else
    employment_factor=single(0.9);
    housing=housing.*employment_factor;

    % Initialize retirement consumption with the enforcer
    c=pension+ks_out.*ks-z1-1e9.*(ks_out>0.2)+(single_1+r+r.*(a<0)).*a-aprime + dim_enforcer;

    if agej == Jr
        c = c + (aprime == 0) .* single_1;
    end
end

%% Expenses and Grid Math
nongrid_expenses=housing+food_nonfuel+(transport_nonfuel+discretionary).*employment_factor+taxes;
grid_budget=utilities+food_fuel+transport_fuel.*employment_factor;

grid_expenses=grid_budget.*(energy_shock.*z2+single(~energy_shock));
grid_income=grid_budget.*(pv>single_5).*(max(single_1,energy_shock.*z2)).*(pv-single_5)./10;
grid_expenses=grid_expenses.*(pv<=single_5).*(single_1-pv./single_5);
total_expenses=nongrid_expenses+grid_expenses;

pv_investment=w.*(pvprime-pv).*pv_share_price;

c=c+(grid_income-total_expenses).*w_factor-pv_investment;

% 3. Safe debt deprecation using pure element-wise multiplication
bad_debt_mask = (aprime < 0) & ( (c + aprime > 0) | (agej < Jr & labor_h < 0.6) );
c = c - bad_debt_mask .* 1e9;

%% Utility Calculation
if agej < Jr
    h_util = labor_h;
else
    h_util = (c <= 0) .* (z1 ~= 0) .* single_1 ...
           + (c > 0) .* (aprime >= 0) .* c .* 0.5;
end

feasible=(c>0);
c_for_utility=c;
c_for_utility(~feasible)=1;

F=(c_for_utility.^(1-sigma))./(1-sigma) - psi.*(h_util.^(1+eta))./(1+eta);

%% Penalties
debt_mask = (aprime < 0);
feas_debt_mask = feasible & debt_mask;
infeas_mask = ~feasible;
infeas_debt_mask = infeas_mask & debt_mask;

F = F + feas_debt_mask .* (F .* (1e-3 - single_1) + aprime .* 1e4);
F = F + infeas_mask .* ( (c - single_1) .* 1e3 - F );
F = F + infeas_debt_mask .* ( aprime .* 1e5 );

%% Warm Glow
if agej-Jr>=10
    networth_prime=aprime+ks.*(single_1-ks_out)+0.*a.*z1;
    safe_nw = max(networth_prime, single_0);

    warmglow=(networth_prime>0).*wg1.*((single_1+safe_nw./wg2).^(single_1-wg3))./(single_1-wg3);
    warmglow=beta.*(single_1-sj).*warmglow;
    F=F+warmglow;
end

end
