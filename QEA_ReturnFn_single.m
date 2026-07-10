function F=QEA_ReturnFn_single(d,aprime,pvprime,a,pv,ks,z1,z2,w,sigma,psi,eta,agej,Jr,pension,r,ks_employee,kappa_j,wg1,wg2,wg3,beta,sj,energy_shock,pv_share_price)
% Is LifeCycleModel8_ReturnFn, but modified to include medical expense
% shocks when retired.

F=single(-Inf);
single_0=single(0); single_1=single(1); single_5=single(5);
h=d;
ks_out=d;

if agej<Jr
    if aprime<0 && pvprime>pv % Can't buy PVs using debt
        return
    end
else
    % We don't explicitly prohibit debt at retirement
    % Instead, we disfavor it and hope those who don't need it show the way
    % if aprime+ks+50<0
    %     return
    % end
end

housing=398*kappa_j; % housing scales with income
utilities=single(80);
food=single(300);
% transport=single(252);
transport_fuel=single(150);
transport_nonfuel=single(252)-transport_fuel;
taxes=single_0; % only pay taxes when employed
discretionary=518*kappa_j; % discretionary scales with income;
w_factor=single(1/2668); % unscaled weekly average gross wages

if agej<Jr % If working age
    employment_factor=(z1+single_1)*0.5; % full rate at full employment; half-rate when unemployed
    income=w*kappa_j*z1*h; % If unemployed, z1 product will be 0
    taxes=income*591*w_factor; % taxes scale with income
    % Kiwisaver takes 5% out of income
    c=income*(single_1-ks_employee);
else % Retirement
    employment_factor=single(0.9); % Retirees less active?
    c=pension+ks_out*ks-z1; % Subtract z1 (medical expenses) here
end
if a>=0
    % Positive assets pay r interest rate
    c=c+(single_1+r)*a-aprime;
elseif agej==Jr && aprime==0
    % Jubilee !!  Unmployment debts forgiven at Jr
    c=c+single_1;
else
    % Negative assets pay 2*r loan rate
    c=c+(single_1+2*r)*a-aprime;
end
if c<=0 && agej<Jr % Early out if cannot meet minimal consumption constraint
    % When unemployed and without debt, c==0 is possible
    % By prohibiting c==0, we force the unemployed to take on debt
    % If this leads to overall infeasibility for one agent, all are affected
    % If c<0 for all labor/debt choices of any agent at this point, we quit
    return
end


%% All agents in this peel have either debt, income, or assets sufficient to proceed
% We now compute core living expenses to deduct from consumption; convert kiwi stats to model units
nongrid_expenses=housing+food+(transport_nonfuel+discretionary)*employment_factor+taxes;
grid_budget=utilities+transport_fuel*employment_factor;
% Calculate energy expense/income/investment
grid_expenses=grid_budget*(energy_shock*z2+single(~energy_shock));
if pv>single_5
    % grid_income is 1/2 the cost rate once above self-sufficient 5kW+10kWh system
    grid_income=grid_budget*(max(single_1,energy_shock*z2))*(pv-single_5)/10;
    grid_expenses=single_0;
else
    grid_income=single_0;
    grid_expenses=grid_expenses*(single_1-pv/single_5);
end
total_expenses=nongrid_expenses+grid_expenses;
pv_investment=w*(pvprime-pv)*pv_share_price;
c=c+(grid_income-total_expenses)*w_factor-pv_investment;
% Should leave about $529/week for further consumption/investment

if aprime<0
    if c+aprime>0 % No new debt for extra consumption
        % There is a less negative aprime that should suffice
        return
    elseif agej<Jr && h<0.6 % No debt if not trying to hustle
        % Note that if unemployed, one can still offer hours, even if they don't count
        % This just narrows the field of F evaluations, saving GPU cycles
        return
    end
end

if c>0
    F=(c^(single_1-sigma))/(single_1-sigma) -psi*(h^(single_1+eta))/(single_1+eta); % The utility function
    if aprime<0
        F=F*1e-3+aprime*1e4; % Trivialize calculated F and disfavor debt so we used the least of it possible
    end
else
    % Disfavor a technically infeasible solution.
    % If there is a c>0 for all agents within this peel, it will be selected instead
    % If not, this disfavored result will be probability-weighted with
    % other results (some of which may achieve c>0)
    % If we are at the bitter end of bad luck, our small probability will
    % not weigh much against the successful mainstream agent population
    F=(c-single_1)*1e3;
    if aprime<0
        F=F+aprime*1e5; % Augment disfavored F and further disfavor debt so we used the least of it possible
    end
end


% add the warm glow to the return, but only near end of life, and only with positive net worth
networth_prime=aprime+ks*(single_1-ks_out);
if agej-Jr>=10 && networth_prime>0
    % Warm glow of bequests: bequest are a luxury good
    warmglow=wg1*((single_1+networth_prime/wg2)^(single_1-wg3))/(single_1-wg3);
    % Modify for beta and sj (get the warm glow next period if die)
    warmglow=beta*(single_1-sj)*warmglow;
    % add the warm glow to the return
    F=F+warmglow;
end

end
