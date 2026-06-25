%% QEA-2026: Unemployment, Medical, and Energy Shocks

%% Adapted from Life-Cycle Model 21: Idiosyncratic medical shocks in retirement
% Various ExogShockFn are used to make
% both the grid and transition probabilities depend on age.

% Note: Both the z1_grid_J and the ExogShockFn approaches require that the
% number of grid points in z1_grid does NOT change with age.

%% How does VFI Toolkit think about this?
%
% One decision variable: h, labour hours worked
% One endogenous state variable: a, assets (total household savings)
% Two stochastic exogenous state variables:
%     z1, dual-purpose ('unemployment' shock in working age, medical shock in retirement)
%     z2, AR(1) energy price shock
% Age: j

%% Begin setting up to use VFI Toolkit to solve
% Lets model agents from age 20 to age 100, so 81 periods

Params.agejshifter=19; % Age 20 minus one. Makes keeping track of actual age easy in terms of model age
Params.J=100-Params.agejshifter; % =81, Number of period in life-cycle

% Grid sizes to use
n_d=[31,5]; % Endogenous labour choice (fraction of time worked); and kiwisaver redemption percentage
n_a=[51,11,5]; % Endogenous asset holdings: assets, pv, kiwisaver
n_z=[2,9]; % Exogenous labor productivity units shock; energy price shocks
N_j=Params.J; % Number of periods in finite horizon

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
Params.ks_employee=0.05; % Employee contribution
Params.ks_employer=0.05; % Employer contribution

% Demographics
Params.agej=1:1:Params.J; % Is a vector of all the agej: 1,2,3,...,J
Params.Jr=46;

% Pensions
Params.pension=0.3;

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


%% Grids
vfoptions.precision='single'; simoptions.precision=vfoptions.precision;
cast2precision=str2func(vfoptions.precision);
vfoptions.lowmemory=1;

% The ^3 means that there are more points near 0 and near 16. We know from theory that the value function will be more 'curved' near zero assets,
% and putting more points near curvature (where the derivative changes the most) increases accuracy of results.
zero=cast2precision(0);
a_grid_cubed=linspace(zero,1,floor(n_a(1)/4)+1).^3;
a_grid_linear=linspace(cast2precision(1),10,ceil(3*n_a(1)/4));
asset_grid=[a_grid_cubed, a_grid_linear(2:end)]';

pv_grid=[linspace(0,4,floor(n_a(2)/2)),linspace(5,15,floor(n_a(2)/2)+1)]';

ks_grid=linspace(zero,20,n_a(3))';

a_grid=[asset_grid; pv_grid; ks_grid];

% Grid for labour choice
h_grid=linspace(zero,1,n_d(1))'; % Notice that it is imposing the 0<=h<=1 condition implicitly
% Grid for kiwisaver liquidation
ks_out_grid=(linspace(zero,1,n_d(2)).^3)';

% Switch into toolkit notation
d_grid=[h_grid; ks_out_grid];

% tell the code how many d1, d2, and d3 there are
% Idea is to distinguish three categories of decision variable:
%  d1: decision is in the ReturnFn but not in aprimeFn
%  d2: decision is in the aprimeFn but not in ReturnFn
%  d3: decision is in both ReturnFn and in aprimeFn
% Note: ReturnFn must use inputs (d1,d3,..) 
%       aprimeFn must use inputs (d2,d3,..)
% n_d must be set up as n_d=[n_d1, n_d2, n_d3]
% d_grid must be set up as d_grid=[d1_grid; d2_grid; d3_grid];

%% z1_grid and pi_z1 as a function that depends on age
% Note that the dependence on age is just via the parameters that are input
% In this example, agej obviously depends on age (it is a vector)
vfoptions.ExogShockFn1=@(agej,Jr) LifeCycleModel21_ExogShockFn(agej,Jr);
% simoptions.ExogShockFn=vfoptions.ExogShockFn;

