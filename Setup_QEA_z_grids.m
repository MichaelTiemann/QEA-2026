%% Manually construct z_gridvals_J, pi_z_J, et al using ExogShockFn
function [z_gridvals_J,pi_z_J,statdist_z1,vfoptions,simoptions]=Setup_QEA_z_grids(n_z,z2_grid,pi_z2,Params,ExogShockFn,vfoptions,simoptions)

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
