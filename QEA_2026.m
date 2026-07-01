%% QEA-2026: Unemployment, Medical, and Energy Shocks

%% Adapted from Life-Cycle Model 21: Idiosyncratic medical shocks in retirement
% Various ExogShockFn are used to make both the grid and transition probabilities depend on age.

% Note: Both the z1_grid_J and the ExogShockFn approaches require that the
% number of grid points in z1_grid does NOT change with age.

%% How does VFI Toolkit think about this?
%
% Two decision variables:
%     h, labour hours worked;
%     ks_out, fraction of retirement savings to liquidate
% Two endogenous state variables:
%     a, assets (total household savings);
%     pv, shares of PV+Battery assets (offset electricity costs, generate grid income)
% Two stochastic exogenous state variables:
%     z1, dual-purpose ('unemployment' shock in working age, medical shock in retirement)
%     z2, AR(1) energy price shock
% Age: j

%% Begin setting up to use VFI Toolkit to solve
% Lets model agents from age 20 to age 100, so 81 periods

Params.agejshifter=19; % Age 20 minus one. Makes keeping track of actual age easy in terms of model age
Params.J=100-Params.agejshifter; % =81, Number of period in life-cycle

% Grid sizes to use
n_d=[29,13]; % Endogenous labour choice (fraction of time worked); and kiwisaver redemption percentage
n_a=[83,7,97]; % Endogenous asset holdings: assets, pv, kiwisaver
n_z=[2,5]; % Exogenous labor productivity units shock; energy price shocks
N_j=Params.J; % Number of periods in finite horizon
vfoptions.lowmemory=3;
Params.Q_min=2;
Params.Q_max=19;

%% Parameters

% Discount rate
Params.beta = 0.96;
% Preferences
Params.sigma = 2; % Coeff of relative risk aversion (curvature of consumption)
Params.eta = 1.5; % Curvature of leisure (This will end up being 1/Frisch elasticity)
Params.psi = 10; % Weight on leisure

% Prices
Params.w=1; % Wage
Params.r=0.05; % Interest rate (0.05 is 5%)
% Note that this include direct costs (utilities, transport fuel) as well as indirect (energy fraction costs of goods and services consumed)
Params.energy_shock=0; % If 1, shock returns to mean; if > 1, shock increases price by (energy_shock-1)
% Median Kiwi income is roughly $120K/hh, so $20K 5kW system with 10kWh battery is 1/6th income.
% One fifth share of that (1kW+2kWh) is 1/30th income.
Params.pv_share_price=1/30;

% KiwiSaver Scheme
Params.ks_r=0.07; % Long-term growth estimate
Params.ks_employee=0.035; % Employee contribution
Params.ks_employer=0.035; % Employer contribution

% Demographics
Params.agej=1:1:Params.J; % Is a vector of all the agej: 1,2,3,...,J
Params.Jr=46;

% Pensions
Params.pension=0.2;

% Age-dependent labor productivity units
Params.kappa_j=[linspace(0.5,2,Params.Jr-15),linspace(2,1,14),zeros(1,Params.J-Params.Jr+1)];

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
Params.sj=1-Params.dj(21:101); % Conditional survival probabilities
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
vfoptions.precision='single'; simoptions.precision=vfoptions.precision;
cast2precision=str2func(vfoptions.precision);

% The ^3 means that there are more points near 0 and near 16. We know from theory that the value function will be more 'curved' near zero assets,
% and putting more points near curvature (where the derivative changes the most) increases accuracy of results.
zero=cast2precision(0);
a_grid_cubed=linspace(cast2precision(-1.4),0,floor(n_a(1)/4)+1).^3; % If the debt well is not deep enough, -Inf kills those that touch bottom
[~,zero_asset_index]=min(abs(a_grid_cubed));
a_grid_cubed(zero_asset_index)=0;
a_grid_exp=exp(linspace(cast2precision(-3),log(10),ceil(3*n_a(1)/4)))-linspace(cast2precision(exp(-3)),0,ceil(3*n_a(1)/4));
asset_grid=[a_grid_cubed, a_grid_exp(2:end)]';