% Discretize the AR(1) process z2
% Exogenous shock process, z2: AR1 on labor productivity units
% Note this is not dependent on age
Params.rho_z2=0.5;
Params.sigma_epsilon_z2=0.15;
[z2_grid,pi_z2]=discretizeAR1_FarmerToda(0,Params.rho_z2,Params.sigma_epsilon_z2,n_z(2));
z2_grid=exp(z2_grid); % Take exponential of the grid
[mean_z2,~,~,~]=MarkovChainMoments(z2_grid,pi_z2); % Calculate the mean of the grid so as can normalise it
z2_grid=z2_grid./mean_z2; % Normalise the grid on z2 (so that the mean of z2 is exactly 1)

% Both value function and simulations need to know about the age-dependence exogenous shocks

[z_gridvals_J,pi_z_J,statdist_z1,vfoptions]=Setup_QEA(n_z,z2_grid,pi_z2,Params,vfoptions.ExogShockFn1,vfoptions);


%% Define aprime function for KiwiSaver
ks_primeFn=@(h,ks_out,ks,z1,z2,w,agej,Jr,ks_r,ks_employee,ks_employer,kappa_j) QEA_ksprimeFn(h,ks_out,ks,z1,z2,w,agej,Jr,ks_r,ks_employee,ks_employer,kappa_j); % Will return the value of ks_prime
vfoptions.aprimeFn=ks_primeFn; simoptions.aprimeFn=vfoptions.aprimeFn;
vfoptions.experienceassetz=1; simoptions.experienceassetz=1;
simoptions.d_grid=d_grid;
simoptions.a_grid=a_grid;
simoptions.z_grid=z_gridvals_J;
simoptions.alreadygridvals=vfoptions.alreadygridvals;

%% Now, create the return function
DiscountFactorParamNames={'beta','sj'};

% Now use 'QEA_ReturnFn'
ReturnFn=@(h,ks_out,aprime,pvprime,a,pv,ks,z1,z2,w,sigma,psi,eta,agej,Jr,pension,r,ks_employee,kappa_j,wg1,wg2,wg3,beta,sj,energy_shock,pv_share_price) ...
    QEA_ReturnFn(h,ks_out,aprime,pvprime,a,pv,ks,z1,z2,w,sigma,psi,eta,agej,Jr,pension,r,ks_employee,kappa_j,wg1,wg2,wg3,beta,sj,energy_shock,pv_share_price);

%% Solve the value function iteration problem
disp('Solve for Value fn and Policy fn using ValueFnIter command')
tic;
[V, Policy]=ValueFnIter_Case1_FHorz(n_d,n_a,n_z,N_j, d_grid, a_grid, z_gridvals_J, pi_z_J, ReturnFn, Params, DiscountFactorParamNames, [], vfoptions);
toc
% Note: Because we have vfoptions.ExogShockFn, what we input for z1_grid and  pi_z1 will just be ignored.

%% Now, we want to graph Life-Cycle Profiles

%% Initial distribution of agents at birth (j=1)
% Before we plot the life-cycle profiles we have to define how agents are at age j=1. We will give them all zero assets.
jequaloneDist=zeros([n_a,n_z],vfoptions.precision,'gpuArray'); % Put no households anywhere on grid
jequaloneDist(1,1,1,:,(n_z(2)+1)/2)=statdist_z1; % All agents start with zero assets, no pvs, no kiwisaver, with z drawn from its stationary distribution

%% We now compute the 'stationary distribution' of households
% Start with a mass of one at initial age, use the conditional survival
% probabilities sj to calculate the mass of those who survive to next
% period, repeat. Once done for all ages, normalize to one
Params.mewj=ones(1,Params.J); % Marginal distribution of households over age
for jj=2:length(Params.mewj)
    Params.mewj(jj)=Params.sj(jj-1)*Params.mewj(jj-1);
end
Params.mewj=Params.mewj./sum(Params.mewj); % Normalize to one
AgeWeightsParamNames={'mewj'}; % So VFI Toolkit knows which parameter is the mass of agents of each age
StationaryDist=StationaryDist_FHorz_Case1(jequaloneDist,AgeWeightsParamNames,Policy,n_d,n_a,n_z,N_j,pi_z_J,Params,simoptions);
% Note: Because we have simoptions.ExogShockFn, what we input for z1_grid and  pi_z1 will just be ignored.

