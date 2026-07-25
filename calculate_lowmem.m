%% Calculate lowmem values
function lowmem = calculate_lowmem(n_d, n_a, n_z, vfoptions)

% First, we have to sort how many of which variables might all stack together in memory
% Then we form a parameter list that reads as follows
% ([d and a without expasset always vectorized],[expassets],[semiz],[z],[e],[u])
% if there's only one of semiz,z,or e, it loops at lowmemory==1
% if there are two of semiz,z,or e, they loop at lowmemory==2
% if all three of semiz,z, and e are present, they loop at lowmemory==3
% if there's an expasset, it can loop at lowmemory==4; it can also loop while looping others at lowmemory==5
% note that n_u shows up for aprime; we can calculate the aprime lowmemory requirements by just treating it like a lone z shock

if exist('vfoptions','var')==0
    vfoptions.dynasty=0;
    vfoptions.experienceasset=0;
    vfoptions.experienceassetu=0;
    vfoptions.experienceassete=0;
    vfoptions.experienceassetz=0;
    vfoptions.experienceassetze=0;
    vfoptions.riskyasset=0;
    vfoptions.residualasset=0;
    vfoptions.n_ambiguity=0;
    vfoptions.n_e=0;
    vfoptions.n_semiz=0;
else
    if ~isfield(vfoptions,'dynasty')
        vfoptions.dynasty=0;
    end
    if ~isfield(vfoptions,'experienceasset')
        vfoptions.experienceasset=0;
    end
    if ~isfield(vfoptions,'experienceassetu')
        vfoptions.experienceassetu=0;
    end
    if ~isfield(vfoptions,'experienceassete')
        vfoptions.experienceassete=0;
    end
    if ~isfield(vfoptions,'experienceassetz')
        vfoptions.experienceassetz=0;
    end
    if ~isfield(vfoptions,'experienceassetze')
        vfoptions.experienceassetze=0;
    end
    if ~isfield(vfoptions,'riskyasset')
        vfoptions.riskyasset=0;
    end
    if ~isfield(vfoptions,'residualasset')
        vfoptions.residualasset=0;
    end
    if ~isfield(vfoptions,'n_ambiguity')
        vfoptions.n_ambiguity=0;
    end
    if ~isfield(vfoptions,'n_e')
        vfoptions.n_e=0;
    end
    if ~isfield(vfoptions,'n_semiz')
        vfoptions.n_semiz=0;
    end
end

%% Deal with Experience Asset if need to do that
% experienceasset: aprime(d,a)
% experienceassetu: aprime(d,a,u)
% experienceassetz: aprime(d,a,z)
% experienceassete: aprime(d,a,e)
% experienceassetze: aprime(d,a,z,e)

