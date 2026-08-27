function ks_prime = QEA_ksprimeFn_single(d, ks, z1, z2, w, agej, Jr, ks_r, ks_employee, ks_employer, kappa_j)

% Create a dimension protector to force implicit expansion
dim_protector = 0*d + 0*ks + 0*z1;

% ks_r is a scalar, leverage BLAS *
ks_growth = ks * ks_r;

if agej < Jr
    % --- Working age ---
    % w and kappa_j are scalars. Group them so they evaluate first,
    % then use .* for the grid matrices (z1 and d).
    ks_income = (w * kappa_j) * (z1 .* d);

    % ks_employee and ks_employer are scalars.
    ks_prime = ks + ks_growth + ks_income * (ks_employee + ks_employer) + dim_protector;

else
    % --- Retirement ---
    % d acts as ks_out
    valid_mask = single(d <= 0.5);
    inf_mask = log(valid_mask);

    ks_prime = (ks + ks_growth) .* (single(1) - d) + inf_mask + dim_protector;
end


end
