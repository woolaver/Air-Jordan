%Complete iteration loop for initial aircraft weight estimation

clear
close all
clc

g = 9.8; %m/s^2
num_passengers = 8; %7 + 1 pilot
passenger_mass = 86.1826; %kg
baggage_mass = 13.6078; %kg

baggage_weight = g*baggage_mass*num_passengers; %N
passenger_weight = g*num_passengers*passenger_mass; %N

W_payload = baggage_weight + passenger_weight; %N

%battery mass is estimated assuming energy density of 500 Wh/kg and 200 nmi
%of electric cruise plus additional 100 nmi for other stages of flight
%https://ntrs.nasa.gov/api/citations/20190000487/downloads/20190000487.pdf


%https://press.siemens.com/global/en/pressrelease/siemens-develops-world-record-electric-motor-aircraft

%estimated 6 electric aircraft engines for improved takeoff performance,
%Siemens motor has weight of 50 kg

electric_motor_weight = g*6*50; %N

%taken from MTOW of General - Comparison Aircraft google sheet
research_MTOW = (9.8/2.205)*[2450, 1320, 9800, 5400, 3400, 4200, 12500]; %converted lbs to N
research_WE = (9.8/2.205)*[1660, 941, 6000, 4050, 2250, 2400, 10362]; %converted lbs to N

avg_MTOW = mean(research_MTOW); %N

%take average MTOW as first W0 guess, assuming that maximum takeoff weight is same as gross takeoff weight, for a commercial aircraft maximum payload will be much closer to gross takeoff weight to maximize profit
W0 = avg_MTOW; %N

W0 = W0 + electric_motor_weight; %N

%Raymer's Regression showed increasing empty weight fraction with increase
%in takeoff weight, not realisitc value, most likely due to mix of
%conventional, hybrid-electric, and electric aircraft, will just use
%Raymer's constants given in book for twin engine propeller aircraft
%(metric)

%estimating fuel fraction from Roskan data table for takeoff, cruise,
%descent, landing, and reserves
W1_W0 = .992;
W2_W1 = .996;
W3_W2 = .996;
W4_W3 = .990;
%W5_W4 calculated below for fuel cruise flight
W6_W5 = 1; %assuming fully electric loiter (Roskam's doesn't have any data for this)
%W7_W6 will be calculated below for reserve fuel
W8_W7 = .992;
W9_W8 = .992;

%FAR 23 requires 45 minutes of flight time in IFR conditions for fuel
%reserves, will assume that this flight is fully jet fuel

%L/D estimate from typical twin turboprop aircraft from Roskam's
L_D = 11;

%specific fuel consumption of general aviation piston engine
cp = .4; %lb/(hp*h)
prop_efficiency = .85;

%200 nmi fuel range from 400nmi total range - 200 nmi electric range
R_fuel = 200;
W5_W4 = 1/(exp(R_fuel/(325.9*(prop_efficiency/cp)*L_D)));

%range for 45 minutes of reserve fuel at 225 knots
R_reserve = 225*.75; %nmi
W7_W6 = 1/(exp(R_reserve/(325.9*(prop_efficiency/cp)*L_D)));

%electric cruise range calculation for battery mass sizing
R_electric = 250*1852; %nmi converted to m, 250nmi taken from 200 requirement plus extra for takeoff and climb
batt_efficiency = .96; %conservative estimate from slides

%Justification for 400 Wh/kg batteries
%Likely, airborne batteries will natively belong to Generation-4 solid-state since their market inception, 
% with gravimetric energy density at cell level starting at 400 Wh/kg, 
% and possibly achieving the 700 Wh/kg mark by 2035 (Kühnelt et al. 2023).
eb_star = 400*3600; %200 Wh/kg from estimate converted to SI units J/kg

tol = 10^(-5);
delta = 1;

A = 1.4;
C = -.10;

while delta > tol
    %using Raymers's method with custom regression constants
    WE_W0 = A*W0^C + electric_motor_weight/W0;
    %assuming fuel use during takeoff and climb and fully electric cruise
    WF_W0 = 1 - (W9_W8*W8_W7*W7_W6*W6_W5*W5_W4*W4_W3*W3_W2*W2_W1*W1_W0);
    m_cruise = W5_W4*W4_W3*W3_W2*W2_W1*W1_W0*W0/g; %kg

    mass_battery = (R_electric*g*m_cruise)/(batt_efficiency*eb_star*L_D); %kg

    W0_new = (W_payload + mass_battery*g)/(1 - WF_W0 - WE_W0); %kg
    delta = abs(W0_new - W0)/W0_new;
    W0 = W0_new;
end

disp('Estimated Aircraft Takeoff Weight:')
disp(W0/g + " kg")

disp('Estimated Empty Takeoff Weight:')
disp(WE_W0*W0/g + " kg")

disp('Estimated Fuel Weight:')
disp(WF_W0*W0/g + " kg")

disp('Payload Weight Crew and Passenger:')
disp(passenger_weight/g + " kg")

disp('Payload Weight Baggage:')
disp(baggage_weight/g + " kg")

disp('Electric Propulsion - battery system weight:')
disp(mass_battery + electric_motor_weight/g + " kg")

disp('Total Battery Weight:')
disp(mass_battery + " kg")

disp('Estimated Cruise Mass:')
disp(m_cruise + " kg")

disp('Cruise Mass Fraction:')
disp(1 - (m_cruise/(W0)))

disp('Takeoff Mass Fraction:')
disp(W3_W2*W2_W1*W1_W0)

disp('Landing Mass Fraction:')
disp()