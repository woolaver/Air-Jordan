%% run_check.m - runs the Air Jordan design loop and prints the converged design
% Put this file in the Air-Jordan-main folder and type  run_check  in the MATLAB command window.
% Needs: MATLAB + Aerospace Toolbox (atmoscoesa). Run time: a few minutes (field simulations in every pass).

updatedAircraftDesignDriver;              % full driver: loop, emissions, cost, plots
a = aircraft_final;  W = Wimproved;       % converged design (the legacy P-S block afterwards overwrites "aircraft")

fprintf('\n================ Air Jordan converged design ================\n');
fprintf('MTOW              %8.0f lb      (expected 13,624)\n', a.W0);
fprintf('Wing area / span  %8.1f ft^2 / %5.1f ft   (625 / 75.0)\n', a.wing_area, sqrt(a.AR*a.wing_area));
fprintf('W/S               %8.2f lb/ft^2 (21.8)\n', a.W0/a.wing_area);
fprintf('Installed power   %8.0f hp      (2,897; constraints need %.0f)\n', P_final, a.P_W*a.W0);
fprintf('Take-off / landing over 50 ft  %5.0f / %5.0f ft   (289 / 254, RFP 300)\n', takeoff_distance, landing_distance);
fprintf('Approach path     %8.1f deg     (-13.1)\n', a.gamma_app);
fprintf('Battery           %8.0f lb, %5.0f kWh usable (3,884 lb, 729 kWh)\n', W.battery_weight, a.E_batt);
fprintf('Fuel              %8.0f lb (trip %.0f + reserve %.0f)   (1,009 = 645 + 364)\n', W.fuel_weight, a.Wf_trip, a.Wf_reserve);
fprintf('Tails HT / VT     %8.1f / %5.1f ft^2   (185 / 42)\n', a.horiz_area, a.vert_area);
fprintf('CD0 / cruise L/D  %8.4f / %5.2f   (0.0258 / 12.37)\n', a.CD0_clean, a.L_D);
fprintf('Tail strike / tip-back  %5.1f / %5.1f deg   (21.6 / 20.8)\n', a.th_tailstrike, a.tipback);
fprintf('DOC per trip      %8.0f $       (3,167)\n', c.DOC);
fprintf('\nComponent weights [lb]\n');
f = fieldnames(W);
for k = 1:numel(f), v = W.(f{k}); if isnumeric(v) && isscalar(v), fprintf('  %-26s %8.0f\n', f{k}, v); end, end