%% FnsToEvaluate are how we say what we want to graph the life-cycles of
% Like with return function, we have to include (h,aprime,a,z) as first inputs, then just any relevant parameters.
FnsToEvaluate.fractiontimeworked=@(h,ks_out,aprime,pvprime,a,pv,ks,z1,z2) h; % h is fraction of time worked
FnsToEvaluate.earnings=@(h,ks_out,aprime,pvprime,a,pv,ks,z1,z2,w,kappa_j) w*kappa_j*z1*h; % w*kappa_j*z*h is the labor earnings (note: h will be zero when z is zero, so could just use w*kappa_j*h)
FnsToEvaluate.assets=@(h,ks_out,aprime,pvprime,a,pv,ks,z1,z2) a; % a is the current asset holdings
FnsToEvaluate.pv=@(h,ks_out,aprime,pvprime,a,pv,ks,z1,z2) pv; % a is the current asset holdings
FnsToEvaluate.ks=@(h,ks_out,aprime,pvprime,a,pv,ks,z1,z2) ks; % a is the current asset holdings
FnsToEvaluate.fractionunemployed=@(h,ks_out,aprime,pvprime,a,pv,ks,z1,z2) (z1==0); % indicator for z=0 (unemployment) [Note: only makes sense as unemployment for j=1,..,Jr]
FnsToEvaluate.fractionwithmedicalexpenses=@(h,ks_out,aprime,pvprime,a,pv,ks,z1,z2) (z1==0.3); % indicator for z=0.3 medical shock

%% Calculate the life-cycle profiles
AgeConditionalStats=LifeCycleProfiles_FHorz_Case1(StationaryDist,Policy,FnsToEvaluate,Params,[],n_d,n_a,n_z,N_j,d_grid,a_grid,z_gridvals_J,simoptions);
AgeConditionalStats.title="Life Cycle Profile: Assets Allocations All Shocks";
AgeConditionalStats.legend={'KiwiSaver Balance (ks)', ...
    'Solar PV Shares (pv)', ...
    'Assets (a)', ...
    'Location','northeast'};
% Note: Because we have simoptions.ExogShockFn, what we input for z1_grid will just be ignored.

% For example
% AgeConditionalStats.earnings.Mean
% There are things other than Mean (Median, Gini, percentiles, etc.); in
% earlier deterministic models all agents were identical at each age so
% those were trivial, but now that we have an idiosyncratic shock z they
% are meaningful and worth looking at.

clf(10)
figure(10)
plot(1:1:Params.J,AgeConditionalStats.assets.Mean)
title(sprintf("\nLife Cycle Profile: Assets (a)\nParams.rho_z2 = %.3f;\nParams.sigma_epsilon_z2 = %.3f", Params.rho_z2, Params.sigma_epsilon_z2))
legend('Unemployment+Medical Expense Shocks')


%% Plot the life cycle profiles of fraction-of-time-worked, earnings, assets, unemployment, and medical expenses
clf(1)
figure(1)
subplot(4,2,1); plot(1:1:Params.J,AgeConditionalStats.fractiontimeworked.Mean)
title('Life Cycle Profile: Fraction Time Worked (h)')
subplot(4,2,3); plot(1:1:Params.J,AgeConditionalStats.earnings.Mean)
title('Life Cycle Profile: Labor Earnings (w kappa_j z h)')
subplot(4,2,5); plot(1:1:Params.J,[AgeConditionalStats.fractionunemployed.Mean(1:Params.Jr-1),zeros(1,Params.J-Params.Jr+1)])
title('Life Cycle Profile: Fraction Unemployment (z==0)')
subplot(4,2,7); plot(1:1:Params.J,AgeConditionalStats.fractionwithmedicalexpenses.Mean)
title('Life Cycle Profile: Fraction experiencing medical expenses (z==0.3)')
subplot(4,2,2); plot(1:1:Params.J,AgeConditionalStats.assets.Mean)
title('Life Cycle Profile: Assets (a)')
subplot(4,2,4); plot(1:1:Params.J,AgeConditionalStats.pv.Mean)
title('Life Cycle Profile: 1kW PV Shares + 2KWh Battery (pv)')
subplot(4,2,6); plot(1:1:Params.J,AgeConditionalStats.ks.Mean)
title('Life Cycle Profile: KiwiSaver (kw\_balance)')
xlim([1,Params.J])

