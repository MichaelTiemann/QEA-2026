%% QEA-2026: Unemployment, Medical, and Energy Shocks

%% Adapted from Life-Cycle Model 21: Idiosyncratic medical shocks in retirement
% Various ExogShockFn are used to make both the grid and transition probabilities depend on age.

% Note: Both the z1_grid_J and the ExogShockFn approaches require that the
% number of grid points in z1_grid does NOT change with age.

%% How does VFI Toolkit think about this?
%
% One dual-use decision variable:
%     h, labour hours worked;
%     ks_out, fraction of retirement savings to liquidate
% Three endogenous state variables:
%     a, assets (total household savings/debt);
%     pv, shares of PV+Battery assets (offset electricity costs, generate grid income at 50% of cost)
%     ks, Kiwisaver retirement account (modeled as experience asset)
% Two stochastic exogenous state variables:
%     z1, dual-purpose ('unemployment' shock in working age, medical shock in retirement)
%     z2, AR(1) energy price shock
% Age: j

%% Begin setting up to use VFI Toolkit to solve
% Lets model agents from age 20 to age 100, so 81 periods

Params.agejshifter=29; % Age 20 minus one. Makes keeping track of actual age easy in terms of model age
Params.J=80-Params.agejshifter; % =81, Number of period in life-cycle

% Grid sizes to use
n_d=41; % Endogenous labour choice (fraction of time worked); and kiwisaver redemption percentage
% ks=73 good for 2x ks_max, a_max @ 4 (but use 10 for employment shocks)
% ks=61 good for 3x ks_max, a_max @ 6
% ks=61 good for 3x ks_max, a_max @ 6
% ks=53 good for 6x ks_max, a_max @ 16
% ks=43 good for 16x ks_max, a_max @ 64
% ks=37 good for 32x ks_max, a_max @ 96
% ks=31 good for 64x ks_max, a_max @ 192
% ks=23 ok+ for 512x ks_max, a_max @ 1024
% ks=17 ok- for 2048x ks_max, a_max @ 2560
% ks=13 marginal for 4096x ks_max, a_max @ 4096
a_multiplier=16;
ks_multiplier=32;
n_a=[67,5,37]; % Endogenous asset holdings: assets, pv, kiwisaver; 83 is a good minimum for accurate asset tracking
n_z=[2,5]; % Exogenous labor productivity units shock; energy price shocks
N_j=Params.J; % Number of periods in finite horizon
vfoptions=struct();
vfoptions.lowmemory=0;
Params.Q_min=1;
Params.Q_max=20;

%% Parameters

% Discount rate
Params.beta = 0.96;
% Preferences
Params.sigma = 2.5; % Coeff of relative risk aversion (curvature of consumption); larger=>more precautionary
Params.eta = 0.5; % Curvature of leisure (This will end up being 1/Frisch elasticity); larger=>less leisure
Params.psi = 10; % Weight on leisure; larger=>more leisure

% Prices
Params.w=1; % Wage
Params.r=0.04071; % Interest rate (0.05 is 5%)
% Note that this include direct costs (utilities, transport fuel) as well as indirect (energy fraction costs of goods and services consumed)
Params.energy_shock_magnitude=2; % If 1, shock returns to mean; if > 1, shock increases price by (energy_shock-1)
% Median Kiwi income is roughly $120K/hh, so $20K 5kW system with 10kWh battery is 1/6th income.
% One fifth share of that (1kW+2kWh) is 1/30th income.
Params.pv_share_price=1/30;

% KiwiSaver Scheme
Params.ks_r=0.07; % Long-term growth estimate
Params.ks_employee=0.035; % Employee contribution
Params.ks_employer=0.035; % Employer contribution

% Demographics
Params.agej=1:1:Params.J; % Is a vector of all the agej: 1,2,3,...,J
Params.Jr=65-Params.agejshifter;

