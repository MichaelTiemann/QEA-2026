%% Test ExpAsset

%% Adapted from Life-Cycle Model 21, but without idiosyncratic shocks

%% How does VFI Toolkit think about this?
%
% One decision variables:
%     income, income from labor
% One endogenous state variables:
%     ks, assets (total household savings);
% Age: j

%% Begin setting up to use VFI Toolkit to solve
% Lets model agents from age 20 to age 100, so 81 periods

Params.agejshifter=19; % Age 20 minus one. Makes keeping track of actual age easy in terms of model age
Params.J=100-Params.agejshifter; % =81, Number of period in life-cycle

% Grid sizes to use
n_d=[11]; % Endogenous income choice
n_a=[7]; % Endogenous asset holdings: ks
n_z=0;
N_j=Params.J; % Number of periods in finite horizon

%% Parameters

% Discount rate
Params.beta = 0.96;
% Preferences
Params.sigma = 2; % Coeff of relative risk aversion (curvature of consumption)
Params.eta = 1.5; % Curvature of leisure (This will end up being 1/Frisch elasticity)
Params.psi = 10; % Weight on leisure

% Prices
Params.r=0.05; % Interest rate (0.05 is 5%)

% Demographics
Params.agej=1:1:Params.J; % Is a vector of all the agej: 1,2,3,...,J
Params.Jr=46;

% Start with a mass of one at initial age, use the conditional survival
% probabilities sj to calculate the mass of those who survive to next
% period, repeat. Once done for all ages, normalize to one
Params.mewj=ones(1,Params.J); % Marginal distribution of households over age
Params.mewj=Params.mewj./sum(Params.mewj); % Normalize to one
AgeWeightsParamNames={'mewj'}; % So VFI Toolkit knows which parameter is the mass of agents of each age

% Grid for income choice
d_grid=linspace(0,1,n_d(1))';

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
ks_primeFn=@(income,ks,agej,Jr,r) ks*(1+r)+double(agej<Jr)*(income*0.1)+double(agej>=Jr)*(-0.5); % Will return the value of ks_prime
vfoptions.aprimeFn=ks_primeFn; simoptions.aprimeFn=vfoptions.aprimeFn;
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

% Now use 'QEA_ReturnFn'
ReturnFn=@(income,ks,sigma,psi,eta,agej,Jr,r) ...
    test_ReturnFn(income,ks,sigma,psi,eta,agej,Jr,r);


%% Now, we want to graph Life-Cycle Profiles
% FnsToEvaluate are how we say what we want to graph the life-cycles of
% Like with return function, we have to include (generically, d,aprime,a,z) as first inputs, then just any relevant parameters.
FnsToEvaluate.earnings=@(income,ks) income; % income decision
FnsToEvaluate.ks=@(income,ks) ks; % ks is the current retirement holdings

n_a_values=[13,23,37,53,83,997]

ACSvec=cell(length(n_a_values),1);

for aa=1:length(n_a_values)
    n_a=n_a_values(aa);
    a_grid=linspace(-1,9,n_a(1))';

    simoptions.a_grid=a_grid;

    %% Solve the value function iteration problem with no age-dependent shocks
    disp('Solve for Value fn and Policy fn using ValueFnIter command')
    tic;
    % Because we don't set vfoptions.ExogShockFn (we set ExogShockFn1 to "hide" it), our specially computed z_gridvals_J and pi_z_J are used
    [V, Policy]=ValueFnIter_Case1_FHorz(n_d,n_a,n_z,N_j, d_grid, a_grid, [], [], ReturnFn, Params, DiscountFactorParamNames, [], vfoptions);
    toc

    %% Initial distribution of agents at birth (j=1)
    % Before we plot the life-cycle profiles we have to define how agents are at age j=1. We will give them all zero assets.
    jequaloneDist=zeros(n_a,1,'gpuArray'); % Put no households anywhere on grid
    [~,zero_asset_index]=min(abs(a_grid));
    jequaloneDist(zero_asset_index)=1; % All agents start with zero assets
    
    StationaryDist=StationaryDist_FHorz_Case1(jequaloneDist,AgeWeightsParamNames,Policy,n_d,n_a,n_z,N_j,[],Params,simoptions);

    AgeConditionalStats=LifeCycleProfiles_FHorz_Case1(StationaryDist,Policy,FnsToEvaluate,Params,[],n_d,n_a,n_z,N_j,d_grid,a_grid,[],simoptions);
    AgeConditionalStats.title="Life Cycle Profile: Assets Allocations test";
    AgeConditionalStats.legend={sprintf("KiwiSaver Balance (ks) n\\_a=%d",n_a)};

    ACSvec{aa}=AgeConditionalStats;
end

% Capture resample where we have high-resolution data (n_a is biggest here)
[n_a_2,a_grid_2,simoptions_2]=resample_a_grid_from_StationaryDist(StationaryDist,a_grid,simoptions);

