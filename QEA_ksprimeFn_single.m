function ks_prime=QEA_ksprimeFn_single(d,ks,z1,z2,w,agej,Jr,ks_r,ks_employee,ks_employer,kappa_j)

h=d;
ks_out=d;

ks_growth=ks*ks_r;
if agej<Jr % If working age, calculate contributions
    ks_income=w*kappa_j*z1*h;
    ks_prime=ks+ks_growth+ks_income*(ks_employee+ks_employer);
else % Retirement, redeem ks as needed
    if ks_out>0.5
        ks_prime=single(-Inf);
    else
        ks_prime=(ks+ks_growth)*(single(1)-ks_out);
    end
end

end
