%Driver function to run all aircraft design functions
% CORRECTED (Oct 21 2026): P-S section uses PS_constraintcurves_corrected and
% weightIterationEstimate_corrected with ONE consistent set of inputs (search "FIX").
% weight_Estimate_Iteration_old, preliminary_Sizing, fuel_fraction_calc and aircraftcost
% are unchanged team files. In fuel_fraction_calc.m replace the Swet regression by
% wetted_area_corrected(W0, S, p) so cruise L/D also sees the wing area.

%% Weight Estimation

clear
close all
clc

%PUT UNITS ON EVERYTHING
%LABEL ALL ASSUMPTIONS WITH WHERE YOU GOT IT FROM

%estimated 10 electric motors driving 6 propellers, see Assignment 4 report
%for justification
electric_system_mass = 10*32.5 + 500; %kg

%L/D estimate from drag polar estimate using Roskam's estimations
L_D = 11.8746;

%specific fuel consumption of general aviation piston engine
cp = .4; %lb/(hp*h)
prop_efficiency = .8;

%electric cruise range calculation for battery mass sizing
e_range = 200; %nmi, additional 25nmi added for takeoff and climb
batt_efficiency = .96; %conservative estimate from slides

%Justification for 400 Wh/kg batteries
%Likely, airborne batteries will natively belong to Generation-4 solid-state since their market inception, 
% with gravimetric energy density at cell level starting at 400 Wh/kg, 
% and possibly achieving the 750 Wh/kg mark by 2035 (Kühnelt et al. 2023).
eb_star = 500*3600; %500 Wh/kg from estimate converted to SI units J/kg

battery_degradation = .9;

disp('WEIGHT ESTIMATION:')

%returns W0 in kg, Wcr_W0 is cruise weight fraction assuming fuel cruise is
%before electric cruise, Wl_W0 is landing weight fraciton
[W0, Wcr_W0, Wland_W0, Wclimb_W0, Wce_W0, Wto_W0] = weight_Estimate_Iteration_old(electric_system_mass, L_D, cp, prop_efficiency, e_range, batt_efficiency, eb_star, battery_degradation);

disp('--------------------------------------')
%% Preliminary Sizing

AR = 11;
%W_S = 16; %used for CD0 estimate only, coming from blown wing analysis
W_S = 16;

% Raymer's estimations for Cf, using twin engine small aircraft
Cf_clean = .0045;

%estimate CLmax for different configurations
%CLmax_clean also from x-57 they got 1.7 for unblown cruise wing, we will
%probably have higher but we'll go with this for right now, climb doesn't
%seem to be a limiting factor anyway
CLmax_clean = 1.5;
%CLmax_to comes from NASA x-57 estimation, they got ~4.5 we can push it to
%5
%https://ntrs.nasa.gov/api/citations/20170005883/downloads/20170005883.pdf
CLmax_to = 10;

CLmax_climb = 3.472;

% 6 electric engine, one combustion engine 
Neng = 7;

%just an estimation from Adam, will need a way to calculate this or a
%better estimate
Pcr_P0 = .8;

%assuming unpressurized for now, may want to pressurize later but for how
%short our flight time is climbing to high altitudes will probably not be
%worth it
alt_cr = 12500; %feet

design_margin = .025; % 2.5% margin on P/W, W/S design point

[W_S_point, P_W_point] = preliminary_Sizing(W0, AR, W_S, Cf_clean, CLmax_clean, CLmax_to, CLmax_climb, prop_efficiency, Wcr_W0, Wclimb_W0, Wce_W0, Wland_W0, Wto_W0, Pcr_P0, Neng, alt_cr, design_margin);

disp("W/S Design Point: " + W_S_point)
disp("P/W Design Point: " + P_W_point)
disp("W/P Design Point: " + 1/P_W_point)

disp('--------------------------------------')



%% P-S Plot Conversion
design_margin = 1.025;

p = struct('AR',AR,'Cf_clean',Cf_clean,'CLmax_to',CLmax_to, ...
    'prop_efficiency',prop_efficiency,'Wcr_W0',Wcr_W0,'Wclimb_W0',Wclimb_W0, ...
    'Wce_W0',Wce_W0,'Wland_W0',Wland_W0,'Pcr_P0',Pcr_P0,'Neng',Neng,'alt_cr',alt_cr, 'design_margin', design_margin);

% FIX: one landing C_L for every constraint (PS_constraintcurves used a local 5)
p.CLmax_ld      = CLmax_to;      % blown C_L,max in landing configuration (same assumption as take-off)
% FIX: landing model for powered lift: W/S <= 0.5 rho V_S,max^2 C_L,max,ld
p.landing_model = 'blown';       % 'raymer' = old conventional estimate (with S_a, without 0.75)
p.Vs_max_kt     = 27.3;          % kt, highest stall speed that still lands in 300 ft (1.30 V_S approach,
                                 % 1.3 g flare to 3 ft/s, braking + reverse) - from the time-marching model
% FIX: field condition = RFP field (old code: Colorado 6,800 ft / 90 F inside the function)
p.h_field_ft    = 1000;  p.dT_field_K = 10;    % <- set to the team's official RFP field condition
% FIX: critical loss of thrust N/(N-1) with N independent propulsors
p.Neng          = 10;
% FIX: wing/tail area in the empty weight and the wetted area (reference: typical twin wing)
p.WS_ref = 26; p.rhoWing = 2.5; p.rhoTail = 2.0; p.f_exposed = 0.90;
p.cHT = 0.90; p.cVT = 0.06; p.l_ht = 30.8; p.l_vt = 23.3;   % ft, arms of the STOL481.avl layout
% FIX: same battery inputs in sizing and weight iteration
p.eb_Whkg = eb_star/3600; p.R_el_nmi = e_range + 25;
p.N_motors = 10; p.P_motor_kW = 140;

S_sweep = 200:10:1500;

[P_point, S_point, ps] = PS_constraintcurves_corrected(S_sweep, W0, W_S_point, p);
fprintf('P-S design power: %.0f hp\n', P_point);
fprintf('P-S design wing area: %.0f ft^2 (%.1f m^2)\n', S_point, S_point*0.092903);

[W0_design, WeightStruct] = weightIterationEstimate_corrected(P_point, W0, S_point, W_S_point, prop_efficiency, p);

% FIX: tails from volume coefficients at the final wing (instead of 40 % / 30 % of S)
x_wing_c4 = 20.0; x_ht_c4 = x_wing_c4 + p.l_ht; x_vt_c4 = x_wing_c4 + p.l_vt;
tail = tailSizing(S_point, AR, 1.0, x_wing_c4, x_ht_c4, x_vt_c4, struct('cHT',p.cHT,'cVT',p.cVT));

disp('New Weight Values (lbs):')
disp(WeightStruct);


battery_pack_density = 1.5*62.428; %1.5 kg/L from baseline assumption converted to lbs/ft^3
battery_volume = WeightStruct.W_batt/battery_pack_density;

disp('Battery Volume (ft^3): ')
disp(battery_volume)

fuel_density = 760/16.018;% 100% Sustainable Aviation Fuel, what the RR550 turbogenerator is designed to run on, 760 kg/m^3 converted to lbs/ft^3
fuel_volume = WeightStruct.Wf/fuel_density;

disp('Fuel Volume (ft^3): ')
disp(fuel_volume)


%% Cost Output based on Design Points

[c] = aircraftcost(aircraft_data_01);

disp("Total Cost = $" + c.tot_cost );
disp("COC", c.T1);
disp("FOC", c.T2);
disp("IOC", c.T3);
disp("Aircraft Cost", c.T0);