n_a(2)=1;
pv_grid=(0:n_a(2)-1)';

% We want a grid that captures both the incremental contributions over time
% and also the compound interest.  Note that with 5% contribution plus 5%
% employer match, agents can invest 10% of w before they retire.
% cumsum(0.1*ones(1,45).*(1.07.^(45:-1:1))) is 30*w if no shocks.
% Grid is bounded by 0 and exp(-4)==0.0183 is entry-point for low-earners
ks_max=ceil(1.6*sum((Params.ks_employee+Params.ks_employer)*Params.kappa_j(1:Params.Jr-1).*((1+Params.ks_r).^(Params.Jr-1:-1:1)-1)))
ks_contrib_sum=ceil(sum(Params.ks_employee*Params.kappa_j(1:Params.Jr-1)))
ks_grid=[0, exp(linspace(-4,log(ks_max-ks_contrib_sum+1),n_a(3)-1))+linspace(0,ks_contrib_sum,n_a(3)-1)]';

a_grid=[asset_grid; pv_grid; ks_grid];

% Grid for labour choice
h_grid=linspace(zero,1,n_d(1))'; % Notice that it is imposing the 0<=h<=1 condition implicitly
% Grid for kiwisaver liquidation; limit to 50% total liquidation per year
ks_out_grid=(linspace(zero,(1/2)^(1/3),n_d(2)).^3)';

% tell the code how many d1, d2, and d3 there are
% Idea is to distinguish three categories of decision variable:
%  d1: decision is in the ReturnFn but not in aprimeFn
%  d2: decision is in the aprimeFn but not in ReturnFn
%  d3: decision is in both ReturnFn and in aprimeFn
% Note: ReturnFn must use inputs (d1,d3,..) 
%       aprimeFn must use inputs (d2,d3,..)
% n_d must be set up as n_d=[n_d1, n_d2, n_d3]
% d_grid must be set up as d_grid=[d1_grid; d2_grid; d3_grid];
d_grid=[h_grid; ks_out_grid];

%% Define aprime function for KiwiSaver
ks_primeFn=@(h,ks_out,ks,z1,z2,w,agej,Jr,ks_r,ks_employee,ks_employer,kappa_j) QEA_ksprimeFn(h,ks_out,ks,z1,z2,w,agej,Jr,ks_r,ks_employee,ks_employer,kappa_j); % Will return the value of ks_prime
vfoptions.aprimeFn=ks_primeFn; simoptions.aprimeFn=vfoptions.aprimeFn;
vfoptions.experienceassetz=1; simoptions.experienceassetz=1;
simoptions.d_grid=d_grid;
simoptions.a_grid=a_grid;
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
ReturnFn=@(h,ks_out,aprime,pvprime,a,pv,ks,z1,z2,w,sigma,psi,eta,agej,Jr,pension,r,ks_employee,kappa_j,wg1,wg2,wg3,beta,sj,energy_shock,pv_share_price) ...
    QEA_ReturnFn(h,ks_out,aprime,pvprime,a,pv,ks,z1,z2,w,sigma,psi,eta,agej,Jr,pension,r,ks_employee,kappa_j,wg1,wg2,wg3,beta,sj,energy_shock,pv_share_price);


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
% Now build z_gridvals_J and pi_z_J, setting vfoptions and simoptions flags appropriately
[z_gridvals_no_shocks_J,pi_z_no_shocks_J,statdist_z1_no_shocks,vfoptions_no_shocks,simoptions_no_shocks]=Setup_QEA(n_z,z2_grid,pi_z2,Params,@(agej,Jr) LifeCycleModel21_ExogShockFn3(agej,Jr),vfoptions,simoptions);


%% Solve the value function iteration problem with no age-dependent shocks
disp('Solve for Value fn and Policy fn using ValueFnIter command')
tic;
% Because we don't set vfoptions.ExogShockFn (we set ExogShockFn1 to "hide" it), our specially computed z_gridvals_J and pi_z_J are used
[V_no_shocks, Policy_no_shocks]=ValueFnIter_Case1_FHorz(n_d,n_a,n_z,N_j, d_grid, a_grid, z_gridvals_no_shocks_J, pi_z_no_shocks_J, ReturnFn, Params, DiscountFactorParamNames, [], vfoptions_no_shocks);
toc

