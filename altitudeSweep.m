% altitudeSweep.m -- MTOW, battery, fuel and L/D vs cruise altitude (+ pressurization)

alts        = [10 15 20 25 30]*1000;   % ft
alt_press   = 12500;                   % ft, above this the cabin is pressurized
Np          = 8;                       % pax
V_pr        = 374 + 187 + 93;          % ft^3, cabin + cockpit + baggage (fuselage.md)
W_av        = 300;                     % lb, uninstalled avionics (ASSUMED)
f_fus_press = 0.12;                    % +12% fuselage structure for pressurization (ASSUMED)
P_hp        = 1765;                    % installed power used by the weight code

W_ECS  = 63.36*Np^0.25*(V_pr/1000)^0.604*W_av^0.1;
res = nan(numel(alts), 7);   % alt, MTOW, battery, fuel, L/D, W_press, W/S

for k = 1:numel(alts)
    clear aircraft
    aircraft = aircraft();
    aircraft.alt_cr = alts(k);
    if alts(k) > alt_press
        aircraft.W_pressurization = W_ECS + f_fus_press*1.4*aircraft.S_fuselage;
    else
        aircraft.W_pressurization = 0;
    end
    W = supermegadetailedweightestimation(aircraft.W0, P_hp, aircraft);
    [~, ~, LD] = fuel_fraction_calc_refined(P_hp, W.MTOW, aircraft);   % L/D the code actually used
    res(k,:) = [alts(k), W.MTOW, W.battery_weight, W.fuel_weight, LD, ...
                aircraft.W_pressurization, W.MTOW/aircraft.wing_area];
end

T = array2table(res, 'VariableNames', {'alt_ft','MTOW_lb','MainBattery_lb','Fuel_lb', ...
                                       'L_D','W_press_lb','W_S'});
disp(T)
writetable(T, 'altitude_sweep.csv');

figure;
subplot(2,1,1); hold on; grid on
plot(alts/1000, res(:,2), 'o-', 'LineWidth', 1.5)
plot(alts/1000, res(:,3), 's-', 'LineWidth', 1.5)
plot(alts/1000, res(:,4), 'd-', 'LineWidth', 1.5)
xline(alt_press/1000, 'k:', 'pressurized above');
ylabel('Weight (lb)'); legend('MTOW','Main battery','Fuel','Location','best')
title('Cruise altitude trade (225 kt TAS, 200 nmi fuel + 200 nmi electric)')
subplot(2,1,2); grid on
plot(alts/1000, res(:,5), 'o-', 'LineWidth', 1.5)
xlabel('Cruise altitude (kft)'); ylabel('Cruise L/D')