% Pensions & Helpers for shock/retirement regimes
shock_titles={"No Shocks", "Unemployment and Medical", "Energy Only", "All Shocks"};
% shock_titles={"No Shocks", "Energy Only", "Unemployment and Medical"};
shock_titles={"Energy Only"};

ks_legends={"5% emp only", "3.5% + 3.5%"};
ks_legends={"5% emp only (linear grid)"};
% ks_legends={"3.5% + 3.5%"};

ks_regime_contributions=[[0.05,0]; [0.035, 0.035]];
ks_regime_contributions=[[0.05,0.0]];
% ks_regime_contributions=[[0.035, 0.035]];

ExocShockFn_vec={@LifeCycleModel21_ExogShockFn3,@LifeCycleModel21_ExogShockFn,@LifeCycleModel21_ExogShockFn3,@LifeCycleModel21_ExogShockFn};
ExocShockFn_vec={@LifeCycleModel21_ExogShockFn3};

energy_shock_factor=[0,0,1,1];
energy_shock_factor=[1];

pension_schemes=[0.0, 0.15];
pension_schemes=0.15;

pv_regimes=1:n_a(2);
pv_regimes=[1,n_a(2)];

% Age-dependent labor productivity units
Params.kappa_j=[linspace(0.5,2,Params.Jr-15),linspace(2,1,14),zeros(1,Params.J-Params.Jr+1)];
Params.kappa_j=Params.kappa_j(1:N_j);

% Conditional survival probabilities: sj is the probability of surviving to be age j+1, given alive at age j
% Most countries have calculations of these (as they are used by the government departments that oversee pensions)
% In fact I will here get data on the conditional death probabilities, and then survival is just 1-death.
% Here I just use them for the US, taken from "National Vital Statistics Report, volume 58, number 10, March 2010."
% I took them from first column (qx) of Table 1 (Total Population)
% Conditional death probabilities
Params.dj=[0.006879, 0.000463, 0.000307, 0.000220, 0.000184, 0.000172, 0.000160, 0.000149, 0.000133, 0.000114, 0.000100, 0.000105, 0.000143, 0.000221, 0.000329, 0.000449, 0.000563, 0.000667, 0.000753, 0.000823,...
    0.000894, 0.000962, 0.001005, 0.001016, 0.001003, 0.000983, 0.000967, 0.000960, 0.000970, 0.000994, 0.001027, 0.001065, 0.001115, 0.001154, 0.001209, 0.001271, 0.001351, 0.001460, 0.001603, 0.001769, 0.001943, 0.002120, 0.002311, 0.002520, 0.002747, 0.002989, 0.003242, 0.003512, 0.003803, 0.004118, 0.004464, 0.004837, 0.005217, 0.005591, 0.005963, 0.006346, 0.006768, 0.007261, 0.007866, 0.008596, 0.009473, 0.010450, 0.011456, 0.012407, 0.013320, 0.014299, 0.015323,...
    0.016558, 0.018029, 0.019723, 0.021607, 0.023723, 0.026143, 0.028892, 0.031988, 0.035476, 0.039238, 0.043382, 0.047941, 0.052953, 0.058457, 0.064494,...
    0.071107, 0.078342, 0.086244, 0.094861, 0.104242, 0.114432, 0.125479, 0.137427, 0.150317, 0.164187, 0.179066, 0.194979, 0.211941, 0.229957, 0.249020, 0.269112, 0.290198, 0.312231, 1.000000];
% dj covers Ages 0 to 100
Params.sj=1-Params.dj((1:N_j)+Params.agejshifter); % Conditional survival probabilities
Params.sj(end)=0; % In the present model the last period (j=J) value of sj is actually irrelevant

% Warm glow of bequest
Params.wg1=0.3; % (relative) importance of bequests
Params.wg2=3; % degree to which bequests are a luxury good (>=1; =1 would be a normal good)
Params.wg3=Params.sigma; % By using the same curvature as the utility of consumption it makes it much easier to guess appropriate parameter values for the warm glow