%% Now, we want to graph Life-Cycle Profiles
% FnsToEvaluate are how we say what we want to graph the life-cycles of
% Like with return function, we have to include (generically, d,aprime,a,z) as first inputs, then just any relevant parameters.
FnsToEvaluate.fractiontimeworked=@(h,ks_out,aprime,pvprime,a,pv,ks,z1,z2) h; % h is fraction of time worked
FnsToEvaluate.earnings=@(h,ks_out,aprime,pvprime,a,pv,ks,z1,z2,w,kappa_j) w*kappa_j*z1*h; % w*kappa_j*z*h is the labor earnings (note: h will be zero when z is zero, so could just use w*kappa_j*h)
FnsToEvaluate.assets=@(h,ks_out,aprime,pvprime,a,pv,ks,z1,z2) a; % a is the current asset holdings
FnsToEvaluate.pv=@(h,ks_out,aprime,pvprime,a,pv,ks,z1,z2) pv; % a is the current asset holdings
FnsToEvaluate.ks=@(h,ks_out,aprime,pvprime,a,pv,ks,z1,z2) ks; % a is the current asset holdings
FnsToEvaluate.fractionunemployed=@(h,ks_out,aprime,pvprime,a,pv,ks,z1,z2) (z1==0); % indicator for z=0 (unemployment) [Note: only makes sense as unemployment for j=1,..,Jr]
FnsToEvaluate.fractionwithmedicalexpenses=@(h,ks_out,aprime,pvprime,a,pv,ks,z1,z2) (z1==0.3); % indicator for z=0.3 medical shock


%% Initial distribution of agents at birth (j=1)
% Before we plot the life-cycle profiles we have to define how agents are at age j=1. We will give them all zero assets.
jequaloneDist_no_shocks=zeros([n_a,n_z],vfoptions.precision,'gpuArray'); % Put no households anywhere on grid
jequaloneDist_no_shocks(zero_asset_index,1,1,:,(n_z(2)+1)/2)=statdist_z1_no_shocks; % All agents start with zero assets, zero pv, empty ks, with z drawn from its stationary distribution

StationaryDist_no_shocks=StationaryDist_FHorz_Case1(jequaloneDist_no_shocks,AgeWeightsParamNames,Policy_no_shocks,n_d,n_a,n_z,N_j,pi_z_no_shocks_J,Params,simoptions_no_shocks);
AgeConditionalStats_no_shocks=LifeCycleProfiles_FHorz_Case1(StationaryDist_no_shocks,Policy_no_shocks,FnsToEvaluate,Params,[],n_d,n_a,n_z,N_j,d_grid,a_grid,z_gridvals_no_shocks_J,simoptions_no_shocks);
AgeConditionalStats_no_shocks.title="Life Cycle Profile: Assets Allocations No Shocks (At All)";
AgeConditionalStats_no_shocks.legend={'KiwiSaver Balance (ks)', ...
    'Solar PV Shares (pv)', ...
    'Assets (a)', ...
    'Location','northeast'};

%% Introduce an energy-only shock, to compare asset profiles
Params.energy_shock=2;

[V_energy_only, Policy_energy_only]=ValueFnIter_Case1_FHorz(n_d,n_a,n_z,N_j, d_grid, a_grid, z_gridvals_no_shocks_J, pi_z_no_shocks_J, ReturnFn, Params, DiscountFactorParamNames, [], vfoptions_no_shocks);

