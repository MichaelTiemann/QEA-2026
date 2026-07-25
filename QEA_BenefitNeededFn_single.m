%% Calculate benefit needed to meet consumption needs
function benefit=QEA_BenefitNeededFn_single(d,aprime,pvprime,a,pv,ks,z1,z2, ...
    w,agej,Jr,r,kappa_j,pension,ks_employee,energy_shock,pv_share_price)

single_0=single(0); single_1=single(1);
benefit=single_0;
h=d;
ks_out=d;

if aprime>=1 || pvprime>0
    % No benefit if agent has meaningful assets to sell down
    return
elseif agej<Jr && h<0
    return
elseif agej>=Jr && ks>0
    return
end

income=QEA_IncomeFn_single(d,aprime,pvprime,a,pv,ks,z1,z2,w,agej,Jr,pension,r,kappa_j,ks_employee,energy_shock);
expenses=QEA_ExpensesFn_single(d,aprime,pvprime,a,pv,ks,z1,z2,w,agej,Jr,r,kappa_j,energy_shock,pv_share_price);
surplus=income-expenses;

if surplus<=0
    if agej<Jr
        % Scale benefit by labor to favor those who work most
        benefit=0.1*(single_1+h)-surplus;
    else
        benefit=single(0.2)-surplus; % Big sorry to pensioners who cannot afford to live
    end
end

end
