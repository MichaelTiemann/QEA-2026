function inc = QEA_IncomeFn_single(d, aprime, pvprime, a, pv, ks, z1, z2, w, agej, Jr, pension, r, kappa_j, ks_employee, energy_shock)

% Constants
utilities = 80;
transport_fuel = 150;
w_factor = 1/2668;

% 1. Age-Dependent Base Income & Employment Factor
if agej < Jr
    % Working age: 'd' acts as hours worked (h)
    employment_factor = (z1 + 1) .* 0.5; % Full rate at full emp; half-rate when unemployed
    base_income = w .* kappa_j .* z1 .* d .* (1 - ks_employee);
else
    % Retirement: 'd' acts as Kiwisaver withdrawal fraction (ks_out)
    employment_factor = 0.9; % Retirees less active
    base_income = pension + d .* ks;
end

% 2. Capital Income & Gains (Only triggered when a >= 0)
pos_a = (a >= 0);
capital_income = r .* a .* pos_a;

% Capital gains are only realized if a > aprime (and a >= 0)
capital_gains = (a - aprime) .* (a > aprime) .* pos_a;

% 3. PV Grid Income
% grid_budget automatically expands into a matrix during working age because of z1
grid_budget = utilities + transport_fuel .* employment_factor;

% Mask for excess PV. The (pv - 5) ./ 10 mathematically handles the 1/2 rate.
% max() is natively vectorized and evaluates the energy_shock * z2 interaction instantly.
excess_pv = (pv > 5);
grid_income = grid_budget .* max(1, energy_shock .* z2) .* (pv - 5) .* 0.1 .* excess_pv;

% 4. Total Income
inc = base_income + capital_income + capital_gains + grid_income .* w_factor;


end