StationaryDist_energy_only=StationaryDist_FHorz_Case1(jequaloneDist_no_shocks,AgeWeightsParamNames,Policy_energy_only,n_d,n_a,n_z,N_j,pi_z_no_shocks_J,Params,simoptions_no_shocks);
AgeConditionalStats_energy_only=LifeCycleProfiles_FHorz_Case1(StationaryDist_energy_only,Policy_energy_only,FnsToEvaluate,Params,[],n_d,n_a,n_z,N_j,d_grid,a_grid,z_gridvals_no_shocks_J,simoptions_no_shocks);
AgeConditionalStats_energy_only.title="Life Cycle Profile: Assets Allocations Energy Only Shocks";
AgeConditionalStats_energy_only.legend={'KiwiSaver Balance (ks)', ...
    'Solar PV Shares (pv)', ...
    'Assets (a)', ...
    'Location','northeast'};


% For example
% AgeConditionalStats.earnings.Mean
% There are things other than Mean (Median, Gini, percentiles, etc.); in
% earlier deterministic models all agents were identical at each age so
% those were trivial, but now that we have an idiosyncratic shock z they
% are meaningful and worth looking at.

if ishandle(1)
    clf(1)
end
figure(1)
hold on
plot(1:1:Params.J,AgeConditionalStats_no_shocks.assets.Mean)
plot(1:1:Params.J,AgeConditionalStats_energy_only.assets.Mean)
hold off
title(sprintf("\nLife Cycle Profile: Assets (a)\nParams.rho\\_z2 = %.3f;\nParams.sigma\\_epsilon\\_z2 = %.3f", Params.rho_z2, Params.sigma_epsilon_z2))
legend('No Unemployment nor Medical Shocks', 'Energy Shocks Only')


%% Plot the life cycle profiles of fraction-of-time-worked, earnings, assets, unemployment, and medical expenses
ACSvec=[AgeConditionalStats_no_shocks, AgeConditionalStats_energy_only];

Plot_ACS_profiles(ACSvec,Params,1);

Plot_ACS_assets(ACSvec,asset_grid,pv_grid,ks_grid,Params,4);

% Notice how we only plot the first part of
% AgeConditionalStats.fractionunemployed.Mean(1:Params.Jr-1), because this
% FnToEvaluate is based on z, which changes meaning between j=Jr-1 and j=Jr.
%% Now compute value function with unemployment and medical shocks (but not energy shocks)
Params.energy_shock=0;

[z_gridvals_all_shocks_J,pi_z_all_shocks_J,statdist_z1_all_shocks,vfoptions_all_shocks,simoptions_all_shocks]=Setup_QEA(n_z,z2_grid,pi_z2,Params,@(agej,Jr) LifeCycleModel21_ExogShockFn(agej,Jr),vfoptions,simoptions);

[V_all_shocks, Policy_all_shocks]=ValueFnIter_Case1_FHorz(n_d,n_a,n_z,N_j, d_grid, a_grid, z_gridvals_all_shocks_J, pi_z_all_shocks_J, ReturnFn, Params, DiscountFactorParamNames, [], vfoptions_all_shocks);


%% Now compute the 'stationary distribution' of households with shocks

%% Initial distribution of agents at birth (j=1)
% Before we plot the life-cycle profiles we have to define how agents are at age j=1. We will give them all zero assets.
jequaloneDist_all_shocks=zeros([n_a,n_z],vfoptions.precision,'gpuArray'); % Put no households anywhere on grid
jequaloneDist_all_shocks(zero_asset_index,1,1,:,(n_z(2)+1)/2)=statdist_z1_all_shocks; % All agents start with zero assets, no pvs, no kiwisaver, with z drawn from its stationary distribution

StationaryDist_all_shocks=StationaryDist_FHorz_Case1(jequaloneDist_all_shocks,AgeWeightsParamNames,Policy_all_shocks,n_d,n_a,n_z,N_j,pi_z_all_shocks_J,Params,simoptions_all_shocks);

%% Calculate the life-cycle profiles for all shocks
AgeConditionalStats_all_shocks=LifeCycleProfiles_FHorz_Case1(StationaryDist_all_shocks,Policy_all_shocks,FnsToEvaluate,Params,[],n_d,n_a,n_z,N_j,d_grid,a_grid,z_gridvals_all_shocks_J,simoptions_all_shocks);
AgeConditionalStats_all_shocks.title="Life Cycle Profile: Assets Allocations All Shocks";
AgeConditionalStats_all_shocks.legend={'KiwiSaver Balance (ks)', ...
    'Solar PV Shares (pv)', ...
    'Assets (a)', ...
    'Location','northeast'};