% Start with a mass of one at initial age, use the conditional survival
% probabilities sj to calculate the mass of those who survive to next
% period, repeat. Once done for all ages, normalize to one
Params.mewj=ones(1,Params.J); % Marginal distribution of households over age
for jj=2:length(Params.mewj)
    Params.mewj(jj)=Params.sj(jj-1)*Params.mewj(jj-1);
end
Params.mewj=Params.mewj./sum(Params.mewj); % Normalize to one
AgeWeightsParamNames={'mewj'}; % So VFI Toolkit knows which parameter is the mass of agents of each age

%% Grids (except Z, which is case-by-case below)
simoptions=struct();
vfoptions.precision='single'; simoptions.precision=vfoptions.precision;
cast2precision=str2func(vfoptions.precision);

zero=cast2precision(0);
a_grid_debt=1-exp(linspace(log(cast2precision(51)),0,floor(n_a(1)/3)+1));
a_grid_exp=exp(linspace(cast2precision(-2.5),log(a_multiplier),ceil(2*n_a(1)/3)))-linspace(exp(cast2precision(-2.5)),0,ceil(2*n_a(1)/3));
asset_grid=[a_grid_debt, a_grid_exp(2:end)]';
[~,zero_asset_index]=min(abs(asset_grid));
asset_grid(zero_asset_index)=0;

pv_grid=(2.^(0:n_a(2)-1)-1)';

% ks_grid and a_grid are set below

% Grid for labour choice when agej<Jr; Grid for kiwisaver liquidation otherwise
d_grid=linspace(zero,1,n_d)'; % Notice that it is imposing the 0<=d<=1 condition implicitly

%% Define aprime function for KiwiSaver
% By saying nothing about vfoptions.l_dexperienceasset or vfoptions.l_d2, it defaults to 1
% Ditto vfoptions.l_a2
ks_primeFn=@(d,ks,z1,z2,w,agej,Jr,ks_r,ks_employee,ks_employer,kappa_j) QEA_ksprimeFn_single(d,ks,z1,z2,w,agej,Jr,ks_r,ks_employee,ks_employer,kappa_j); % Will return the value of ks_prime
vfoptions.aprimeFn=ks_primeFn; simoptions.aprimeFn=vfoptions.aprimeFn;
vfoptions.experienceassetz=1; simoptions.experienceassetz=1;
simoptions.d_grid=d_grid;
% simoptions.a_grid is set below
simoptions.optimize_nProbs=0;
simoptions.verbose=1;

% 1st element: mean
% 2nd element: median
% 3rd element: std dev and variance
% 4th element: lorenz curve and gini coefficient
% 5th element: min/max
% 6th element: quantiles
% 7th element: More Inequality
simoptions.whichstats=[1,1,1,0,1,1,0];

%% Create the return function
DiscountFactorParamNames={'beta','sj'};

% Now use 'QEA_ReturnFn'
ReturnFn=@(d,aprime,pvprime,a,pv,ks,z1,z2,w,sigma,psi,eta,agej,Jr,pension,r,ks_employee,kappa_j,wg1,wg2,wg3,beta,sj,energy_shock,pv_share_price) ...
    QEA_ReturnFn_single(d,aprime,pvprime,a,pv,ks,z1,z2,w,sigma,psi,eta,agej,Jr,pension,r,ks_employee,kappa_j,wg1,wg2,wg3,beta,sj,energy_shock,pv_share_price);

% Octave compatibility layer: this ReturnFn supports direct singleton expansion.
vfoptions.vectorizedarrayfunnames={'QEA_ReturnFn_single','QEA_ksprimeFn_single','QEA_IncomeFn_single','QEA_ExpensesFn_single','QEA_LeisureFn_single'};
ncores = 10;
if exist('ncores', 'var') && ncores>1
    vfi_pool('start', ncores);
    vfoptions.n_proc=ncores;
