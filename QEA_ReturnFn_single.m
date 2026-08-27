function F=QEA_ReturnFn_single(d,aprime,pvprime,a,pv,ks,z1,z2,w,sigma,psi,eta,agej,Jr,pension,r,ks_employee,kappa_j,wg1,wg2,wg3,beta,sj,energy_shock,pv_share_price)

single_0=single(0);
single_1=single(1);
single_5=single(5);

labor_h=d;
ks_out=d;

% 1. The Dimension Enforcer (Optimized using BLAS)
dim_enforcer = 0*d + 0*aprime + 0*pvprime + 0*a + 0*pv + 0*ks + 0*z1 + 0*z2;

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
    % Pre-compute scalars before matrix operations
    housing = housing * kappa_j;
    discretionary = discretionary * kappa_j;

    % Use BLAS scalar multiplication
    employment_factor = (z1 + single_1) * 0.5;

    % Group scalars: (w * kappa_j) evaluated once, then applied to the matrix
    income = (w * kappa_j) * (z1 .* labor_h) + dim_enforcer;

    % Pre-compute scalar scaling factor
    taxes = income * (591 * w_factor);
    c = income * (single_1 - ks_employee);

    % r * (a<0) is scalar * logical matrix -> uses BLAS!
    c = c + (single_1 + r + r * (a < 0)) .* a - aprime + 0 * (pvprime .* ks);
else
    employment_factor=single(0.9);
    housing = housing * employment_factor;

    % Optimized scalar multiplications
    c = pension + ks_out .* ks - z1 - 1e9 * (ks_out > 0.2) + (single_1 + r + r * (a < 0)) .* a - aprime + dim_enforcer;

    if agej == Jr
        c = c + (aprime == 0) * single_1;
    end
end

%% Expenses and Grid Math
% Pre-group scalar addition (transport_nonfuel + discretionary)
nongrid_expenses = housing + food_nonfuel + (transport_nonfuel + discretionary) * employment_factor + taxes;

grid_budget = utilities + food_fuel + transport_fuel * employment_factor;

% Assuming energy_shock is a scalar parameter
grid_expenses = grid_budget .* (energy_shock * z2 + single(~energy_shock));

% Division converted to scalar multiplication (* 0.1)
grid_income = grid_budget .* (pv > single_5) .* (max(single_1, energy_shock * z2)) .* (pv - single_5) * 0.1;

% Division converted to scalar reciprocal (* (1/single_5))
grid_expenses = grid_expenses .* (pv <= single_5) .* (single_1 - pv * (1/single_5));
total_expenses = nongrid_expenses + grid_expenses;

% Pre-compute scalar product (w * pv_share_price)
pv_investment = (w * pv_share_price) * (pvprime - pv);

c = c + (grid_income - total_expenses) * w_factor - pv_investment;

% Logical AND (&) is faster than floating-point multiplication (.*)
bad_debt_mask = (aprime < 0) & ( (c + aprime > 0) | (agej < Jr & labor_h < 0.6) );
c = c - bad_debt_mask * 1e9;

%% Utility Calculation
if agej < Jr
    h_util = labor_h;
else
    % Use logical & instead of .* for masks
    h_util = ((c <= 0) & (z1 ~= 0)) * single_1 + ((c > 0) & (aprime >= 0)) .* c * 0.5;
end

feasible = (c > 0);
c_for_utility = c;
c_for_utility(~feasible) = single_1;

% Pre-compute the division scalars to use BLAS multiplication
util_scale_c = single_1 / (single_1 - sigma);
util_scale_h = psi / (single_1 + eta);

F = (c_for_utility .^ (single_1 - sigma)) * util_scale_c - (h_util .^ (single_1 + eta)) * util_scale_h;

%% Penalties
debt_mask = (aprime < 0);
feas_debt_mask = feasible & debt_mask;
infeas_mask = ~feasible;
infeas_debt_mask = infeas_mask & debt_mask;

% Stripped unnecessary dots for scalar penalties
F = F + feas_debt_mask .* (F * (1e-3 - single_1) + aprime * 1e4);
F = F + infeas_mask .* ((c - single_1) * 1e3 - F);
F = F + infeas_debt_mask .* (aprime * 1e5);

%% Warm Glow
if agej - Jr >= 10
    networth_prime = aprime + ks .* (single_1 - ks_out) + 0 * (a .* z1);
    safe_nw = max(networth_prime, single_0);

    % Pre-compute all the scalar math
    wg_scalar_multiplier = (wg1 / (single_1 - wg3)) * (beta * (single_1 - sj));

    % Replaced division with reciprocal multiplication (* (1/wg2))
    warmglow = (networth_prime > 0) .* ((single_1 + safe_nw * (single_1/wg2)) .^ (single_1 - wg3)) * wg_scalar_multiplier;

    F = F + warmglow;
end


end
