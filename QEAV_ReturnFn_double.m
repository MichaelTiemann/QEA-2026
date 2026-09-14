function F = QEAV_ReturnFn_double(d, aprime, pvprime, a, pv, ks, z1, z2, w, sigma, psi, eta, agej, Jr, pension, r, ks_employee, kappa_j, wg1, wg2, wg3, beta, sj, energy_shock, pv_share_price)
% Vectorized LifeCycleModel8_ReturnFn

% --- 1. Initialization and Shape Inference ---
% We use 'aprime' to infer the tensor shape, initializing F to -Inf.
F = -Inf(size(aprime), 'like', aprime);
valid_mask = true(size(aprime)); % Tracks agents who haven't hit an early 'return'

h = d;
ks_out = d;
taxes = zeros(size(aprime), 'like', aprime);

% Base constants
housing_base = 398; 
utilities = 80;
food_fuel = 75;
food_nonfuel = 225;
transport_fuel = 150;
transport_nonfuel = 252 - transport_fuel;
discretionary_base = 518; 
w_factor = 1/2668; 

% --- 2. Age-Dependent Income and Base Constraints ---
if agej < Jr
    % Working Age
    valid_mask = valid_mask & ~(aprime < 0 & pvprime > pv);
    
    housing = housing_base * kappa_j;
    discretionary = discretionary_base * kappa_j;
    employment_factor = (z1 + 1) * 0.5;
    
    income = w * kappa_j .* z1 .* h;
    taxes = income * 591 * w_factor;
    c = income * (1 - ks_employee);
else
    % Retirement Age
    valid_mask = valid_mask & ~(ks_out > 0.2);
    h = zeros(size(d), 'like', d);
    
    employment_factor = 0.9 + zeros(size(aprime), 'like', aprime);
    housing = housing_base * 0.9;
    discretionary = discretionary_base; % Assuming base carries over if not scaled? (Adjust if retired has no discretionary)
    
    c = pension + ks_out .* ks - z1;
    h(z1 ~= 0) = 1; % Focus on getting healthy
end

% --- 3. Asset Returns & Debt Costs ---
pos_a = (a >= 0);
jubilee = (agej == Jr & aprime == 0);
neg_a = ~(pos_a | jubilee);

c(pos_a)   = c(pos_a)   + (1 + r) * a(pos_a)   - aprime(pos_a);
c(jubilee) = c(jubilee) + 1;
c(neg_a)   = c(neg_a)   + (1 + 2*r) * a(neg_a) - aprime(neg_a);

if agej < Jr
    valid_mask = valid_mask & ~(c <= 0); % Early out if c <= 0
end

% --- 4. Core Living Expenses ---
nongrid_expenses = housing + food_nonfuel + (transport_nonfuel + discretionary) .* employment_factor + taxes;
grid_budget = utilities + food_fuel + transport_fuel .* employment_factor;

grid_expenses = grid_budget .* (energy_shock .* z2 + double(~energy_shock));
grid_income = zeros(size(aprime), 'like', aprime);

pv_high = (pv > 5);
if any(pv_high(:))
    grid_income(pv_high) = grid_budget(pv_high) .* max(1, energy_shock * z2(pv_high)) .* (pv(pv_high) - 5) / 10;
    grid_expenses(pv_high) = 0;
end
if any(~pv_high(:))
    grid_expenses(~pv_high) = grid_expenses(~pv_high) .* (1 - pv(~pv_high) / 5);
end

total_expenses = nongrid_expenses + grid_expenses;
pv_investment = w * (pvprime - pv) * pv_share_price;
c = c + (grid_income - total_expenses) * w_factor - pv_investment;

% --- 5. Debt Restrictions (aprime < 0) ---
invalid_debt_1 = (aprime < 0) & (c + aprime > 0);
valid_mask = valid_mask & ~invalid_debt_1;

if agej < Jr
    invalid_debt_2 = (aprime < 0) & ~(c + aprime > 0) & (h < 0.6);
    valid_mask = valid_mask & ~invalid_debt_2;
end

% --- 6. Utility Evaluation ---
pos_c = (c > 0);

if agej >= Jr
    ret_pos_c_neg_a = pos_c & (aprime < 0);
    ret_pos_c_pos_a = pos_c & ~(aprime < 0);
    
    h(ret_pos_c_neg_a) = 0;
    h(ret_pos_c_pos_a) = c(ret_pos_c_pos_a) * 0.5;
end

% A. Evaluate strictly valid states where c > 0
valid_pos = valid_mask & pos_c;
% Note: Because we only index `c(valid_pos)`, it is guaranteed > 0, 
% preventing complex number generation from negative fractional powers.
F(valid_pos) = (c(valid_pos).^(1 - sigma)) ./ (1 - sigma) - psi * (h(valid_pos).^(1 + eta)) ./ (1 + eta);

debt_pos = valid_pos & (aprime < 0);
F(debt_pos) = F(debt_pos) * 1e-3 + aprime(debt_pos) * 1e4;

% B. Evaluate valid states where c <= 0 (Disfavored solutions)
valid_neg = valid_mask & ~pos_c;
F(valid_neg) = (c(valid_neg) - 1) * 1e3;

debt_neg = valid_neg & (aprime < 0);
F(debt_neg) = F(debt_neg) + aprime(debt_neg) * 1e5;

% --- 7. Warm Glow of Bequests ---
if (agej - Jr) >= 10
    networth_prime = aprime + ks .* (1 - ks_out);
    wg_mask = valid_mask & (networth_prime > 0);
    
    warmglow = wg1 * ((1 + networth_prime(wg_mask) / wg2).^(1 - wg3)) ./ (1 - wg3);
    F(wg_mask) = F(wg_mask) + beta * (1 - sj) * warmglow;
end

end