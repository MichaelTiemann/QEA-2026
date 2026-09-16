function [lowmemory, elements_per_chunk, total_elements] = calculate_lowmem(n_d, n_a, n_z, vfoptions, max_elements)
% 1. Respect MATLAB's 2^31 indexing limit as absolute hard cap
if nargin < 5 || isempty(max_elements)
    max_elements = 2^31;
end

if nargin < 4 || isempty(vfoptions)
    vfoptions = struct();
end

% Check core exotic flags
exp_fields = {'experienceasset', 'experienceassetu', 'experienceassete', 'experienceassetz', 'experienceassetze', 'experienceassetsemiz'};
l_a2 = 0;
for i = 1:length(exp_fields)
    if isfield(vfoptions, exp_fields{i}) && vfoptions.(exp_fields{i}) > 0
        l_a2 = vfoptions.(exp_fields{i});
        break;
    end
end

% 3. Standardize dimensions
N_d  = max(1, prod(n_d(n_d > 0)));

if l_a2 > 0 && length(n_a) > l_a2
    n_a1 = n_a(1:end-l_a2);
    n_a2 = n_a(end-l_a2+1:end);
else
    n_a1 = n_a;
    n_a2 = [];
end

N_a1 = max(1, prod(n_a1(n_a1 > 0)));
N_a2 = max(1, prod(n_a2(n_a2 > 0)));
N_z  = max(1, prod(n_z(n_z > 0)));

n_e = []; if isfield(vfoptions, 'n_e'); n_e = vfoptions.n_e; end
N_e  = max(1, prod(n_e(n_e > 0)));

n_semiz = []; if isfield(vfoptions, 'n_semiz'); n_semiz = vfoptions.n_semiz; end
N_semiz = max(1, prod(n_semiz(n_semiz > 0)));

N_ze = N_z * N_e * N_semiz;

% 4. Core Tensor-Bridge Footprint & Memory Calculations
total_elements = N_d * (N_a1^2) * N_a2 * N_ze;

bytes_per_element = 8; % double precision (64-bit)
tensor_multiplier = 7; % Active working tensors in VRAM (F_tensor, RHS, guards, etc.)

% Define safe hardware ceilings
max_index_limit = 2^31; % MATLAB hard index limit
max_vram_bytes = 28 * (1024^3); % 28GB working ceiling on the 32GB RTX 5090 (allows pipelining room)

% Maximum allowed elements per chunk based on memory bytes and index caps
max_elements_by_vram = max_vram_bytes / (bytes_per_element * tensor_multiplier);
max_allowed_elements = min(max_index_limit, max_elements_by_vram);

% --- LEVEL 0: Slice Nothing ---
if total_elements <= max_allowed_elements
    lowmemory = 0;
    elements_per_chunk = total_elements;
    return;
end

% --- LEVEL 1 & 2: Slice Shocks (Z, E, SemiZ) ---
if N_ze > 1
    if N_semiz > 1 && (total_elements / N_semiz) <= max_allowed_elements
        lowmemory = 1; elements_per_chunk = total_elements / N_semiz; return;
    elseif N_z > 1 && (total_elements / N_z) <= max_allowed_elements
        lowmemory = 1; elements_per_chunk = total_elements / N_z; return;
    elseif N_e > 1 && (total_elements / N_e) <= max_allowed_elements
        lowmemory = 1; elements_per_chunk = total_elements / N_e; return;
    elseif (total_elements / N_ze) <= max_allowed_elements
        lowmemory = 2; elements_per_chunk = total_elements / N_ze; return;
    end
end

% --- LEVEL 4 & 5: Slice Experience Asset (a2) ---
if N_a2 > 1
    % Level 4: Slices a2 (divides total elements by N_a2 so each chunk fits in VRAM)
    if (total_elements / N_a2) <= max_allowed_elements
        lowmemory = 4; elements_per_chunk = total_elements / N_a2; return;
    end
    % Level 5: Slices a2 AND shocks
    if (total_elements / (N_a2 * N_ze)) <= max_allowed_elements
        lowmemory = 5; elements_per_chunk = total_elements / (N_a2 * N_ze); return;
    end
end

% --- LEVEL 3: Catastrophic Fallback (Slice Decisions) ---
if N_d > 1
    if (total_elements / (N_a2 * N_ze * N_d)) <= max_allowed_elements
        lowmemory = 3; elements_per_chunk = total_elements / (N_a2 * N_ze * N_d); return;
    end
end

% Hard limit fallback
warning('Grid exceeds VRAM pipelining limits even with Level 5 maximum slicing.');
lowmemory = 5;
elements_per_chunk = total_elements / (N_a2 * N_ze);


end