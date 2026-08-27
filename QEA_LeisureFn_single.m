function leisure = QEA_LeisureFn_single(d, aprime, pvprime, a, pv, ks, z1, z2, w, agej, Jr, pension, r, kappa_j, ks_employee, wg1, wg2, wg3, beta, sj, energy_shock, pv_share_price)

single_0 = single(0);
single_1 = single(1);

% Dimension protector to enforce implicit expansion across state variables
dim_protector = 0*d + 0*aprime + 0*a + 0*z1;

discretionary = single(518);
w_factor = single(1/2668);

if agej < Jr
    % --- Working Age ---
    discretionary = discretionary * kappa_j;
    employment_factor = (z1 + single_1) * 0.5;

    % Grouping scalars (w * kappa_j * 2) allows BLAS evaluation before matrix expansion
    leisure = (w * kappa_j * 2) * ((single_1 - d) .* z1);

else
    % --- Retirement ---
    employment_factor = single(0.9);

    % Evaluate Income & Expenses (assuming these are now fully vectorized)
    income = QEA_IncomeFn_single(d, aprime, pvprime, a, pv, ks, z1, z2, w, agej, Jr, pension, r, kappa_j, ks_employee, energy_shock);
    expenses = QEA_ExpensesFn_single(d, aprime, pvprime, a, pv, ks, z1, z2, w, agej, Jr, r, kappa_j, energy_shock, pv_share_price);

    % Sickness & Solvency Mask:
    % Replaces nested scalar `if aprime >= 0 && z1 == 0` and `if income > expenses`
    % max() evaluates the budget constraint instantly across the grid.
    healthy_and_solvent_mask = (aprime >= single_0) & (z1 == single_0);
    net_income = max(single_0, income - expenses);

    leisure = 0.5 * net_income .* healthy_and_solvent_mask;
end

% Apply base discretionary leisure
leisure = leisure + (discretionary * w_factor) .* employment_factor;

% --- Warm Glow of Bequests ---
% Evaluated purely as a scalar block condition since it only applies universally by age
if (agej - Jr) >= 10
    networth_prime = aprime + ks .* (single_1 - d);

    % Mask applies the `if networth_prime > single_0` logic over the multi-dimensional grid
    valid_nw_mask = (networth_prime > single_0);

    % Element-wise exponentiation and multiplication
    warmglow = wg1 + wg1 .* ((single_1 + networth_prime ./ wg2).^(single_1 - wg3)) ./ (single_1 - wg3);
    warmglow = (beta * (single_1 - sj)) .* warmglow; % Grouped scalars

    leisure = leisure + warmglow .* valid_nw_mask;
end

% Enforce final state space geometry
leisure = leisure + dim_protector;


end