disp('Re-Solve for Value fn and Policy fn using ValueFnIter command with a_grid_2')
tic;
% Because we don't set vfoptions.ExogShockFn (we set ExogShockFn1 to "hide" it), our specially computed z_gridvals_J and pi_z_J are used
[V_2, Policy_2]=ValueFnIter_Case1_FHorz(n_d,n_a_2,n_z,N_j, d_grid, a_grid_2, [], [], ReturnFn, Params, DiscountFactorParamNames, [], vfoptions);
toc

jequaloneDist_2=zeros(n_a_2,1,'gpuArray'); % Put no households anywhere on grid
[~,zero_asset_index_2]=min(abs(a_grid_2));
jequaloneDist_2(zero_asset_index_2)=1; % All agents start with zero assets

StationaryDist_2=StationaryDist_FHorz_Case1(jequaloneDist_2,AgeWeightsParamNames,Policy_2,n_d,n_a_2,n_z,N_j,[],Params,simoptions_2);

AgeConditionalStats_2=LifeCycleProfiles_FHorz_Case1(StationaryDist,Policy,FnsToEvaluate,Params,[],n_d,n_a,n_z,N_j,d_grid,a_grid,[],simoptions);
AgeConditionalStats_2.title="Life Cycle Profile: Assets Allocations test";
AgeConditionalStats_2.legend={sprintf("KiwiSaver Balance (ks) n\\_a=%d",n_a)};

stride=2;
ACSvec_other=cell(ceil(length(n_a_values)/stride),3);

% Look at other ways to distribute points in a_grid
for bb=1:3
    for aa=1:stride:length(n_a_values)
        n_a=n_a_values(aa);
        switch bb
            case 1
                a_grid=[-0.6,-0.4,-0.2, exp(linspace(-3,log(3.7),n_a(1)-3))+linspace(-exp(-3),4.5,n_a(1)-3)]';
            case 2
                a_grid=unique([-0.6,-0.4,-0.2, 8-exp(linspace(0,log(3.7),n_a(1)-3))-linspace(-exp(-3),4.5,n_a(1)-3)])';
            case 3
                a_grid=unique([-0.6,-0.3, exp(linspace(-3,log(3.7),ceil(n_a(1)/2)-1))+linspace(-exp(-3),4.5,ceil(n_a(1)/2)-1),9-exp(linspace(0,log(4.5),ceil(n_a(1)/2)-1))-linspace(0,4.5,ceil(n_a(1)/2)-1)])';
        end
    
        simoptions.a_grid=a_grid;
    
        %% Solve the value function iteration problem with no age-dependent shocks
        disp('Solve for Value fn and Policy fn using ValueFnIter command')
        tic;
        % Because we don't set vfoptions.ExogShockFn (we set ExogShockFn1 to "hide" it), our specially computed z_gridvals_J and pi_z_J are used
        [V, Policy]=ValueFnIter_Case1_FHorz(n_d,n_a,n_z,N_j, d_grid, a_grid, [], [], ReturnFn, Params, DiscountFactorParamNames, [], vfoptions);
        toc
    
        %% Initial distribution of agents at birth (j=1)
        % Before we plot the life-cycle profiles we have to define how agents are at age j=1. We will give them all zero assets.
        jequaloneDist=zeros(n_a,1,'gpuArray'); % Put no households anywhere on grid
        [~,zero_asset_index]=min(abs(a_grid));
        jequaloneDist(zero_asset_index)=1; % All agents start with zero assets
    
        StationaryDist=StationaryDist_FHorz_Case1(jequaloneDist,AgeWeightsParamNames,Policy,n_d,n_a,n_z,N_j,[],Params,simoptions);
    
        AgeConditionalStats=LifeCycleProfiles_FHorz_Case1(StationaryDist,Policy,FnsToEvaluate,Params,[],n_d,n_a,n_z,N_j,d_grid,a_grid,[],simoptions);
        AgeConditionalStats.title="Life Cycle Profile: Assets Allocations test";
        AgeConditionalStats.legend={sprintf("method %d (ks) n\\_a=%d",bb,n_a)};
    
        ACSvec_other{(aa-1)/stride+1,bb}=AgeConditionalStats;
    
    end
end

% save('cyclingbug.mat','ACSvec','Params');

%% Plot the results

Plot_ACS_assets(ACSvec,ACSvec_other,AgeConditionalStats_2,Params,10);

function Plot_ACS_assets(ACSvec,ACSvec_other,AgeConditionalStats_2,Params,figure_start)

if ~exist("figure_start", "var")
    figure_start=10;
end

ACS_mean_max=gather(max(cellfun(@(x) max(x.ks.Mean), ACSvec)));
ACS_mean_min=gather(min(cellfun(@(x) max(x.ks.Mean), ACSvec)));
ACS_max=gather(max(cellfun(@(x) max(x.ks.Maximum), ACSvec)));
ACS_min=gather(min(cellfun(@(x) min(x.ks.Minimum), ACSvec)));

legends=cell(3*size(ACSvec,1),1);
legends_other=cell([3,1].*size(ACSvec_other));

if ishandle(figure_start)
    clf(figure_start)
end
figure(figure_start);
% First axes
ax1 = axes;
ylabel(ax1,'Y1 (Blue)');
ax1.ColorOrderIndex=1;