end
vfoptions.verbose=1;

%% Compute Z grids (z_gridvals_J and pi_z_J) manually
%
% Discretize the AR(1) process z2
% Exogenous shock process, z2: AR1 on labor productivity units
% Note this is not dependent on age
Params.rho_z2=0.25; % 0.25 creates more tail-risk in pi_z vs 0.5
Params.sigma_epsilon_z2=0.25; % 0.5 creates more extreme values in z_grid vs 0.25
[z2_grid,pi_z2]=discretizeAR1_FarmerToda(0,Params.rho_z2,Params.sigma_epsilon_z2,n_z(2));
z2_grid=exp(z2_grid); % Take exponential of the grid
[mean_z2,~,~,~]=MarkovChainMoments(z2_grid,pi_z2); % Calculate the mean of the grid so as can normalise it
z2_grid=z2_grid./mean_z2; % Normalise the grid on z2 (so that the mean of z2 is exactly 1)


%% Prepare to graph Life-Cycle Profiles (later)
% FnsToEvaluate are how we say what we want to graph the life-cycles of
% Like with return function, we have to include (generically, d,aprime,a,z) as first inputs, then just any relevant parameters.

FnsToEvaluate2.income=@(d,aprime,pvprime,a,pv,ks,z1,z2,w,agej,Jr,pension,r,kappa_j,ks_employee,energy_shock) QEA_IncomeFn_single(d,aprime,pvprime,a,pv,ks,z1,z2,w,agej,Jr,pension,r,kappa_j,ks_employee,energy_shock);
FnsToEvaluate2.expenses=@(d,aprime,pvprime,a,pv,ks,z1,z2,w,agej,Jr,r,kappa_j,energy_shock,pv_share_price) QEA_ExpensesFn_single(d,aprime,pvprime,a,pv,ks,z1,z2,w,agej,Jr,r,kappa_j,energy_shock,pv_share_price);
FnsToEvaluate2.leisure_h=@(d,aprime,pvprime,a,pv,ks,z1,z2,w,agej,Jr,pension,r,kappa_j,ks_employee,wg1,wg2,wg3,beta,sj,energy_shock,pv_share_price) QEA_LeisureFn_single(d,aprime,pvprime,a,pv,ks,z1,z2,w,agej,Jr,pension,r,kappa_j,ks_employee,wg1,wg2,wg3,beta,sj,energy_shock,pv_share_price);

% Create a universal dimension protector that evaluates to an (N_a x N_z) matrix of zeros
dim_protector = @(a, z1) 0 .* a .* z1;

FnsToEvaluate=FnsToEvaluate2;
% Trivial functions safely expanded to the full state space:
FnsToEvaluate.fractiontimeworked    = @(h,aprime,pvprime,a,pv,ks,z1,z2) h + dim_protector(a, z1);
FnsToEvaluate.assets                = @(d,aprime,pvprime,a,pv,ks,z1,z2) a + dim_protector(a, z1);
FnsToEvaluate.pv                    = @(d,aprime,pvprime,a,pv,ks,z1,z2) pv + dim_protector(a, z1);
FnsToEvaluate.ks                    = @(d,aprime,pvprime,a,pv,ks,z1,z2) ks + dim_protector(a, z1);
FnsToEvaluate.fractionunemployed    = @(d,aprime,pvprime,a,pv,ks,z1,z2) (z1==0) + dim_protector(a, z1);
FnsToEvaluate.fractionwithmedicalexpenses = @(d,aprime,pvprime,a,pv,ks,z1,z2) (z1==0.300000011920928955078125) + dim_protector(a, z1);

FnsToEvaluate.earnings=@(h,aprime,pvprime,a,pv,ks,z1,z2,w,kappa_j) w*kappa_j.*z1.*h; % w*kappa_j*z*h is the labor earnings (note: h will be zero when z is zero, so could just use w*kappa_j*h)