if vfoptions.experienceasset>=1 || vfoptions.experienceassetu>=1 || vfoptions.experienceassetz>=1 || vfoptions.experienceassete>=1 || vfoptions.experienceassetze>=1
    % It is simply assumed that the experience asset is the last asset, and that the decision that influences it is the last decision.
    % When using both semiexo and experience asset, the last decision variable influences semi-exo and the second last decision variable influences the experience asset

    if vfoptions.experienceasset>=1
        if ~isfield(vfoptions,'l_dexperienceasset')
            vfoptions.l_dexperienceasset=1; % by default, only one decision variable influences the experienceasset
        end
    elseif vfoptions.experienceassetu>=1
        if ~isfield(vfoptions,'l_dexperienceassetu')
            vfoptions.l_dexperienceassetu=1; % by default, only one decision variable influences the experienceassetu
        end
    elseif vfoptions.experienceassete>=1
        if ~isfield(vfoptions,'l_dexperienceassete')
            vfoptions.l_dexperienceassete=1; % by default, only one decision variable influences the experienceassete
        end
    elseif vfoptions.experienceassetz>=1
        if ~isfield(vfoptions,'l_dexperienceassetz')
            vfoptions.l_dexperienceassetz=1; % by default, only one decision variable influences the experienceassetz
        end
    elseif vfoptions.experienceassetze>=1
        if ~isfield(vfoptions,'l_dexperienceassetze')
            vfoptions.l_dexperienceassetze=1; % by default, only one decision variable influences the experienceassetze
        end
    end
    
    if vfoptions.experienceasset>=1
        vfoptions.l_d2=vfoptions.l_dexperienceasset;
        vfoptions.l_a2=vfoptions.experienceasset;
    elseif vfoptions.experienceassetu>=1
        vfoptions.l_d2=vfoptions.l_dexperienceassetu;
        vfoptions.l_a2=vfoptions.experienceassetu;
    elseif vfoptions.experienceassete>=1
        vfoptions.l_d2=vfoptions.l_dexperienceassete;
        vfoptions.l_a2=vfoptions.experienceassete;
    elseif vfoptions.experienceassetz>=1
        vfoptions.l_d2=vfoptions.l_dexperienceassetz;
        vfoptions.l_a2=vfoptions.experienceassetz;
    elseif vfoptions.experienceassetze>=1
        vfoptions.l_d2=vfoptions.l_dexperienceassetze;
        vfoptions.l_a2=vfoptions.experienceassetze;
    end

    if prod(vfoptions.n_semiz)>0
        if ~isfield(vfoptions,'l_dsemiz')
            vfoptions.l_dsemiz=1; % by default, only one decision variable influences the semi-exogenous state
        end

        % Split decision variables (other, semiexo, experienceasset)
        if length(n_d)>(vfoptions.l_d2+vfoptions.l_dsemiz)
            n_d1=n_d(1:end-vfoptions.l_d2-vfoptions.l_dsemiz);
        else
            n_d1=0;
        end
        n_d2=n_d(end-vfoptions.l_d2-vfoptions.l_dsemiz+1:end-vfoptions.l_dsemiz); % n_d2 is the decision variable that influences the experience asset
        n_d3=n_d(end-vfoptions.l_dsemiz+1:end); % n_d3 is the decision variable that influences the transition probabilities of the semi-exogenous state

        % Split endogenous assets into the standard ones and the experience asset
        if length(n_a)<=vfoptions.l_a2
            n_a1=0;
        else
            n_a1=n_a(1:end-vfoptions.l_a2);
        end
        n_a2=n_a(end-vfoptions.l_a2+1:end); % last l_a2 (=vfoptions.experienceasset) dims are the experience asset

    else % no semiz
        % Split decision variables into the standard ones and the one relevant to the experience asset
        if length(n_d)>vfoptions.l_d2
            n_d1=n_d(1:end-vfoptions.l_d2);
        else
            n_d1=0;
        end
        n_d2=n_d(end-vfoptions.l_d2+1:end); % n_d2 is the decision variable that influences next period vale of the experience asset

        % Split endogenous assets into the standard ones and the experience asset
        if length(n_a)<=vfoptions.l_a2
            n_a1=0;
        else
            n_a1=n_a(1:end-vfoptions.l_a2);
        end
        n_a2=n_a(end-vfoptions.l_a2+1:end); % last l_a2 (=vfoptions.experienceasset) dims are the experience asset
    end

    lowmem_aprimefn=nan;
    if vfoptions.experienceasset>=1
        lowmem_aprimefn=calculate_lowmem_aprime_raw(n_d2, n_a2);
    elseif vfoptions.experienceassetu>=1
        lowmem_aprimefn=calculate_lowmem_aprime_raw(n_d2, n_a2, [], [], vfoptions.n_u);
    elseif vfoptions.experienceassete>=1
        lowmem_aprimefn=calculate_lowmem_aprime_raw(n_d2, n_a2, [], vfoptions.n_e);
    elseif vfoptions.experienceassetz>=1
        lowmem_aprimefn=calculate_lowmem_aprime_raw(n_d2, n_a2, n_z);
    elseif vfoptions.experienceassetze>=1
        lowmem_aprimefn=calculate_lowmem_aprime_raw(n_d2, n_a2, n_z, vfoptions.n_e);
    end
    if isnan(lowmem_aprimefn)
        assert(false);
    else
        lowmem_returnfn=calculate_lowmem_raw([n_d1,n_d2],n_a1,n_a2,vfoptions.n_semiz,n_z,vfoptions.n_e);
    end
    lowmem=max(lowmem_aprimefn,lowmem_returnfn);
