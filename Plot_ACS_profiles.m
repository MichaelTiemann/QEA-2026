function Plot_ACS_profiles(ACSvec, Params, fig_start)
for ii=1:length(ACSvec)
    if ishandle(fig_start+ii)
        clf(fig_start+ii)
    end
    figure(fig_start+ii)
    title(ACSvec(ii).title,'Interpreter','none')
    subplot(4,2,1); Subplot_ACS_profiles(ACSvec, Params, ii, 'fractiontimeworked');
    title('Life Cycle Profile: Fraction Time Worked (h)','Interpreter','none')
    subplot(4,2,3); Subplot_ACS_profiles(ACSvec, Params, ii, 'earnings');
    title('Life Cycle Profile: Labor Earnings (w kappa_j z h)','Interpreter','none')
    subplot(4,2,5); plot(1:1:Params.J,[ACSvec(ii).fractionunemployed.Mean(1:Params.Jr-1),zeros(1,Params.J-Params.Jr+1)])
    title('Life Cycle Profile: Fraction Unemployment (z==0)','Interpreter','none')
    subplot(4,2,7); plot(1:1:Params.J,ACSvec(ii).fractionwithmedicalexpenses.Mean)
    title('Life Cycle Profile: Fraction experiencing medical expenses (z==0.3)','Interpreter','none')
    subplot(4,2,2); Subplot_ACS_profiles(ACSvec, Params, ii, 'assets');
    title('Life Cycle Profile: Assets (a)','Interpreter','none')
    subplot(4,2,4); Subplot_ACS_profiles(ACSvec, Params, ii, 'pv');
    title('Life Cycle Profile: 1kW PV Shares + 2KWh Battery (pv)','Interpreter','none')
    subplot(4,2,6); Subplot_ACS_profiles(ACSvec, Params, ii, 'ks');
    title('Life Cycle Profile: KiwiSaver (kw_balance)','Interpreter','none')
    subplot(4,2,8); Subplot_ACS_profiles(ACSvec, Params, ii, 'leisure_h');
    title('Life Cycle Profile: Leisure (leisure_h function)','Interpreter','none')
    xlim([1,Params.J])
end

end