%% Solve the model again, but without medical shocks, to compare asset profiles
% Continue to use return function, but with appropriate ExogShockFn
% We will evaluate the ExogShockFn at agej=1, just because I want to use
% the stationary distribution as the initial distribution for agents.
[z_gridvals_no_medical_J,pi_z_no_medical_J,statdist_z1_no_medical,vfoptions_no_medical,simoptions_no_medical]=Setup_QEA(n_z,z2_grid,pi_z2,Params,@(agej,Jr) LifeCycleModel21_ExogShockFn1(agej,Jr),vfoptions,simoptions);

[V_no_medical, Policy_no_medical]=ValueFnIter_Case1_FHorz(n_d,n_a,n_z,N_j, d_grid, a_grid, z_gridvals_no_medical_J, pi_z_no_medical_J, ReturnFn, Params, DiscountFactorParamNames, [], vfoptions_no_medical);

%% Initial distribution of agents at birth (j=1)
% Before we plot the life-cycle profiles we have to define how agents are at age j=1. We will give them all zero assets.
jequaloneDist_no_medical=zeros([n_a,n_z],vfoptions.precision,'gpuArray'); % Put no households anywhere on grid
jequaloneDist_no_medical(zero_asset_index,1,1,:,(n_z(2)+1)/2)=statdist_z1_no_medical; % All agents start with zero assets, with z drawn from its stationary distribution

StationaryDist_no_medical=StationaryDist_FHorz_Case1(jequaloneDist_no_medical,AgeWeightsParamNames,Policy_no_medical,n_d,n_a,n_z,N_j,pi_z_no_medical_J,Params,simoptions_no_medical);
AgeConditionalStats_no_medical=LifeCycleProfiles_FHorz_Case1(StationaryDist_no_medical,Policy_no_medical,FnsToEvaluate,Params,[],n_d,n_a,n_z,N_j,d_grid,a_grid,z_gridvals_no_medical_J,simoptions_no_medical);
AgeConditionalStats_no_medical.title="Life Cycle Profile: Assets Allocations No Medical Shocks";
AgeConditionalStats_no_medical.legend={'KiwiSaver Balance (ks)', ...
    'Solar PV Shares (pv)', ...
    'Assets (a)', ...
    'Location','northeast'};

%% Solve the model again, but without unemployment shocks, to compare asset profiles
[z_gridvals_no_unemployment_J,pi_z_no_unemployment_J,statdist_z1_no_unemployment,vfoptions_no_unemployment,simoptions_no_unemployment]=Setup_QEA(n_z,z2_grid,pi_z2,Params,@(agej,Jr) LifeCycleModel21_ExogShockFn2(agej,Jr),vfoptions,simoptions);
[V_no_unemployment, Policy_no_unemployment]=ValueFnIter_Case1_FHorz(n_d,n_a,n_z,N_j, d_grid, a_grid, z_gridvals_no_unemployment_J, pi_z_no_unemployment_J, ReturnFn, Params, DiscountFactorParamNames, [], vfoptions_no_unemployment);

%% Initial distribution of agents at birth (j=1)
% Before we plot the life-cycle profiles we have to define how agents are at age j=1. We will give them all zero assets.
jequaloneDist_no_unemployment=zeros([n_a,n_z],vfoptions.precision,'gpuArray'); % Put no households anywhere on grid
jequaloneDist_no_unemployment(zero_asset_index,1,1,:,(n_z(2)+1)/2)=statdist_z1_no_unemployment; % All agents start with zero assets, with z drawn from its stationary distribution

