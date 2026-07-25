%% Test ExpAsset

%% Simplest possible(?) ExpAsset test


%% How does VFI Toolkit think about this?
%
% One endogenous state variable: ea;
% Age: j

%% Begin setting up to use VFI Toolkit to solve

Params.J=21; % Number of period in life-cycle

% Grid sizes to use
n_d=1; % Endogenous income choice
n_a=16; % Endogenous asset holdings: ea
n_z=0;
N_j=Params.J; % Number of periods in finite horizon

%% Parameters

% Discount rate
Params.beta = 0.9;

% Demographics
Params.agej=1:1:Params.J; % Is a vector of all the agej: 1,2,3,...,J
Params.mewj=ones(1,Params.J); % Marginal distribution of households over age
Params.mewj=Params.mewj./sum(Params.mewj); % Normalize to one
AgeWeightsParamNames={'mewj'}; % So VFI Toolkit knows which parameter is the mass of agents of each age

% Grid for income choice
d_grid=0;

a_grid=(0:1:15)';

z_grid=[];

% tell the code how many d1, d2, and d3 there are
% Idea is to distinguish three categories of decision variable:
%  d1: decision is in the ReturnFn but not in aprimeFn
%  d2: decision is in the aprimeFn but not in ReturnFn
%  d3: decision is in both ReturnFn and in aprimeFn
% Note: ReturnFn must use inputs (d1,d3,..) 
%       aprimeFn must use inputs (d2,d3,..)
% n_d must be set up as n_d=[n_d1, n_d2, n_d3]
% d_grid must be set up as d_grid=[d1_grid; d2_grid; d3_grid];
vfoptions.experienceasset=1; simoptions.experienceasset=vfoptions.experienceasset;

% a_grid is set up below

%% Define aprime function for KiwiSaver
aprimeFn=@(d,ea,agej) (agej<11)*(ea+0.2) + (agej>=11)*(ea*0.9); % Will return the value of aprime
vfoptions.aprimeFn=aprimeFn; simoptions.aprimeFn=vfoptions.aprimeFn;
simoptions.d_grid=d_grid;
% 1st element: mean
% 2nd element: median
% 3rd element: std dev and variance
% 4th element: lorenz curve and gini coefficient
% 5th element: min/max
% 6th element: quantiles
% 7th element: More Inequality
simoptions.whichstats=[1,1,1,0,1,1,0];

%% Create the return function
DiscountFactorParamNames={'beta'};

% Now use 'ea_ReturnFn'
ReturnFn=@(d2,ea) ea_ReturnFn(d2,ea);


%% Now, we want to graph Life-Cycle Profiles
% FnsToEvaluate are how we say what we want to graph the life-cycles of
% Like with return function, we have to include (generically, d,aprime,a,z) as first inputs, then just any relevant parameters.
FnsToEvaluate.ea=@(d,ea,agej) ea; % ks is the current retirement holdings

simoptions.a_grid=a_grid;

%% Solve the value function iteration problem with no age-dependent shocks
disp('Solve for Value fn and Policy fn using ValueFnIter command')
tic;
% Because we don't set vfoptions.ExogShockFn (we set ExogShockFn1 to "hide" it), our specially computed z_gridvals_J and pi_z_J are used
[V, Policy]=ValueFnIter_Case1_FHorz(n_d,n_a,n_z,N_j, d_grid, a_grid, [], [], ReturnFn, Params, DiscountFactorParamNames,[], vfoptions);
toc

%% Initial distribution of agents at birth (j=1)
% Before we plot the life-cycle profiles we have to define how agents are at age j=1. We will give them all zero assets.
jequaloneDist=zeros(n_a,1,'gpuArray'); % Put no households anywhere on grid
jequaloneDist(1)=1; % All agents start with asset value of 0 (at index 1)

StationaryDist=StationaryDist_FHorz_Case1(jequaloneDist,AgeWeightsParamNames,Policy,n_d,n_a,n_z,N_j,[],Params,simoptions);

AgeConditionalStats=LifeCycleProfiles_FHorz_Case1(StationaryDist,Policy,FnsToEvaluate,Params,[],n_d,n_a,n_z,N_j,d_grid,a_grid,[],simoptions);
AgeConditionalStats.title="ea test";

if ishandle(1)
    clf(1)
end
figure(1)
hold on
plot(1:1:Params.J,AgeConditionalStats.ea.Mean)
plot(1:1:Params.J,AgeConditionalStats.ea.Maximum)
plot(1:1:Params.J,AgeConditionalStats.ea.Minimum)
hold off

function F=ea_ReturnFn(d2,ea)

F=ea;

end
