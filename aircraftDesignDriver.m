%Driver function to run all aircraft design functions

%% Weight Estimation

clear
close all
clc

%PUT UNITS ON EVERYTHING, THIS SHIT ASS
%LABEL ALL ASSUMPTIONS WITH WHERE YOU GOT IT FROM

%estimated 6 electric aircraft engines for improved takeoff performance,
%Siemens motor has weight of 50 kg
%https://press.siemens.com/global/en/pressrelease/siemens-develops-world-record-electric-motor-aircraft
electric_system_mass = 6*50;

%L/D estimate from typical twin turboprop aircraft from Roskam's
L_D = 11;

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
[W0, Wcr_W0, Wland_W0, Wclimb_W0, Wce_W0] = weight_Estimate_Iteration(electric_system_mass, L_D, cp, prop_efficiency, e_range, batt_efficiency, eb_star, battery_degradation);

disp('--------------------------------------')
%% Preliminary Sizing

AR = 11;
W_S = 10; %used for CD0 estimate only, if we can get a better way to find this we should

%Raymer's estimations for Cf, using twin engine small aircraft
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

%assuming 6 electric engines and one combustion
Neng = 7;

%just an estimation from Adam, will need a way to calculate this or a
%better estimate
Pcr_P0 = .9;

%assuming unpressurized for now, may want to pressurize later but for how
%short our flight time is climbing to high altitudes will probably not be
%worth it
alt_cr = 12500; %feet

preliminary_Sizing(W0, AR, W_S, Cf_clean, CLmax_clean, CLmax_to, prop_efficiency, Wcr_W0, Wclimb_W0, Wce_W0, Wland_W0, Pcr_P0, Neng, alt_cr)


%% Cost Estimation

tb = 3; % our block time is 3 hours based on research
% maintenance labor rate in USD

K = 2.75; % regional route factor
R = 400; % RFP nmi range 