%% Comparison Validation
% call estimate_w0 for any design to compare

clear;
close all;
clc;

g = 9.8;
tol = 1e-5;

%% Our Initial Design Estimations

d = struct();
d.g = g; d.tol = tol;
d.num_passengers = 8; % 7 pax + 1 pilot
d.passenger_mass = 86.1826; % kg
d.baggage_mass = 13.6078; % kg/person
d.num_motors = 6;
d.motor_mass_each = 50; % kg, Siemens SP70D-class
d.W1_W0 = .992; d.W2_W1 = .996; d.W3_W2 = .996; d.W4_W3 = .990;
d.W6_W5 = 1; d.W8_W7 = .992; d.W9_W8 = .992;
d.L_D = 11; d.cp = .4; d.prop_efficiency = .85;
d.R_fuel = 200; % nmi, fuel-burning cruise leg
d.R_electric = 250 * 1852; % m, electric cruise leg + climb margin
d.R_reserve  = 225 * .75; % nmi, 45 min @ 225 kt
d.batt_efficiency = .96;
d.eb_star = 400 * 3600; % J/kg  (400 Wh/kg)
d.A = 1.4; 
d.C = -.10;
d.W0_guess = 25000; % N, starting guess
 
res_design = estimate_w0(d);

%% NASA X-57 MAxwell
% fully electric, converted Tecnam P2006T airframe

% never flew real payload/range mission and is a 1 pilot testbed
% R_fuel/R_electric are guesstimations

x = struct();
x.g = g; x.tol = tol;
x.num_passengers = 1;  % pilot only, not a payload mission
x.passenger_mass = 86.1826;
x.baggage_mass = 0;
x.num_motors = 1;
x.motor_mass_each = (117 + 12*15) / 2.205; % total. lb to kg (~135 kg)
x.W1_W0 = 1; x.W2_W1 = 1; x.W3_W2 = 1; x.W4_W3 = 1; % no fuel leg bc fully electric
x.W6_W5 = 1; x.W8_W7 = 1; x.W9_W8 = 1; 
x.L_D = 11; % twin turbo prop estimate
x.cp = .4; x.prop_efficiency = .85; % unused since R_fuel = 0
x.R_fuel = 0; % no fuel leg bc fully electric
x.R_electric = 100 * 1852; % nmi guesstimation mission range
x.R_reserve = 0;
x.batt_efficiency = .96;
x.eb_star = 177 * 3600; % J/kg pack specific energy
x.A = 1.4; x.C = -.10; % Raymer twin-prop constants
x.W0_guess = 13000; % N
 
res_x57 = estimate_w0(x);
actual_x57_kg = 3000 / 2.205; % lb -> kg
 

%% Electra EL-2 GoldFinch or Other ?

%% Print Comparison

fprintf('\n Our Aircraft Design \n');
fprintf('W0 = %.0f kg | WE = %.0f kg | WF = %.0f kg | Battery = %.0f kg\n', ...
    res_design.W0_kg, res_design.WE_kg, res_design.WF_kg, res_design.mass_battery_kg);
 
fprintf('\n NASA X-57 Maxwell (Mod IV) \n');
fprintf('Model W0  = %.0f kg\n', res_x57.W0_kg);
fprintf('Actual W0 = %.0f kg (NASA fact sheet, ~3,000 lb)\n', actual_x57_kg);
fprintf('Model %% error = %.1f%%\n', 100*(res_x57.W0_kg - actual_x57_kg)/actual_x57_kg);
fprintf('Model battery mass = %.0f kg; Actual battery mass = %.0f kg (860 lb)\n', ...
    res_x57.mass_battery_kg, 860/2.205);
 