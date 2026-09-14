function ks_prime = QEA_ksprimeFn_double(d, ks, z1, z2, w, agej, Jr, ks_r, ks_employee, ks_employer, kappa_j)
% Vectorized KiwiSaver Experience Asset Transition Function

% 'd' acts as hours 'h' before retirement, and withdrawal rate 'ks_out' after.
% Using implicit expansion (.*) ensures compatibility with VFIToolkit ndgrid tensors.

ks_growth = ks .* ks_r;

if agej < Jr
    % ---------------------------------------------------------
    % Working Age: Calculate Contributions
    % ---------------------------------------------------------
    ks_income = w .* kappa_j .* z1 .* d;
    ks_prime = ks + ks_growth + ks_income .* (ks_employee + ks_employer);
    
else
    % ---------------------------------------------------------
    % Retirement: Redeem ks as needed
    % ---------------------------------------------------------
    ks_prime = (ks + ks_growth) .* (1 - d);
    
    % Invalidate states where withdrawal rate exceeds 0.5 (50%)
    invalid_mask = (d > 0.5);
    if any(invalid_mask(:))
        ks_prime(invalid_mask) = -Inf;
    end
end

% ---------------------------------------------------------
% DIMENSIONAL GUARD (Crucial for VFIToolkit generalized tensors)
% ---------------------------------------------------------
% If the mathematical equations above do not explicitly use every state 
% passed in (e.g., z2 is unused here), ks_prime will be missing that dimension.
% We force ks_prime to expand to the full joint mesh size of the inputs:
dimensional_guard = zeros(size(d + ks + z1 + z2), 'like', d);
ks_prime = ks_prime + dimensional_guard;

end