elseif vfoptions.riskyasset>=1
    l_d=length(n_d); % because it is a risky asset there must be some decision variables
    if isfield(vfoptions,'refine_d')
        l_d=l_d-vfoptions.refine_d(1);
        if length(vfoptions.refine_d)==4 % only relevant if using semiz
            l_d=l_d-vfoptions.refine_d(4);
        end
    else
        warning('Using vfoptions.riskyasset=1 without setting vfoptions.refine_d is outdated behaviour, it is strongly recommended you set vfoptions.refine_d')
        vfoptions.refine_d=zeros(1,4);
    end
    %% Setup refine
    if length(n_a2)>1
        error('Have not yet implemented riskyasset for more than one riskyasset')
    end
    if sum(vfoptions.refine_d)~=length(n_d)
        error('vfoptions.refine_d seems to be set up wrong, it is inconsistent with n_d')
    end
    if any(vfoptions.refine_d(2:3)==0)
        error('vfoptions.refine_d cannot contain zeros for d2 or d3 (you can do no d1, but you cannot do no d2 nor no d3)')
    end
    
    if vfoptions.refine_d(1)>0
        n_d1=n_d(1:vfoptions.refine_d(1));
    else
        n_d1=0;
    end
    if vfoptions.refine_d(2)>0
        n_d2=n_d(vfoptions.refine_d(1)+1:vfoptions.refine_d(1)+vfoptions.refine_d(2));
    else
        n_d2=0;
    end
    if vfoptions.refine_d(3)>0
        n_d3=n_d(vfoptions.refine_d(1)+vfoptions.refine_d(2)+1:vfoptions.refine_d(1)+vfoptions.refine_d(2)+vfoptions.refine_d(3));
    else
        n_d3=0;
    end
    if vfoptions.refine_d(4)>0
        n_d4=n_d(vfoptions.refine_d(1)+vfoptions.refine_d(2)+vfoptions.refine_d(3)+1:end);
    else
        n_d4=0;
    end
    lowmem_aprimefn=calculate_lowmem_aprime_raw([n_d2,n_d3,n_a1],n_a2,vfoptions.n_u);
    lowmem_returnfn=calculate_lowmem_raw([n_d1,n_d3,n_d4],n_a1,n_a2,n_z,vfoptions.n_semiz,vfoptions.n_e);
    lowmem=max(lowmem_aprimefn,lowmem_returnfn);
elseif vfoptions.residualasset
    if isscalar(n_a)
        n_a1=0;
    else
        n_a1=n_a(1:end-1);
    end
    n_r=n_a(end); % n_a2 is the residual asset
    rprimefn_lowmem=calculate_lowmem_aprimefn_raw([n_d,n_a1],n_r,[],n_z,vfoptions.n_e);
    lowmem_returnfn=calculate_lowmem_raw(n_d,n_a1,n_r,[],[n_z,vfoptions.n_e]);
    lowmem=max(rprimefn_lowmem,lowmem_returnfn);
elseif isfield(vfoptions,'StateDependentVariables_z')==1 || vfoptions.dynasty==1
    lowmem=calculate_lowmem_raw(n_d,n_a,[],[],n_z,[]);
elseif prod(vfoptions.n_semiz)>0
    if length(n_d)>vfoptions.l_dsemiz
        n_d1=n_d(1:end-vfoptions.l_dsemiz);
    else
        n_d1=0;
    end
    n_d2=n_d(end-vfoptions.l_dsemiz+1:end); % n_d2 is the decision variable that influences the transition probabilities of the semi-exogenous state

    lowmem=calculate_lowmem_raw(n_d, n_a, [], vfoptions.n_semiz,n_z,vfoptions.n_e);
else
    lowmem=calculate_lowmem_raw(n_d, n_a, [], [], n_z, vfoptions.n_e);