ACSvec=[AgeConditionalStats];

for ii=1:length(ACSvec)
    clf(2+ii)
    figure(2+ii)
    area(1:1:Params.J, [ACSvec(ii).ks.Mean; ACSvec(ii).pv.Mean*Params.pv_share_price; ACSvec(ii).assets.Mean]);
    title(ACSvec(ii).title)
    legend(ACSvec(ii).legend{:})
    if any(ACSvec(ii).assets.Maximum==asset_grid(end))
        warning(sprintf("assets maxed out ACSvec(%d)", ii));
    end
    if any(ACSvec(ii).pv.Maximum==pv_grid(end))
        warning(sprintf("pv shares maxed out ACSvec(%d)", ii));
    end
    if any(ACSvec(ii).ks.Maximum==ks_grid(end))
        warning(sprintf("ks maxed out ACSvec(%d)", ii));
    end
end

% Notice how we only plot the first part of
% AgeConditionalStats.fractionunemployed.Mean(1:Params.Jr-1), because this
% FnToEvaluate is based on z, which changes meaning between j=Jr-1 and j=Jr.


%% Solve the model again, but without medical shocks, to compare asset profiles
vfoptions_no_medical=vfoptions;
simoptions_no_medical=simoptions;
vfoptions_no_medical.ExogShockFn1=@(agej,Jr) LifeCycleModel21_ExogShockFn1(agej,Jr);
% simoptions_no_medical.ExogShockFn=vfoptions_no_medical.ExogShockFn;

% Continue to use return function, but with appropriate ExogShockFn
% We will evaluate the ExogShockFn at agej=1, just because I want to use
% the stationary distribution as the initial distribution for agents.
[z_gridvals_no_medical_J,pi_z_no_medical_J,statdist_z1_no_medical,vfoptions_no_medical]=Setup_QEA(n_z,z2_grid,pi_z2,Params,vfoptions_no_medical.ExogShockFn1,vfoptions);

[V_no_medical, Policy_no_medical]=ValueFnIter_Case1_FHorz(n_d,n_a,n_z,N_j, d_grid, a_grid, z_gridvals_no_medical_J, pi_z_no_medical_J, ReturnFn, Params, DiscountFactorParamNames, [], vfoptions_no_medical);

%% Initial distribution of agents at birth (j=1)
% Before we plot the life-cycle profiles we have to define how agents are at age j=1. We will give them all zero assets.
jequaloneDist_no_medical=zeros([n_a,n_z],vfoptions.precision,'gpuArray'); % Put no households anywhere on grid
jequaloneDist_no_medical(1,1,1,:,(n_z(2)+1)/2)=statdist_z1_no_medical; % All agents start with zero assets, with z drawn from its stationary distribution

StationaryDist_no_medical=StationaryDist_FHorz_Case1(jequaloneDist_no_medical,AgeWeightsParamNames,Policy_no_medical,n_d,n_a,n_z,N_j,pi_z_no_medical_J,Params,simoptions_no_medical);
AgeConditionalStats_no_medical=LifeCycleProfiles_FHorz_Case1(StationaryDist_no_medical,Policy_no_medical,FnsToEvaluate,Params,[],n_d,n_a,n_z,N_j,d_grid,a_grid,z_gridvals_no_medical_J,simoptions_no_medical);
AgeConditionalStats_no_medical.title="Life Cycle Profile: Assets Allocations No Medical Shocks";
AgeConditionalStats_no_medical.legend={'KiwiSaver Balance (ks)', ...
    'Solar PV Shares (pv)', ...
    'Assets (a)', ...
    'Location','northeast'};

%% Solve the model again, but without unemployment shocks, to compare asset profiles
vfoptions_no_unemployment=vfoptions;
simoptions_no_unemployment=simoptions;
vfoptions_no_unemployment.ExogShockFn1=@(agej,Jr) LifeCycleModel21_ExogShockFn2(agej,Jr);
% simoptions_no_unemployment.ExogShockFn=vfoptions_no_unemployment.ExogShockFn;