StationaryDist_no_unemployment=StationaryDist_FHorz_Case1(jequaloneDist_no_unemployment,AgeWeightsParamNames,Policy_no_unemployment,n_d,n_a,n_z,N_j,pi_z_no_unemployment_J,Params,simoptions_no_unemployment);
AgeConditionalStats_no_unemployment=LifeCycleProfiles_FHorz_Case1(StationaryDist_no_unemployment,Policy_no_unemployment,FnsToEvaluate,Params,[],n_d,n_a,n_z,N_j,d_grid,a_grid,z_gridvals_no_unemployment_J,simoptions_no_unemployment);
AgeConditionalStats_no_unemployment.title="Life Cycle Profile: Assets Allocations No Unemployment Shocks";
AgeConditionalStats_no_unemployment.legend={'KiwiSaver Balance (ks)', ...
    'Solar PV Shares (pv)', ...
    'Assets (a)', ...
    'Location','northeast'};


%% Plot the results
ACSvec=[AgeConditionalStats_all_shocks,AgeConditionalStats_no_medical,AgeConditionalStats_no_unemployment,AgeConditionalStats_no_shocks,AgeConditionalStats_energy_only];

Plot_ACS_assets(ACSvec,asset_grid,pv_grid,ks_grid,Params,10);

% Notice that medical expense shocks late in life cause elderly households
% to hold more assets (as self-insurance against medical expense shocks)


%% Manually construct z_gridvals_J, pi_z_J, et al using ExogShockFn
function [z_gridvals_J,pi_z_J,statdist_z1,vfoptions,simoptions]=Setup_QEA(n_z,z2_grid,pi_z2,Params,ExogShockFn,vfoptions,simoptions)

% We will evaluate the ExogShockFn at agej=1, just because I want to use
% the stationary distribution as the initial distribution for agents.
z1_grid_J=zeros(n_z(1),Params.J,vfoptions.precision,'gpuArray');
pi_z1_J=zeros(n_z(1),n_z(1),Params.J,vfoptions.precision,'gpuArray');
for jj=1:Params.J
    [z1_grid, pi_z1]=ExogShockFn(jj,Params.Jr);
    z1_grid_J(:,jj)=z1_grid;
    pi_z1_J(:,:,jj)=pi_z1;
end

% Now, we put together the two grids, as a stacked column
z_gridvals_J=zeros(prod(n_z),length(n_z),Params.J,vfoptions.precision,'gpuArray');
% But use Kronecker product to combine pi_z grids
for jj=1:Params.J
    z_gridvals_J(:,:,jj)=CreateGridvals(n_z, [z1_grid_J(:,jj); z2_grid],1);
    pi_z_J(:,:,jj)=kron(pi_z2,pi_z1_J(:,:,jj)); % note reverse order
end

mcmomentsoptions.Tolerance=1e-4;
[mean_z1,~,~,statdist_z1]=MarkovChainMoments(z1_grid_J(:,1),pi_z1_J(:,:,1),mcmomentsoptions);