end


end




%% Calculate lowmem values for simple grids
function lowmem = calculate_lowmem_raw(n_d, n_a1, n_a2, n_semiz, n_z, n_e)

if n_d==0
    n_d=1;
end
N_d=prod(n_d(n_d~=0));
if n_a1==0
    n_a1=1;
end
N_a1=prod(n_a1(n_a1~=0));
if n_a2==0
    n_a2=1;
end
N_a2=prod(n_a2(n_a2~=0));
N_semiz=prod(~isempty(n_semiz)*n_semiz);
N_z=prod(~isempty(n_z)*n_z);
N_e=prod(~isempty(n_e)*n_e);
n_semizze=[N_semiz; N_z; N_e];
n_semizze=n_semizze(n_semizze~=0);

numel_lowmem5=N_d*N_a1*N_a1;
if numel_lowmem5 < 2^31
    numel_lowmem4=numel_lowmem5*N_a2;
    if numel_lowmem4 < 2^31
        numel_lowmem3=numel_lowmem4*prod(n_semizze);
        if numel_lowmem3 < 2^31
            lowmem=0; % we can vectorize everything
        else
            switch length(n_semizze)
                case 1
                    lowmem=1;
                case 2
                    if N_e
                        if numel_lowmem4*max(N_semiz,N_z) < 2^31
                            lowmem=1;
                        else
                            lowmem=2;
                        end
                    elseif numel_lowmem4*N_semiz < 2^31
                        lowmem=1;
                    else
                        lowmem=2;
                    end
                case 3
                    if numel_lowmem4*N_semiz*N_z < 2^31
                        lowmem=1;
                    elseif numel_lowmem4*N_semiz < 2^31
                        lowmem=2;
                    else
                        lowmem=3;
                    end
                otherwise
                    assert(false);
            end
        end
    elseif numel_lowmem5*prod(n_semizze) < 2^31
        lowmem=4;
    else
        lowmem=5;
    end
    fprintf("lowmem = %d \n", lowmem)
else
    error("Model size exceeds GPU maximum variable size");
end

end




%% Calculate lowmem values for simple grids
function lowmem = calculate_lowmem_aprime_raw(n_d2, n_a2, n_z, n_e, n_u)

N_d2=prod(n_d2);
N_a2=prod(n_a2);
if exist('n_z','var')
    N_z=prod(n_z);
else
    N_z=0;
end
if exist('n_e','var')
    N_e=prod(n_e);
else
    N_e=0;
end
if exist('n_u','var')
    N_u=prod(n_u);
else
    N_u=0;
end

numel_lowmem3=N_d2*N_a2;
if numel_lowmem3 < 2^31
    if N_u
        if numel_lowmem3*N_u < 2^31
            lowmem=0;
        else
            lowmem=1;
        end
    elseif N_z
        if N_e
            if numel_lowmem3*N_z*N_e < 2^31
                lowmem=0;
            elseif numel_lowmem3*N_z < 2^31
                lowmem=1;
            else
                lowmem=2;
            end
        elseif numel_lowmem3*N_z < 2^31
            lowmem=0;
        else
            lowmem=1;
        end
    elseif N_e
        if numel_lowmem3*N_e < 2^31
            lowmem=0;
        else
            lowmem=1;
        end
    else
        lowmem=0
    end
    fprintf("aprime lowmem = %d \n", lowmem)
else
    error("Model size exceeds GPU maximum variable size for aprime");
end

end




%% Ptype interface
function lowmem = calculate_lowmem_PType(n_d, n_a, n_z, vfoptions)

    if isstruct(n_d)
        lowmem=struct();
        for iistr=fieldnames(n_d)
            if isfield (vfoptions, 'n_e')
                n_e=vfoptions.n_e.(iistr);
            else
                n_e=[];
            end
            lowmem.(iistr)=calculate_lowmem(n_d.(iistr), n_a.(iistr), n_z.(iistr), vfoptions.(iistr));
        end
    else
        error("lowmem PType requires struct arguments");
    end

end