%% Now compute the 'stationary distribution' of households under various conditions
% Four shock regimes: none, unemployment and medical, energy, all shocks
% Three retirement regimes: 5% employee only, 3.5%+3.5%, 5%+5%
% Three pension regimes: 7%, 15%, 25%
ACSmat=cell(length(pv_regimes),length(ks_legends),length(pension_schemes),length(shock_titles));

orig_n_a=n_a;
orig_n_z=n_z;
orig_z2_grid=z2_grid;
orig_pi_z2=pi_z2;

for shock_regime=1:length(shock_titles)
    ExogShockFn=ExocShockFn_vec{shock_regime};
    Params.energy_shock=Params.energy_shock_magnitude*energy_shock_factor(shock_regime);
    if energy_shock_factor(shock_regime)==0
        % Create trivial z2 grid
        n_z(2)=1;
        z2_grid=1;
        pi_z2=1;
    else
        n_z=orig_n_z;
        z2_grid=orig_z2_grid;
        pi_z2=orig_pi_z2;
    end
    [z_gridvals_J,pi_z_J,statdist_z1,vfoptions_this_shock,simoptions_this_shock]=Setup_QEA_z_grids(n_z,z2_grid,pi_z2,Params,@(agej,Jr) ExogShockFn(agej,Jr),vfoptions,simoptions);

    for pv_regime=pv_regimes
        pv_grid=(2.^(0:pv_regime-1)-1)';

        for ks_regime=1:length(ks_legends)
            Params.ks_employee=ks_regime_contributions(ks_regime,1);
            Params.ks_employer=ks_regime_contributions(ks_regime,2);

            if Params.ks_employee+Params.ks_employer==0
                % Create trivial ks grid
                n_a(3)=3;
                ks_grid=[0;1;2]; % Just need something to make ExpAssetz work
            else
                n_a=orig_n_a;
                % We want a grid that captures both the incremental contributions over time
                % and also the compound interest.  Note that with 5% contribution plus 5%
                % employer match, agents can invest 10% of w per year before they retire.
                % 0.1*cumsum(1.07.^(45:-1:1)) is 30*w if no shocks (and no kappa_j).
                % Grid is bounded by 0 and exp(-4)==0.0183 is entry-point for low-earners
                ks_contrib_sum=Params.w*sum(Params.ks_employee*Params.kappa_j(1:Params.Jr-1));
                if Params.ks_r==0
                    ks_balance=Params.w*cumsum((Params.ks_employee+Params.ks_employer)*Params.kappa_j(1:Params.Jr-1));
                else
                    ks_balance=Params.w*cumsum((Params.ks_employee+Params.ks_employer)*Params.kappa_j(1:Params.Jr-1).*((1+Params.ks_r).^(Params.Jr-1:-1:1)-1));
                end
                % Add in 10 years of ks accumulation assuming 4% draw-down
                ks_balance=[ks_balance, ks_balance(end)+cumsum(ks_balance(end).*((1+Params.ks_r-0.03).^(Params.J-Params.Jr:-1:1)-1))];
                ks_max=ks_balance(end)*ks_multiplier;
                ks_max=ks_balance(end)+2;
                % ks_grid=[0, exp(linspace(cast2precision(-4),log(ks_max-ks_contrib_sum+1),n_a(3)-1))+linspace(0,ks_contrib_sum,n_a(3)-1)]';
                if mod(ks_regime,2)==1
                    ks_grid=linspace(0,ks_max,n_a(3))';
                else
                    ks_grid=[0, exp(linspace(cast2precision(-4),log(ks_max),n_a(3)-1))]';
                end
            end
            [~,zero_ks_index]=min(abs(ks_grid));
            ks_grid(zero_ks_index)=0;
            % [~,test_ks_index]=min(abs(ks_grid-2));
            % ks_grid(test_ks_index)=2;
            test_ks_index=zero_ks_index;

            n_a(2)=pv_regime;
            a_grid=[asset_grid; pv_grid; ks_grid];
            simoptions_this_shock.a_grid=a_grid;

            vfoptions_this_shock.lowmemory=calculate_lowmem(n_d, n_a, n_z, vfoptions); simoptions_this_shock.lowmemory=vfoptions_this_shock.lowmemory;

            for pension_regime=1:length(pension_schemes)
                Params.pension=pension_schemes(pension_regime);

                fprintf("Solving %s, pv_max=%d, ks %s, pension %d%%\n", shock_titles{shock_regime}, pv_regime, ks_legends{ks_regime}, round(100*pension_schemes(pension_regime)));
                %% Solve the model, with/without shocks, to compare asset profiles
                tic;
                [V, Policy]=ValueFnIter_Case1_FHorz(n_d,n_a,n_z,N_j, d_grid, a_grid, z_gridvals_J, pi_z_J, ReturnFn, Params, DiscountFactorParamNames, [], vfoptions_this_shock);
                toc

                %% Initial distribution of agents at birth (j=1)
                % Before we plot the life-cycle profiles we have to define how agents are at age j=1. We will give them all zero assets.
                jequaloneDist=zeros([n_a,n_z],vfoptions.precision,'gpuArray'); % Put no households anywhere on grid
                jequaloneDist(zero_asset_index,1,test_ks_index,:,(n_z(2)+1)/2)=statdist_z1; % All agents start with zero assets, no pvs, no kiwisaver, with z drawn from its stationary distribution

                StationaryDist=StationaryDist_FHorz_Case1(jequaloneDist,AgeWeightsParamNames,Policy,n_d,n_a,n_z,N_j,pi_z_J,Params,simoptions_this_shock);

                %% Calculate the life-cycle profiles for all shocks
                AgeConditionalStats=LifeCycleProfiles_FHorz_Case1(StationaryDist,Policy,FnsToEvaluate,Params,[],n_d,n_a,n_z,N_j,d_grid,a_grid,z_gridvals_J,simoptions_this_shock);
                AgeConditionalStats.title=sprintf("Life Cycle Profile: Assets Allocations %s; Pension %d", shock_titles{shock_regime}, round(100*pension_schemes(pension_regime)));
                AgeConditionalStats.legend={sprintf("KiwiSaver Balance (ks) %s", ks_legends{ks_regime}), ...
                    'Solar PV Shares (pv)', ...
                    'Assets (a)', ...
                    'Leisure (leisure_h)', ...
                    'Location','northeast'};
                % shocks last, so they stay together as a group
                ACSmat{pv_regime,ks_regime,pension_regime,shock_regime}=AgeConditionalStats;

                % Notice that medical expense shocks late in life cause elderly households
                % to hold more assets (as self-insurance against medical expense shocks)

                if shock_regime==2 && pension_regime==3
                    if ishandle(ks_regime)
                        clf(ks_regime)
                    end
                    figure(ks_regime+pv_regime*length(pv_regimes))
                    hold on
                    plot(1:1:Params.J,AgeConditionalStats.assets.Mean)
                    plot(1:1:Params.J,AgeConditionalStats.assets.Minimum)
                    plot(1:1:Params.J,AgeConditionalStats.assets.Maximum)
                    plot(1:1:Params.J,AgeConditionalStats.ks.Mean,'-o')
                    plot(1:1:Params.J,AgeConditionalStats.ks.Minimum,'-d')
                    hold off
                    title(sprintf("\nLife Cycle Profile: Assets (a)\nParams.rho_z2 = %.3f;\nParams.sigma_epsilon_z2 = %.3f\nKS: %s\nPension = %d", Params.rho_z2, Params.sigma_epsilon_z2, ks_legends{ks_regime}, round(100*pension_schemes(pension_regime))),'Interpreter','none')
                    legend(shock_titles{shock_regime},'Interpreter','none')

                    AgeConditionalStats2=LifeCycleProfiles_FHorz_Case1(StationaryDist,Policy,FnsToEvaluate2,Params,[],n_d,n_a,n_z,N_j,d_grid,a_grid,z_gridvals_J,simoptions_this_shock);

                    if ishandle(301+(pv_regime*length(pv_regimes)+ks_regime)*2)
                        clf(301+(pv_regime*length(pv_regimes)+ks_regime)*2)
                    end
                    figure(301+(pv_regime*length(pv_regimes)+ks_regime)*2)
                    hold on
                    plot(1:1:Params.J,AgeConditionalStats2.income.Mean)
                    plot(1:1:Params.J,AgeConditionalStats2.income.QuantileMeans(Params.Q_min,:))
                    plot(1:1:Params.J,AgeConditionalStats2.income.QuantileMeans(Params.Q_max,:))
                    plot(1:1:Params.J,AgeConditionalStats2.expenses.Mean)
                    plot(1:1:Params.J,AgeConditionalStats2.expenses.QuantileMeans(Params.Q_min,:))
                    plot(1:1:Params.J,AgeConditionalStats2.expenses.QuantileMeans(Params.Q_max,:))
                    legend({'income.Mean','income.Q_min','income.Q_max','expense.Mean','expense.Q_min','expense.Q_max'},'Interpreter','none')
                    hold off

                    AgeConditionalStats2=LifeCycleProfiles_FHorz_Case1(StationaryDist,Policy,FnsToEvaluate2,Params,[],n_d,n_a,n_z,N_j,d_grid,a_grid,z_gridvals_J,simoptions_this_shock);

                    if ishandle(302+(pv_regime*length(pv_regimes)+ks_regime)*2)
                        clf(302+(pv_regime*length(pv_regimes)+ks_regime)*2)
                    end
                    figure(302+(pv_regime*length(pv_regimes)+ks_regime)*2)
                    hold on
                    plot(1:1:Params.J,AgeConditionalStats2.leisure_h.Mean,'-o')
                    plot(1:1:Params.J,AgeConditionalStats2.leisure_h.Minimum,'-d')
                    plot(1:1:Params.J,AgeConditionalStats2.leisure_h.Maximum,'-p')
                    hold off
                end
            end
        end
    end
