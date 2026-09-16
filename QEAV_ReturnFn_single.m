function F = QEAV_ReturnFn_single(d, aprime, pvprime, a, pv, ks, z1, z2, w, sigma, psi, eta, agej, Jr, pension, r, ks_employee, kappa_j, wg1, wg2, wg3, beta, sj, energy_shock, pv_share_price)

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

% Idioms for clean equations and strict PTX compliance
single_0 = single(0);
single_1 = single(1);

% Base constants
housing_base = single(398);
utilities = single(80);
food_fuel = single(75);
food_nonfuel = single(225);
transport_fuel = single(150);
transport_nonfuel = single(252) - transport_fuel;
discretionary_base = single(518);
w_factor = single_1 / single(2668);

% --- 1. Age-Dependent Income and Base Constraints ---
if agej < Jr
    % Working Age Constraints
    if (aprime < single_0) && (pvprime > pv)
        f_val = single(-Inf);
        return;
    end
    housing = housing_base * kappa_j;
    discretionary = discretionary_base * kappa_j;
    employment_factor = (z1 + single_1) * single(0.5);
    income = w * kappa_j * z1 * d;
    taxes = income * single(591) * w_factor;
    c = income * (single_1 - ks_employee);
    h = d;
    ks_out = single_0;
else
    % Retirement Constraints
    if d > single(0.2)
        f_val = single(-Inf);
        return;
    end
    if z1 ~= single_0
        h = single_1;
    else
        h = single_0;
    end
    employment_factor = single(0.9);
    housing = housing_base * single(0.9);
    discretionary = discretionary_base;
    ks_out = d;
    c = pension + ks_out * ks - z1;
    taxes = single_0;
end

% --- 2. Asset Returns & Debt Costs ---
if a >= single_0
    c = c + (single_1 + r) * a - aprime;
elseif (agej == Jr) && (aprime == single_0)
    c = c + single_1; % Jubilee
else
    c = c + (single_1 + single(2)*r) * a - aprime;
end

% --- 3. Core Living Expenses ---
nongrid_expenses = housing + food_nonfuel + (transport_nonfuel + discretionary) * employment_factor + taxes;
grid_budget = utilities + food_fuel + transport_fuel * employment_factor;

if energy_shock == single_0
    grid_expenses = grid_budget;
else
    grid_expenses = grid_budget * energy_shock * z2;
end

if pv > single(5)
    grid_income = grid_budget * max(single_1, energy_shock * z2) * (pv - single(5)) / single(10);
    grid_expenses = single_0;
else
    grid_income = single_0;
    grid_expenses = grid_expenses * (single_1 - pv / single(5));
end

total_expenses = nongrid_expenses + grid_expenses;
pv_investment = w * (pvprime - pv) * pv_share_price;
c = c + (grid_income - total_expenses) * w_factor - pv_investment;

% --- 4. Illegal Moves (Aggressive -Inf) ---
if aprime < single_0
    if c + aprime > single_0 % No new debt for extra consumption
        f_val = single(-Inf);
        return;
    elseif agej < Jr && h < single(0.6) % No debt if not trying to hustle
        f_val = single(-Inf);
        return;
    end
end

% Close the Welfare Fraud Loophole ---
if (c <= single_0) && (aprime > single_0 || pvprime > pv)
    % You cannot claim welfare/bankruptcy while voluntarily increasing your savings or buying solar panels!
    f_val = single(-Inf);
    return;
end

% --- 5. Final Utility & The Social Safety Net ---
if c > single_0
    % Normal Economy
    if agej >= Jr
        if aprime < single_0
            h = single_0;
        else
            h = c * single(0.5); % Pretend leisure
        end
    end

    u_val = (c^(single_1 - sigma)) / (single_1 - sigma) - psi * (h^(single_1 + eta)) / (single_1 + eta);

    if aprime < single_0
        u_val = u_val * single(1e-3) + aprime * single(1e4); % Disfavor debt usage
    end
else
    % The Bankruptcy Zone: Apply the workfare consumption floor
    c_min_base = single(0.05); % Baseline survival consumption

    if agej < Jr
        % Working Age: Mimic OLG-Electrify work-contingent benefit
        c_welfare = c_min_base + single(0.1) * h;
    else
        % Retirement: Flat survival pension
        c_welfare = c_min_base;
    end

    % Standard utility of welfare consumption, minus labor disutility, minus stigma
    u_val = (c_welfare^(single_1 - sigma)) / (single_1 - sigma) - psi * (h^(single_1 + eta)) / (single_1 + eta) - single(50);

    if aprime < single_0
        u_val = u_val + aprime * single(1e5); % Heavily penalize trying to borrow while on welfare
    end
end

% --- 6. Warm Glow ---
networth_prime = aprime + ks * (single_1 - ks_out);
if agej - Jr >= single(10) && networth_prime > single_0
    warmglow = wg1 * ((single_1 + networth_prime / wg2)^(single_1 - wg3)) / (single_1 - wg3);
    warmglow = beta * (single_1 - sj) * warmglow;
    u_val = u_val + warmglow;
end

f_val = u_val;


end