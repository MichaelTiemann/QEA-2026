function ks_prime=QEA_ksprimeFn(h,ks_out,ks,z1,z2,w,agej,Jr,ks_r,ks_employee,ks_employer,kappa_j)

ks_growth=ks*ks_r;
if agej<Jr % If working age, calculate contributions
    ks_income=w*kappa_j*z1*h;
    ks_prime=ks+ks_growth+ks_income*(ks_employee+ks_employer);
else % Retirement, redeem ks as needed
    ks_prime=(ks+ks_growth)*(single(1)-ks_out);
end

end
