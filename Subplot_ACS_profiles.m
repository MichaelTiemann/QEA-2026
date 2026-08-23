function Subplot_ACS_profiles(ACSvec, Params, ii, fieldname)
hold on
plot(1:1:Params.J,ACSvec(ii).(fieldname).Mean)
plot(1:1:Params.J,ACSvec(ii).(fieldname).Minimum)
plot(1:1:Params.J,ACSvec(ii).(fieldname).QuantileMeans(Params.Q_min,:))
plot(1:1:Params.J,ACSvec(ii).(fieldname).QuantileMeans(Params.Q_max,:))
plot(1:1:Params.J,ACSvec(ii).(fieldname).Maximum)
hold off

end