hold(ax1, 'on')
for aa=1:size(ACSvec,1)
    plot(ax1,1:1:Params.J,ACSvec{aa}.ks.Mean,'-d');
    legends(3*(aa-1)+1)={ACSvec{aa}.legend{1}};
    % plot(ax1,1:1:Params.J,ACSvec{ii}.ks.QuantileMeans(1,:));
    % legends(3*(ii-1)+2)={strcat(ACSvec{ii}.legend{1}, " Q(1)")};
    % plot(ax1,1:1:Params.J,ACSvec{ii}.ks.QuantileMeans(20,:));
    % legends(3*(ii-1)+3)={strcat(ACSvec{ii}.legend{1}, " Q(20)")};
end
legends={legends(~cellfun('isempty', legends))};
legend(ax1,legends{:},'Location','northeast');

linestyles={'-s','-o','-*'};

for bb=1:size(ACSvec_other,2)
    legends_other=cell([3,1].*size(ACSvec_other));
    if ishandle(figure_start+bb)
        clf(figure_start+bb)
    end
    figure(figure_start+bb);
    % Second axes (placed directly on top)
    ax2 = axes('Position', ax1.Position, 'Color', 'none', ...
        'XAxisLocation', 'top', 'YAxisLocation', 'right');
    ax2.ColorOrderIndex=1;
    ylabel(ax2,'Y2 (Red)');
    ax2.XAxis.Visible = 'off'; % Hide duplicate x-axis labels
    ax2.XLim=ax1.XLim; ax2.YLim=ax1.YLim;
    hold(ax2, 'on')
    for aa=1:size(ACSvec_other,1)
        plot(ax2,1:1:Params.J,ACSvec_other{aa,bb}.ks.Mean,linestyles{bb});
        % ax2.ColorOrderIndex=mod(ax2.ColorOrderIndex+stride-2,size(ax2.ColorOrder,1))+1;
        legends_other(3*(aa-1)+1,bb)={ACSvec_other{aa,bb}.legend{1}};
        % plot(1:1:Params.J,ACSvec{ii}.ks.QuantileMeans(1,:));
        % plot(1:1:Params.J,ACSvec{ii}.ks.QuantileMeans(20,:));
    end
    ax2.ColorOrderIndex=1;
    ax2.ColorOrderIndex=size(ax2.ColorOrder,1);
    plot(ax2,1:1:Params.J,AgeConditionalStats_2.ks.Mean, '-p');
    legends_other=[legends_other(~cellfun('isempty', legends_other)); {sprintf("resampled (ks) pentagram")}];
    legend(ax2,legends_other{:},'Location','northwest');
end

hold(ax2,'off')
hold(ax1,'off')

end


function [n_a_new,a_grid_new,simoptions_new]=resample_a_grid_from_StationaryDist(StationaryDist,a_grid,simoptions)
%% Recompute an a_grid so that it produces meaningful Maximum and Minimum statistics
% In the normal course of events, grid interpolation errors will overwhelm
% Maximum/Minimum statistics that come from evaluating z and e probabilities
% This function creates a grid based on found Mean values, so that Maximum and Minimum can accurately report.

max_j=size(StationaryDist,2);
a_grid_new=zeros(1,max_j+2);
% indexes_prior=find(StationaryDist(:,1));
for jj=2:max_j
    indexes=find(StationaryDist(:,jj));
    indexes_length=length(indexes);
    [maxval,maxindex]=max(StationaryDist(indexes,jj));
    if any(diff(StationaryDist(indexes(1:maxindex),jj)<0)) || any(diff(StationaryDist(indexes(maxindex:end),jj)>0))
       error("probability split detected");
    end
    ax=sum(StationaryDist(indexes,jj).*indexes)/sum(StationaryDist(indexes,jj));
    ax_lower=floor(ax);
    ax_upper=ceil(ax);
    if ax_lower<1
        warning("ax underflow");
        ax_lower=1;
    end
    if ax_upper>length(a_grid)
        warning("ax overflow");
        ax_upper=length(a_grid);
    end
    a_grid_new(jj)=a_grid(ax_lower)+(a_grid(ax_upper)-a_grid(ax_lower))*(ax-ax_lower);
    % indexes_prior=indexes;
end

% Add some extra headroom to our grid (often lost due to rounding errors)
max_new=max(a_grid_new(1:max_j));
min_new=min(a_grid_new(1:max_j));
if max_new>0
    a_grid_new(max_j+1)=max_new*1.2;
else
    a_grid_new(max_j+1)=max_new*0.8;
end
min_new=min(a_grid_new);
if min(a_grid_new)<0
    a_grid_new(max_j+2)=min_new*1.2;
else
    a_grid_new(max_j+2)=min_new*0.8;
end

a_grid_new=unique(a_grid_new)';
simoptions_new=simoptions;
simoptions_new.a_grid=a_grid_new;
n_a_new=length(a_grid_new);
fprintf("a_grid(%d) -> a_grid_new(%d)\n", length(a_grid), length(a_grid_new));
end