end

if exist('ncores', 'var')
    vfi_pool('stop', ncores);
end

%% Plot the results
%% Plot the life cycle profiles of fraction-of-time-worked, earnings, assets, unemployment, and medical expenses
% Find and keep only the struct cells
struct_indices = cellfun(@isstruct, ACSmat);
struct_cell = ACSmat(struct_indices);

% Combine the structures vertically (works seamlessly in Octave)
ACSvec = cat(1, struct_cell{:});

save -binary 'asset_data.mat' 'ACSvec' 'asset_grid' 'pv_grid' 'ks_grid' 'Params';

Plot_ACS_assets(ACSvec,asset_grid,pv_grid,ks_grid,Params,100);

Plot_ACS_profiles(ACSvec,Params,200);


%% Solve benefits equation for GE (not yet)
function benefit_reduction=BenefitsEqm(UnmetBenefit,BenefitSpending,max_benefit)
if UnmetBenefit==0
    if BenefitSpending==0
        if max_benefit<1e-4
            % No slack to cut
            benefit_reduction=0;
        else
            % Cut slack aggressively
            benefit_reduction=max_benefit*0.5;
        end
    else
        benefit_reduction=max_benefit*0.25;
    end
elseif UnmetBenefit*20<BenefitSpending
    % Allow for more than 1% needs unmet, but certainly less than 5% unmet
    if UnmetBenefit*100<BenefitSpending
        benefit_reduction=max_benefit*0.05;
    else
        benefit_reduction=0;
    end
else
    % Increase benefit to meet more needs.  Must be less than half our increase, lest we ping-pong in some cases
    benefit_reduction=-0.02*max_benefit;
end


end
