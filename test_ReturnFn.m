function F=test_ReturnFn(income,ks,sigma,psi,eta,agej,Jr,r)

F=-Inf;
single_1=1;

if agej<Jr
    c=double(income==0.5);
else
    c=0.1;
end


if c>0
    F=(c^(single_1-sigma))/(single_1-sigma) -psi*(income^(single_1+eta))/(single_1+eta); % The utility function
else
    F=(c-1)*1e3;
end

end
