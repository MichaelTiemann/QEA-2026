function F=QEA_ReturnFn(h,aprime,a,z1,z2,w,sigma,psi,eta,agej,Jr,pension,r,kappa_j,wg1,wg2,wg3,beta,sj,energy_shock)
% Is LifeCycleModel8_ReturnFn, but modified to include medical expense
% shocks when retired.

F=-Inf;
if agej<Jr % If working age
    c=w*kappa_j*z1*h+(1+r)*a-aprime; % If unemployed, z1 product will be 0
else % Retirement
    c=pension+(1+r)*a-z1-aprime; % Subtract z1 here
end

% Subtract energy shock costs
c=c-0.3*(z2-1)*energy_shock;

if c>0
    F=(c^(1-sigma))/(1-sigma) -psi*(h^(1+eta))/(1+eta); % The utility function
end

% add the warm glow to the return, but only near end of life
if agej>=Jr+10
    % Warm glow of bequests: bequest are a luxury good
    warmglow=wg1*((1+aprime/wg2)^(1-wg3))/(1-wg3);
    % Modify for beta and sj (get the warm glow next period if die)
    warmglow=beta*(1-sj)*warmglow;
    % add the warm glow to the return
    F=F+warmglow;
end

end
