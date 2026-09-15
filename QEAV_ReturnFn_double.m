function F = QEAV_ReturnFn_double(d, aprime, pvprime, a, pv, ks, z1, z2, w, sigma, psi, eta, agej, Jr, pension, r, ks_employee, kappa_j, wg1, wg2, wg3, beta, sj, energy_shock, pv_share_price)
% Vectorized LifeCycleModel8_ReturnFn

% --- 1. Initialization & The Universal Dimensional Guard ---
% Create a zero-tensor representing the full expanded state-space mesh
dim_guard = zeros(size(d + aprime + a + pv + ks + z1 + z2), 'like', aprime);
full_mask = false(size(dim_guard)); % Used to force logical arrays to full size

F = -Inf(size(dim_guard), 'like', aprime);
valid_mask = true(size(dim_guard)); 

% Pre-expand variables that will be logically indexed later
h = d + dim_guard;
ks_out = d + dim_guard;
taxes = dim_guard;
aprime_full = aprime + dim_guard; 

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
    taxes = income * 591 * w_factor + dim_guard;
    c = income * (1 - ks_employee) + dim_guard;
else
    % Retirement Age
    valid_mask = valid_mask & ~(ks_out > 0.2);
    h = dim_guard;
    
    employment_factor = 0.9 + dim_guard;
    housing = housing_base * 0.9;
    discretionary = discretionary_base; 
    
    c = pension + ks_out .* ks - z1 + dim_guard;
    
    % Algebraic Masking (Replaces h(z1~=0)=1)
    sick_mask = (z1 ~= 0);
    h = h .* (~sick_mask) + 1 .* sick_mask;
end

% --- 3. Asset Returns & Debt Costs (Pure Algebraic Masking) ---
pos_a = (a >= 0);
jubilee = (agej == Jr & aprime == 0);
neg_a = ~(pos_a | jubilee);

% Instead of c(pos_a) = ..., we mathematically multiply by the boolean arrays
% This utilizes native implicit expansion and completely avoids shape crashes!
c = c + pos_a .* ((1 + r) .* a - aprime);
c = c + jubilee .* 1;
c = c + neg_a .* ((1 + 2*r) .* a - aprime);

if agej < Jr
    valid_mask = valid_mask & ~(c <= 0); % Early out if c <= 0
end

% --- 4. Core Living Expenses ---
nongrid_expenses = housing + food_nonfuel + (transport_nonfuel + discretionary) .* employment_factor + taxes;
grid_budget = utilities + food_fuel + transport_fuel .* employment_factor;

grid_expenses = grid_budget .* (energy_shock .* z2 + double(~energy_shock));
grid_income = dim_guard;

pv_high = (pv > 5);

% Algebraic Masking for PV returns
grid_income = grid_income + pv_high .* (grid_budget .* max(1, energy_shock .* z2) .* (pv - 5) / 10);
grid_expenses = grid_expenses .* (~pv_high) .* (1 - pv / 5); 

total_expenses = nongrid_expenses + grid_expenses;
pv_investment = w .* (pvprime - pv) .* pv_share_price;
c = c + (grid_income - total_expenses) .* w_factor - pv_investment;

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
    
    % Algebraic Masking for h
    h = h .* ~(ret_pos_c_neg_a | ret_pos_c_pos_a) + ret_pos_c_pos_a .* (c * 0.5);
end

% A. Evaluate strictly valid states where c > 0
% We force full_mask here so logical indexing into F works natively
valid_pos = (valid_mask & pos_c) | full_mask;

F(valid_pos) = (c(valid_pos).^(1 - sigma)) ./ (1 - sigma) - psi * (h(valid_pos).^(1 + eta)) ./ (1 + eta);

% Because we pre-expanded aprime_full, it won't crash when indexed here!
debt_pos = valid_pos & (aprime_full < 0);
F(debt_pos) = F(debt_pos) * 1e-3 + aprime_full(debt_pos) * 1e4;

% B. Evaluate valid states where c <= 0 (Disfavored solutions)
valid_neg = (valid_mask & ~pos_c) | full_mask;
F(valid_neg) = (c(valid_neg) - 1) * 1e3;

debt_neg = valid_neg & (aprime_full < 0);
F(debt_neg) = F(debt_neg) + aprime_full(debt_neg) * 1e5;

% --- 7. Warm Glow of Bequests ---
if (agej - Jr) >= 10
    networth_prime = aprime + ks .* (1 - ks_out) + dim_guard;
    wg_mask = (valid_mask & (networth_prime > 0)) | full_mask;
    
    warmglow = wg1 * ((1 + networth_prime(wg_mask) / wg2).^(1 - wg3)) ./ (1 - wg3);
    F(wg_mask) = F(wg_mask) + beta * (1 - sj) * warmglow;
end


end