[z_gridvals_no_unemployment_J,pi_z_no_unemployment_J,statdist_z1_no_unemployment,vfoptions_no_unemployment]=Setup_QEA(n_z,z2_grid,pi_z2,Params,vfoptions_no_unemployment.ExogShockFn1,vfoptions);

[V_no_unemployment, Policy_no_unemployment]=ValueFnIter_Case1_FHorz(n_d,n_a,n_z,N_j, d_grid, a_grid, z_gridvals_no_unemployment_J, pi_z_no_unemployment_J, ReturnFn, Params, DiscountFactorParamNames, [], vfoptions_no_unemployment);

%% Initial distribution of agents at birth (j=1)
% Before we plot the life-cycle profiles we have to define how agents are at age j=1. We will give them all zero assets.
jequaloneDist_no_unemployment=zeros([n_a,n_z],vfoptions.precision,'gpuArray'); % Put no households anywhere on grid
jequaloneDist_no_unemployment(1,1,1,:,(n_z(2)+1)/2)=statdist_z1_no_unemployment; % All agents start with zero assets, with z drawn from its stationary distribution

StationaryDist_no_unemployment=StationaryDist_FHorz_Case1(jequaloneDist_no_unemployment,AgeWeightsParamNames,Policy_no_unemployment,n_d,n_a,n_z,N_j,pi_z_no_unemployment_J,Params,simoptions_no_unemployment);
AgeConditionalStats_no_unemployment=LifeCycleProfiles_FHorz_Case1(StationaryDist_no_unemployment,Policy_no_unemployment,FnsToEvaluate,Params,[],n_d,n_a,n_z,N_j,d_grid,a_grid,z_gridvals_no_unemployment_J,simoptions_no_unemployment);
AgeConditionalStats_no_unemployment.title="Life Cycle Profile: Assets Allocations No Unemployment Shocks";
AgeConditionalStats_no_unemployment.legend={'KiwiSaver Balance (ks)', ...
    'Solar PV Shares (pv)', ...
    'Assets (a)', ...
    'Location','northeast'};

%% Solve the model again, but without any shocks, to compare asset profiles
vfoptions_no_shocks=vfoptions;
simoptions_no_shocks=simoptions;
vfoptions_no_shocks.ExogShockFn1=@(agej,Jr) LifeCycleModel21_ExogShockFn3(agej,Jr);
% simoptions_no_shocks.ExogShockFn=vfoptions_no_shocks.ExogShockFn;

[z_gridvals_no_shocks_J,pi_z_no_shocks_J,statdist_z1_no_shocks,vfoptions_no_shocks]=Setup_QEA(n_z,z2_grid,pi_z2,Params,vfoptions_no_shocks.ExogShockFn1,vfoptions);

[V_no_shocks, Policy_no_shocks]=ValueFnIter_Case1_FHorz(n_d,n_a,n_z,N_j, d_grid, a_grid, z_gridvals_no_shocks_J, pi_z_no_shocks_J, ReturnFn, Params, DiscountFactorParamNames, [], vfoptions_no_shocks);

%% Initial distribution of agents at birth (j=1)
% Before we plot the life-cycle profiles we have to define how agents are at age j=1. We will give them all zero assets.
jequaloneDist_no_shocks=zeros([n_a,n_z],vfoptions.precision,'gpuArray'); % Put no households anywhere on grid
jequaloneDist_no_shocks(1,1,1,:,(n_z(2)+1)/2)=statdist_z1_no_shocks; % All agents start with zero assets, with z drawn from its stationary distribution

