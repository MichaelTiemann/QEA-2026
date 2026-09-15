function F = QEAV_ReturnFn_double(d, aprime, pvprime, a, pv, ks, z1, z2, w, sigma, psi, eta, agej, Jr, pension, r, ks_employee, kappa_j, wg1, wg2, wg3, beta, sj, energy_shock, pv_share_price)
% 1. Create the Universal Dimensional Guard
% arrayfun requires all non-scalar inputs to be exactly the same size.
% We create one master guard to explicitly expand the singletons.
dim_guard = zeros(size(aprime + pvprime + a + pv + ks + z1 + z2), 'like', aprime);

% 2. Explicitly broadcast inputs to the master size
aprime_f  = aprime + dim_guard;
pvprime_f = pvprime + dim_guard;
a_f       = a + dim_guard;
pv_f      = pv + dim_guard;
ks_f      = ks + dim_guard;
z1_f      = z1 + dim_guard;
z2_f      = z2 + dim_guard;

% 3. Execute the Fused Custom CUDA Kernel
% (Note: d and all parameters are passed as scalars, which arrayfun handles natively)
F = arrayfun(@CoreMath, d, aprime_f, pvprime_f, a_f, pv_f, ks_f, z1_f, z2_f, ...
    w, sigma, psi, eta, agej, Jr, pension, r, ks_employee, kappa_j, ...
    wg1, wg2, wg3, beta, sj, energy_shock, pv_share_price);
end

% =========================================================================
% THE FUSED GPU KERNEL
% Because this is compiled to CUDA by arrayfun, it must contain ONLY scalar
% operations. It runs independently on every single node of the 5D state space!
% =========================================================================
function f_val = CoreMath(d, aprime, pvprime, a, pv, ks, z1, z2, w, sigma, psi, eta, agej, Jr, pension, r, ks_employee, kappa_j, wg1, wg2, wg3, beta, sj, energy_shock, pv_share_price)
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
    % Working Age Constraints
    if (aprime < 0) && (pvprime > pv)
        f_val = -Inf;
        return;
    end

    housing = housing_base * kappa_j;
    discretionary = discretionary_base * kappa_j;
    employment_factor = (z1 + 1) * 0.5;

    income = w * kappa_j * z1 * d;
    taxes = income * 591 * w_factor;
    c = income * (1 - ks_employee);

    h = d;
    ks_out = 0;
else
    % Retirement Constraints
    if d > 0.2
        f_val = -Inf;
        return;
    end

    if z1 ~= 0
        h = 1;
    else
        h = 0;
    end

    employment_factor = 0.9;
    housing = housing_base * 0.9;
    discretionary = discretionary_base;

    ks_out = d;
    c = pension + ks_out * ks - z1;
    taxes = 0;
end

% --- 2. Asset Returns & Debt Costs ---
if a >= 0
    c = c + (1 + r) * a - aprime;
elseif (agej == Jr) && (aprime == 0)
    c = c + 1; % Jubilee
else
    c = c + (1 + 2*r) * a - aprime;
end

% --- 3. Core Living Expenses ---
nongrid_expenses = housing + food_nonfuel + (transport_nonfuel + discretionary) * employment_factor + taxes;
grid_budget = utilities + food_fuel + transport_fuel * employment_factor;

if energy_shock == 0
    grid_expenses = grid_budget;
else
    grid_expenses = grid_budget * energy_shock * z2;
end

if pv > 5
    grid_income = grid_budget * max(1, energy_shock * z2) * (pv - 5) / 10;
    grid_expenses = 0;
else
    grid_income = 0;
    grid_expenses = grid_expenses * (1 - pv / 5);
end

total_expenses = nongrid_expenses + grid_expenses;
pv_investment = w * (pvprime - pv) * pv_share_price;
c = c + (grid_income - total_expenses) * w_factor - pv_investment;

% --- 4. Illegal Moves (Aggressive -Inf) ---
if aprime < 0
    if c + aprime > 0 % No new debt for extra consumption
        f_val = -Inf;
        return;
    elseif agej < Jr && h < 0.6 % No debt if not trying to hustle
        f_val = -Inf;
        return;
    end
end
% Close the Welfare Fraud Loophole ---
if (c <= 0) && (aprime > 0 || pvprime > pv)
    % You cannot claim welfare/bankruptcy while voluntarily increasing your savings or buying solar panels!
    f_val = -Inf;
    return;
end

% --- 5. Final Utility & The Social Safety Net ---
if c > 0
    % Normal Economy
    if agej >= Jr
        if aprime < 0
            h = 0;
        else
            h = c * 0.5; % Pretend leisure
        end
    end

    u_val = (c^(1 - sigma)) / (1 - sigma) - psi * (h^(1 + eta)) / (1 + eta);

    if aprime < 0
        u_val = u_val * 1e-3 + aprime * 1e4; % Disfavor debt usage
    end
else
    % The Bankruptcy Zone: Apply the workfare consumption floor
    c_min_base = 0.05; % Baseline survival consumption

    if agej < Jr
        % Working Age: Mimic OLG-Electrify work-contingent benefit
        c_welfare = c_min_base + 0.1 * h;
    else
        % Retirement: Flat survival pension
        c_welfare = c_min_base;
    end

    % Standard utility of welfare consumption, minus labor disutility, minus stigma
    u_val = (c_welfare^(1 - sigma)) / (1 - sigma) - psi * (h^(1 + eta)) / (1 + eta) - 50;

    if aprime < 0
        u_val = u_val + aprime * 1e5; % Heavily penalize trying to borrow while on welfare
    end
end

% --- 6. Warm Glow ---
networth_prime = aprime + ks * (1 - ks_out);
if agej - Jr >= 10 && networth_prime > 0
    warmglow = wg1 * ((1 + networth_prime / wg2)^(1 - wg3)) / (1 - wg3);
    warmglow = beta * (1 - sj) * warmglow;
    u_val = u_val + warmglow;
end

f_val = u_val;
end