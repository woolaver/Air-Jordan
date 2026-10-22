%Complete iteration loop for initial aircraft weight estimation

function [MTOW, Wcr_W0, Wl_W0, Wclimb_W0, Wce_W0, Wto_W0] = weight_Estimate_Iteration_old(aircraft)

g = 9.8; %m/s^2

W_payload = aircraft.payload_weight*4.44822; %lbs to N

electric_motor_weight = aircraft.electric_power_weight*4.44822; %lbs to N, includes motor weight plus generator weight

%taken from MTOW of General - Comparison Aircraft google sheet
%research_MTOW = (9.8/2.205)*[2450, 1320, 9800, 5400, 3400, 4200, 12500]; %converted lbs to N
%research_WE = (9.8/2.205)*[1660, 941, 6000, 4050, 2250, 2400, 10362]; %converted lbs to N

research_MTOW = (9.8/2.205)*[2450, 1320, 5400, 3400, 4200]; %converted lbs to N
research_WE = (9.8/2.205)*[1660, 941, 4050, 2250, 2400]; %converted lbs to N

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

%200 nmi fuel range from 400nmi total range - 200 nmi electric range
W5_W4 = 1/(exp(aircraft.R_fuel/(325.9*(aircraft.prop_efficiency/aircraft.specific_fuel_consumption_cruise)*aircraft.L_D)));

%range for 45 minutes of reserve battery at 225 knots
W7_W6 = 1;

R_electric = aircraft.e_range*1852; %nmi converted to m
R_reserve = aircraft.emergency_range*1852; %nmi converted to m

tol = 10^(-5);
delta = 1;

A = 1.4;
C = -.10;

while abs(delta) > tol
    %using Raymers's method with custom regression constants
    WE_W0 = A*W0^C + electric_motor_weight/W0;
    %assuming fuel use during takeoff and climb and fully electric cruise
    WF_W0 = 1 - (W9_W8*W8_W7*W7_W6*W6_W5*W5_W4*W4_W3*W3_W2*W2_W1*W1_W0);
    m_cruise = W5_W4*W4_W3*W3_W2*W2_W1*W1_W0*W0/g; %kg

    emergency_battery_mass = (R_reserve*g*m_cruise)/(aircraft.electric_efficiency*aircraft.emergency_eb_star*aircraft.L_D*aircraft.battery_degredation); %kg

    mass_battery = (R_electric*g*m_cruise)/(aircraft.electric_efficiency*aircraft.eb_star*aircraft.L_D*aircraft.battery_degredation); %kg

    W0_new = (W_payload + (mass_battery + emergency_battery_mass)*g)/(1 - WF_W0 - WE_W0); %kg
    delta = abs(W0_new - W0)/W0_new;
    W0 = W0_new;
end

disp('Estimated Aircraft Takeoff Weight:')
disp(W0/g + "kg, " + W0/g * 2.205 + " lbs")

disp('Estimated Empty Takeoff Weight:')
disp(WE_W0*W0/g * 2.205 + "lbs")

disp('Estimated Fuel Weight:')
disp(WF_W0*W0/g * 2.205 + "lbs")

disp('Payload Weight:')
disp(W_payload/g * 2.205 + "lbs")

disp('Electric Propulsion - battery system weight:')
disp((electric_motor_weight/g)  * 2.205 + "lbs")

disp('Total Cruise Battery Weight:')
disp(mass_battery * 2.205 + "lbs ")

disp('Total Emergency Battery Weight:')
disp(emergency_battery_mass * 2.205 + " lbs")

disp('Landing Weight Fraction:')
Wl_W0 = (W9_W8*W8_W7*W6_W5*W5_W4*W4_W3*W3_W2*W2_W1*W1_W0);
disp(Wl_W0)

MTOW = W0/g * 2.205;
Wcr_W0 = W5_W4*W4_W3*W3_W2*W2_W1*W1_W0 ;
Wclimb_W0 = W3_W2*W2_W1*W1_W0;
Wce_W0 = W4_W3*W3_W2*W2_W1*W1_W0;
Wto_W0 = W2_W1*W1_W0;