StationaryDist_no_shocks=StationaryDist_FHorz_Case1(jequaloneDist_no_shocks,AgeWeightsParamNames,Policy_no_shocks,n_d,n_a,n_z,N_j,pi_z_no_shocks_J,Params,simoptions_no_shocks);
AgeConditionalStats_no_shocks=LifeCycleProfiles_FHorz_Case1(StationaryDist_no_shocks,Policy_no_shocks,FnsToEvaluate,Params,[],n_d,n_a,n_z,N_j,d_grid,a_grid,z_gridvals_no_shocks_J,simoptions_no_shocks);
AgeConditionalStats_no_shocks.title="Life Cycle Profile: Assets Allocations No Shocks (At All)";
AgeConditionalStats_no_shocks.legend={'KiwiSaver Balance (ks)', ...
    'Solar PV Shares (pv)', ...
    'Assets (a)', ...
    'Location','northeast'};

Params.energy_shock=1.5;

[V_energy_only, Policy_energy_only]=ValueFnIter_Case1_FHorz(n_d,n_a,n_z,N_j, d_grid, a_grid, z_gridvals_no_shocks_J, pi_z_no_shocks_J, ReturnFn, Params, DiscountFactorParamNames, [], vfoptions_no_shocks);

StationaryDist_energy_only=StationaryDist_FHorz_Case1(jequaloneDist_no_shocks,AgeWeightsParamNames,Policy_energy_only,n_d,n_a,n_z,N_j,pi_z_no_shocks_J,Params,simoptions_no_shocks);
AgeConditionalStats_energy_only=LifeCycleProfiles_FHorz_Case1(StationaryDist_energy_only,Policy_energy_only,FnsToEvaluate,Params,[],n_d,n_a,n_z,N_j,d_grid,a_grid,z_gridvals_no_shocks_J,simoptions_no_shocks);
AgeConditionalStats_energy_only.title="Life Cycle Profile: Assets Allocations Energy Only Shocks";
AgeConditionalStats_energy_only.legend={'KiwiSaver Balance (ks)', ...
    'Solar PV Shares (pv)', ...
    'Assets (a)', ...
    'Location','northeast'};


%% Plot the results
ACSvec=[AgeConditionalStats,AgeConditionalStats_no_medical,AgeConditionalStats_no_unemployment,AgeConditionalStats_no_shocks,AgeConditionalStats_energy_only];

clf(2)
figure(2)
hold on
for ii=1:length(ACSvec)
    plot(1:1:Params.J,ACSvec(ii).assets.Mean);
end
title(sprintf("\nLife Cycle Profile: Assets (a)\nParams.rho_z2 = %.3f;\nParams.sigma_epsilon_z2 = %.3f", Params.rho_z2, Params.sigma_epsilon_z2))
legend('Unemployment+Medical Expense Shocks', ...
    'Unemployment but No Medical Shocks', ...
    'Medical but No Unemployment Shocks', ...
    'No Shocks (none at all)', ...
    'Energy Only Shocks', ...
    'Location','northeast');
hold off

for ii=1:length(ACSvec)
    clf(2+ii)
    figure(2+ii)
    area(1:1:Params.J, [ACSvec(ii).ks.Mean; ACSvec(ii).pv.Mean*Params.pv_share_price; ACSvec(ii).assets.Mean]);
    title(ACSvec(ii).title)
    legend(ACSvec(ii).legend{:})
    if any(ACSvec(ii).assets.Maximum==asset_grid(end))
        warning(sprintf("assets maxed out ACSvec(%d)", ii));
    end
    if any(ACSvec(ii).pv.Maximum==pv_grid(end))
        warning(sprintf("pv shares maxed out ACSvec(%d)", ii));
    end
    if any(ACSvec(ii).ks.Maximum==ks_grid(end))
        warning(sprintf("ks maxed out ACSvec(%d)", ii));
    end
end


% Notice that medical expense shocks late in life cause elderly households
% to hold more assets (as self-insurance against medical expense shocks)



function [z_gridvals_J,pi_z_J,statdist_z1,vfoptions]=Setup_QEA(n_z,z2_grid,pi_z2,Params,ExogShockFn,vfoptions)

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
vfoptions.alreadygridvals=1;

% Note, because vfoptions.ExogShockFn exists the values of z1_grid and pi_z1
% are effectively ignored internally by the VFI Toolkit commands.

[mean_z1,~,~,statdist_z1]=MarkovChainMoments(z1_grid_J(:,1),pi_z1_J(:,:,1));

end