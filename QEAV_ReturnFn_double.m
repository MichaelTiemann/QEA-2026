function F = QEAV_ReturnFn_double(d, aprime, pvprime, a, pv, ks, z1, z2, w, sigma, psi, eta, agej, Jr, pension, r, ks_employee, kappa_j, wg1, wg2, wg3, beta, sj, energy_shock, pv_share_price)
% Hyper-Optimized "Lazy Expansion" ReturnFn

% Base constants
housing_base = 398;
utilities = 80;
food_fuel = 75;
food_nonfuel = 225;
transport_fuel = 150;
transport_nonfuel = 252 - transport_fuel;
discretionary_base = 518;
w_factor = 1/2668;

% --- 1. Age-Dependent Income and Base Constraints ---
if agej < Jr
    % Working Age
    valid_mask = ~(aprime < 0 & pvprime > pv);
    
    housing = housing_base * kappa_j;
    discretionary = discretionary_base * kappa_j;
    employment_factor = (z1 + 1) * 0.5;
    
    income = w * kappa_j .* z1 .* d;
    taxes = income * 591 * w_factor;
    c = income * (1 - ks_employee);
    
    h = d;
    ks_out = 0; % Scalar natively broadcasts
else
    % Retirement Age
    valid_mask = ~(d > 0.2);
    
    sick_mask = (z1 ~= 0);
    h = double(sick_mask); % 0 if healthy, 1 if sick
    
    employment_factor = 0.9;
    housing = housing_base * 0.9;
    discretionary = discretionary_base;
    
    ks_out = d;
    c = pension + ks_out .* ks - z1;
    taxes = 0;
end

% --- 2. Asset Returns & Debt Costs ---
pos_a = (a >= 0);
jubilee = (agej == Jr & aprime == 0);
neg_a = ~(pos_a | jubilee);

% Stays as small as possible via implicit expansion
c = c + pos_a .* ((1 + r) .* a - aprime) + jubilee .* 1 + neg_a .* ((1 + 2*r) .* a - aprime);

if agej < Jr
    valid_mask = valid_mask & ~(c <= 0); % Early out for negative c
end

% --- 3. Core Living Expenses ---
nongrid_expenses = housing + food_nonfuel + (transport_nonfuel + discretionary) .* employment_factor + taxes;
grid_budget = utilities + food_fuel + transport_fuel .* employment_factor;

grid_expenses = grid_budget .* (energy_shock .* z2 + double(~energy_shock));
pv_high = (pv > 5);

grid_income = pv_high .* (grid_budget .* max(1, energy_shock .* z2) .* (pv - 5) / 10);
grid_expenses = grid_expenses .* (~pv_high) .* (1 - pv / 5);

total_expenses = nongrid_expenses + grid_expenses;
pv_investment = w .* (pvprime - pv) .* pv_share_price;
c = c + (grid_income - total_expenses) .* w_factor - pv_investment;

% --- 4. Debt Restrictions ---
valid_mask = valid_mask & ~((aprime < 0) & (c + aprime > 0));

if agej < Jr
    valid_mask = valid_mask & ~((aprime < 0) & ~(c + aprime > 0) & (h < 0.6));
end

% --- 5. Utility Evaluation (Pure Algebraic Masking) ---
pos_c = (c > 0);

if agej >= Jr
    ret_pos_c_neg_a = pos_c & (aprime < 0);
    ret_pos_c_pos_a = pos_c & ~(aprime < 0);
    h = h .* ~(ret_pos_c_neg_a | ret_pos_c_pos_a) + ret_pos_c_pos_a .* (c * 0.5);
end

% SAFEGUARD: Prevent complex numbers and Inf * 0 = NaN crashes
c_safe = max(c, 0.001); 
h_safe = max(h, 0); 

% U_pos handles c > 0 (Using safe clamped arrays)
U_pos = (c_safe.^(1 - sigma)) ./ (1 - sigma) - psi * (h_safe.^(1 + eta)) ./ (1 + eta);
U_pos = U_pos + (aprime < 0) .* (U_pos * 1e-3 + aprime * 1e4);

% U_neg handles c <= 0
U_neg = (c - 1) * 1e3;
U_neg = U_neg + (aprime < 0) .* (aprime * 1e5);

% Combine (F fully expands to the master tensor size here!)
F = U_pos .* pos_c + U_neg .* (~pos_c);

% --- 6. Warm Glow of Bequests ---
if (agej - Jr) >= 10
    networth_prime = aprime + ks .* (1 - ks_out);
    wg_mask = (networth_prime > 0);
    
    % SAFEGUARD: Prevent complex roots in bequest utility
    nw_safe = max(networth_prime, 0); 
    
    warmglow = wg1 * ((1 + nw_safe / wg2).^(1 - wg3)) ./ (1 - wg3);
    F = F + beta * (1 - sj) * (warmglow .* wg_mask);
end

% --- 7. Safely Apply -Inf to Invalid States ---
% Force F and valid_mask to perfectly match sizes without intermediate allocations
F = F + double(valid_mask) * 0; 
valid_mask = valid_mask & true(size(F));
F(~valid_mask) = -Inf;


end
