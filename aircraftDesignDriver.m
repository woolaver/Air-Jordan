%Driver function to run all aircraft design functions

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
L_D = 20.5;

%specific fuel consumption of general aviation piston engine
cp = .4; %lb/(hp*h)
prop_efficiency = .8;

%electric cruise range calculation for battery mass sizing
e_range = 225; %nmi, additional 25nmi added for takeoff and climb
batt_efficiency = .96; %conservative estimate from slides

%Justification for 400 Wh/kg batteries
%Likely, airborne batteries will natively belong to Generation-4 solid-state since their market inception, 
% with gravimetric energy density at cell level starting at 400 Wh/kg, 
% and possibly achieving the 750 Wh/kg mark by 2035 (Kühnelt et al. 2023).
eb_star = 420*3600; %500 Wh/kg from estimate converted to SI units J/kg

battery_degradation = .9;

disp('WEIGHT ESTIMATION:')

%returns W0 in kg, Wcr_W0 is cruise weight fraction assuming fuel cruise is
%before electric cruise, Wl_W0 is landing weight fraciton
[W0, Wcr_W0, Wland_W0, Wclimb_W0, Wce_W0, Wto_W0] = weight_Estimate_Iteration_old(electric_system_mass, L_D, cp, prop_efficiency, e_range, batt_efficiency, eb_star, battery_degradation);

disp('--------------------------------------')
%% Preliminary Sizing

AR = 11;
W_S = 10.1463; %used for CD0 estimate only, coming from design point

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
CLmax_to = 5;

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

S_sweep = 500:10:4000;

[P_point, S_point, ps] = PS_constraintcurves(S_sweep, W0, W_S_point, p);
disp("P-S design power: " + P_point + " hp");
disp("P-S design wing area: " + S_point + "ft^2");

[W0_design, WeightStruct] = weightIterationEstimate_new(P_point, W0, S_point, W_S_point, prop_efficiency);

disp('New Weight Values (lbs):')
disp(WeightStruct)




%% Cost Estimation

tb = 3; % our block time is 3 hours based on research
% maintenance labor rate in USD

K = 2.75; % regional route factor
R = 400; % RFP nmi range 