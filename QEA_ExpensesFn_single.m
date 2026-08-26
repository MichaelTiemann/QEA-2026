function expenses = QEA_ExpensesFn_single(d, aprime, pvprime, a, pv, ks, z1, z2, w, agej, Jr, r, kappa_j, energy_shock, pv_share_price)

    single_0 = single(0);
    single_1 = single(1);
    single_5 = single(5);

    % Dimension protector mapping the full state and policy spaces
    dim_protector = single_0 .* d .* aprime .* pvprime .* a .* pv .* z1 .* z2;

    housing = single(398);
    utilities = single(80);
    food = single(300);
    transport_fuel = single(150);
    transport_nonfuel = single(252) - transport_fuel;
    w_factor = single_1 / single(2668);

    if agej < Jr
        % --- Working Age ---
        employment_factor = (z1 + single_1) .* 0.5;
        housing = housing * kappa_j;
        discretionary = single(518) * (kappa_j * kappa_j); % Applies kappa_j twice per original logic
        income = (w * kappa_j) * (z1 .* d); % Grouped scalars
        taxes = income * (591 * w_factor);
        expenses = single_0;
    else
        % --- Retirement ---
        employment_factor = single(0.9);
        housing = housing * employment_factor;
        discretionary = single(518) * kappa_j;
        taxes = single_0;
        expenses = z1; % Medical shock acts as baseline expense
    end

    % 1. Penalties & Asset Adjustments (Matrix Masking)
    expenses = expenses - (single_1 + 2 * r) * a .* (a < single_0);
    expenses = expenses - (aprime + a) .* (aprime > a);

    % 2. Core Living & Grid Expenses
    nongrid_expenses = housing + food + (transport_nonfuel + discretionary) .* employment_factor + taxes;
    grid_budget = utilities + transport_fuel .* employment_factor;

    % z2 expands across the matrix; ~energy_shock evaluates instantly as a scalar
    grid_expenses = grid_budget .* (energy_shock .* z2 + single(~energy_shock));

    % 3. PV Subsidy Mask (Zeros out grid_expenses where pv > 5)
    grid_expenses = grid_expenses .* (single_1 - pv ./ single_5) .* (pv <= single_5);

    % 4. Final Aggregation
    total_expenses = nongrid_expenses + grid_expenses;
    pv_investment = (w * pv_share_price) * (pvprime - pv);

    expenses = expenses + total_expenses * w_factor + pv_investment + dim_protector;
end