% Fix up vfoptions and simoptions
% Note ExogShockFn1 vs. ExogShockFn (so we don't ignore z_gridvals_J and pi_z_J)
vfoptions.ExogShockFn1=ExogShockFn;
vfoptions.alreadygridvals=1;
simoptions.alreadygridvals=1;
simoptions.z_grid=z_gridvals_J;


end

function Plot_ACS_assets(ACSvec,asset_grid,pv_grid,ks_grid,Params,figure_start)

if ~exist("figure_start", "var")
    figure_start=10;
end

ACS_mean_max=gather(max(arrayfun(@(x) max(x.assets.Mean), ACSvec)));
ACS_mean_min=gather(min(arrayfun(@(x) min(x.assets.Mean), ACSvec)));
ACS_max=gather(max(arrayfun(@(x) max(x.assets.QuantileCutoffs(Params.Q_max,:)), ACSvec)));
ACS_min=gather(min(arrayfun(@(x) min(x.assets.QuantileCutoffs(Params.Q_min,:)), ACSvec)));

legends=cell(length(ACSvec),1);
if ishandle(figure_start)
    clf(figure_start)
end
figure(figure_start)
hold on
axis([1, length(ACSvec(1).assets.Mean), ACS_mean_min, ACS_mean_max]);
for ii=1:length(ACSvec)
    plot(1:1:Params.J,ACSvec(ii).assets.Mean);
    legends(ii)={extractAfter(ACSvec(ii).title,'Life Cycle Profile: Assets Allocations ')};
end
title(sprintf("\nLife Cycle Profile: Assets (a)\nParams.rho\\_z2 = %.3f;\nParams.sigma\\_epsilon\\_z2 = %.3f", Params.rho_z2, Params.sigma_epsilon_z2))
legend(legends{:},'Location','northeast');
hold off

for ii=1:length(ACSvec)
    if ishandle(figure_start+ii)
        clf(figure_start+ii)
    end
    figure(figure_start+ii)
    axis([1, length(ACSvec(1).assets.Mean), ACS_min, ACS_max]);
    area(1:1:Params.J, [ACSvec(ii).ks.Mean; ACSvec(ii).pv.Mean*Params.pv_share_price; ACSvec(ii).assets.Mean]);
    title(ACSvec(ii).title)
    legend(ACSvec(ii).legend{:})
    if any(ACSvec(ii).assets.QuantileCutoffs(1,:)==asset_grid(1))
        warning(sprintf("assets (Minimum) hit debt floor ACSvec(%d)", ii));
    end
    if any(ACSvec(ii).assets.Mean==asset_grid(1))
        error(sprintf("assets (Mean) hit debt floor ACSvec(%d)", ii));
    end
    if any(ACSvec(ii).assets.QuantileCutoffs(end,:)==asset_grid(end))
        warning(sprintf("assets maxed out ACSvec(%d)", ii));
    end
    if any(ACSvec(ii).pv.QuantileCutoffs(end,:)==pv_grid(end))
        warning(sprintf("pv shares maxed out ACSvec(%d)", ii));
    end
    if any(ACSvec(ii).ks.QuantileCutoffs(end,:)==ks_grid(end))
        warning(sprintf("ks maxed out ACSvec(%d)", ii));
    end
end

end


function Plot_ACS_profiles(ACSvec, Params, figure_start)
for ii=1:length(ACSvec)
    if ishandle(figure_start+ii)
        clf(figure_start+ii)
    end
    figure(figure_start+ii)
    title(ACSvec(ii).title)
    subplot(4,2,1); Subplot_ACS_profiles(ACSvec, Params, ii, 'fractiontimeworked');
    title('Life Cycle Profile: Fraction Time Worked (h)')
    subplot(4,2,3); Subplot_ACS_profiles(ACSvec, Params, ii, 'earnings');
    title('Life Cycle Profile: Labor Earnings (w kappa_j z h)')
    subplot(4,2,5); plot(1:1:Params.J,[ACSvec(ii).fractionunemployed.Mean(1:Params.Jr-1),zeros(1,Params.J-Params.Jr+1)])
    title('Life Cycle Profile: Fraction Unemployment (z==0)')
    subplot(4,2,7); plot(1:1:Params.J,ACSvec(ii).fractionwithmedicalexpenses.Mean)
    title('Life Cycle Profile: Fraction experiencing medical expenses (z==0.3)')
    subplot(4,2,2); Subplot_ACS_profiles(ACSvec, Params, ii, 'assets');
    title('Life Cycle Profile: Assets (a)')
    subplot(4,2,4); Subplot_ACS_profiles(ACSvec, Params, ii, 'pv');
    title('Life Cycle Profile: 1kW PV Shares + 2KWh Battery (pv)')
    subplot(4,2,6); Subplot_ACS_profiles(ACSvec, Params, ii, 'ks');
    title('Life Cycle Profile: KiwiSaver (kw\_balance)')
    xlim([1,Params.J])
end

end

function Subplot_ACS_profiles(ACSvec, Params, ii, fieldname)
hold on
plot(1:1:Params.J,ACSvec(ii).(fieldname).Mean)
plot(1:1:Params.J,ACSvec(ii).(fieldname).Minimum)
plot(1:1:Params.J,ACSvec(ii).(fieldname).QuantileCutoffs(Params.Q_min,:))
plot(1:1:Params.J,ACSvec(ii).(fieldname).QuantileCutoffs(Params.Q_max,:))
plot(1:1:Params.J,ACSvec(ii).(fieldname).Maximum)
hold off

end
