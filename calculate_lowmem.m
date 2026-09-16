function [lowmemory, elements_per_chunk, total_elements] = calculate_lowmem(n_d, n_a1, n_a2, n_z, n_e, max_elements)
% Default safe limit for 32GB VRAM (approx 1 billion double-precision elements)
if nargin < 6 || isempty(max_elements)
    max_elements = 2.14e9;
end

% Standardize dimensions (minimum 1)
N_d  = max(1, prod(n_d(n_d > 0)));
N_a1 = max(1, prod(n_a1(n_a1 > 0)));
N_a2 = max(1, prod(n_a2(n_a2 > 0)));
N_z  = max(1, prod(n_z(n_z > 0)));
N_e  = max(1, prod(n_e(n_e > 0)));
N_ze = N_z * N_e;

% The core Tensor-Bridge footprint (Choices x States)
total_elements = N_d * (N_a1^2) * N_a2 * N_ze;

% --- LEVEL 0: Slice Nothing ---
if total_elements <= max_elements
    lowmemory = 0;
    elements_per_chunk = total_elements;
    return;
end

% --- LEVEL 1 & 2: Slice Shocks (Z and/or E) ---
if N_ze > 1
    % Try Level 1: Slice the larger shock, keep the other vectorized
    if N_z > 1 && N_e == 1 && (total_elements / N_z) <= max_elements
        lowmemory = 1; elements_per_chunk = total_elements / N_z; return;
    elseif N_e > 1 && N_z == 1 && (total_elements / N_e) <= max_elements
        lowmemory = 1; elements_per_chunk = total_elements / N_e; return;
    elseif N_z > 1 && N_e > 1
        if (total_elements / N_e) <= max_elements % Slice E only
            lowmemory = 1; elements_per_chunk = total_elements / N_e; return;
        end
        % Try Level 2: Slice both Z and E
        if (total_elements / N_ze) <= max_elements
            lowmemory = 2; elements_per_chunk = total_elements / N_ze; return;
        end
    end
end

% --- LEVEL 4 & 5: Slice Experience Asset (a2) ---
if N_a2 > 1
    % Try Level 4: Slice A2, but keep Z/E fully vectorized
    if (total_elements / N_a2) <= max_elements
        lowmemory = 4; elements_per_chunk = total_elements / N_a2; return;
    end

    % Try Level 5: Slice A2 AND (Z and E)
    if (total_elements / (N_a2 * N_ze)) <= max_elements
        lowmemory = 5; elements_per_chunk = total_elements / (N_a2 * N_ze); return;
    end
end

% --- LEVEL 3: The Catastrophic Fallback (Slice Decisions) ---
if N_d > 1
    if (total_elements / (N_a2 * N_ze * N_d)) <= max_elements
        lowmemory = 3; elements_per_chunk = total_elements / (N_a2 * N_ze * N_d); return;
    end
end

% If we reach here, it exceeds VRAM even with max slicing.
warning('Grid exceeds VRAM limits even with Level 5 maximum slicing. Consider decreasing grid density.');
lowmemory = 5;
elements_per_chunk = total_elements / (N_a2 * N_ze);


end