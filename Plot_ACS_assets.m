function Plot_ACS_assets(ACSvec,asset_grid,pv_grid,ks_grid,Params,fig_start)

if ~exist("fig_start", "var")
    fig_start=10;
end

ACS_mean_max=gather(max(arrayfun(@(x) max(x.ks.Mean+x.assets.Mean+x.leisure_h.Mean+1), ACSvec)));
ACS_mean_min=gather(min(arrayfun(@(x) min(x.assets.Mean), ACSvec)));
ACS_max=gather(max(arrayfun(@(x) max(x.ks.QuantileMeans(Params.Q_max,:)+x.assets.QuantileMeans(Params.Q_max,:)+x.leisure_h.QuantileMeans(Params.Q_max,:)), ACSvec)));
ACS_min=gather(min(arrayfun(@(x) min(x.assets.QuantileMeans(Params.Q_min,:)), ACSvec)));
if isnan(ACS_min)
    ACS_min=ACS_mean_min;
end

legends=cell(length(ACSvec),1);
if ishandle(fig_start)
    clf(fig_start)
end
figure(fig_start)
hold on
for ii=1:length(ACSvec)
    plot(1:1:Params.J,ACSvec(ii).assets.Mean);

    pat='Life Cycle Profile: Assets Allocations ';
    idx = strfind(ACSvec(ii).title,pat);
    if ~isempty(idx)
        result = ACSvec(ii).title(idx(1) + length(pat):end);
        legends(ii)={result};
    else
        legends(ii)={sprintf("Error: Pattern \'%s\' not found",pat)};
    end

    axis([1, length(ACSvec(1).assets.Mean), ACS_mean_min, ACS_mean_max]);
end
title(sprintf("\nLife Cycle Profile: Assets (a)\nParams.rho_z2 = %.3f;\nParams.sigma_epsilon_z2 = %.3f", Params.rho_z2, Params.sigma_epsilon_z2),'Interpreter','none')
legend(legends{:},'Location','northeast','Interpreter','none');
hold off

y_min=min(asset_grid);

for ii=1:length(ACSvec)
    if ishandle(fig_start+ii)
        clf(fig_start+ii)
    end
    figure(fig_start+ii)
    title(ACSvec(ii).title,'Interpreter','none')
    area(1:1:Params.J, [ACSvec(ii).ks.Mean; ACSvec(ii).pv.Mean*Params.pv_share_price; ACSvec(ii).assets.Mean; ACSvec(ii).leisure_h.Mean]', y_min);
    legend(ACSvec(ii).legend{:},'Interpreter','none')
    axis([1, length(ACSvec(1).assets.Mean)+1, ACS_min, ACS_mean_max]);
    if any(ACSvec(ii).assets.QuantileMeans(1,:)==asset_grid(1))
        warning(sprintf("assets (Minimum) hit debt floor ACSvec(%d)", ii));
    end
    if any(ACSvec(ii).assets.Mean==asset_grid(1))
        warning(sprintf("!!!!!! assets (Mean) hit debt floor ACSvec(%d) !!!!!!", ii));
    end
    if any(ACSvec(ii).assets.QuantileMeans(end,:)==asset_grid(end))
        warning(sprintf("assets maxed out ACSvec(%d)", ii));
    end
    if any(ACSvec(ii).pv.QuantileMeans(end,:)==pv_grid(end))
        warning(sprintf("pv shares maxed out ACSvec(%d)", ii));
    end
    if any(ACSvec(ii).ks.QuantileMeans(end,:)==ks_grid(end))
        warning(sprintf("ks maxed out ACSvec(%d)", ii));
    end
    pause(0.1)
end

end
