function ks_prime=QEA_ksprimeFn(h,ks_out,ks_balance,z1,z2,w,agej,Jr,ks_r,ks_employee,ks_employer,kappa_j)

ks_growth=ks_balance*ks_r;
if agej<Jr % If working age, so calculate contributions
    ks_income=w*kappa_j*z1*h;
    ks_prime=ks_balance+ks_growth+ks_income*(ks_employee+ks_employer);
else % Retirement
    ks_prime=(ks_balance+ks_growth)*(single(1)-ks_out);
end

end
