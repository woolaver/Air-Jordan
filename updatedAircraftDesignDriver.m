%updated version of aircraftDesignDriver

%utilize struct to contain all aircraft information in a single object to
%make function calls easier

clear
clc
close all

% call in aircraft struct
aircraft = aircraft();

%% Initial Weight Estimation

[W0, Wcr_W0, Wl_W0, Wclimb_W0, Wce_W0, Wto_W0] = weight_Estimate_Iteration_old(aircraft);

aircraft.W0 = W0;
aircraft.Wcr_W0 = Wcr_W0;
aircraft.Wland_W0 = Wl_W0;
aircraft.Wclimb_W0 = Wclimb_W0;
aircraft.Wce_W0 = Wce_W0;
aircraft.Wto_W0 = Wto_W0;

%% Preliminary Sizing Estimate


design_margin = .025; % 2.5% margin on P/W, W/S design point

[W_S_point, P_W_point] = preliminary_Sizing(aircraft, design_margin);

%% Blown Wing Analysis

BlownWingAnalysis(aircraft)

%W_S_sweep = linspace(0, 50, 100); %create a wing loading var to sweep over

%max_W_S_blown_land = blown_wing_landing(aircraft, W_S_sweep);



%% Updated Weight Estimate and P-S Curves

design_margin = 1.025;

p = struct('AR',aircraft.AR,'Cf_clean',aircraft.Cf_clean,'CLmax_to', aircraft.CLmax_to, ...
    'prop_efficiency', aircraft.prop_efficiency,'Wcr_W0', aircraft.Wcr_W0,'Wclimb_W0', aircraft.Wclimb_W0, ...
    'Wce_W0',aircraft.Wce_W0,'Wland_W0',aircraft.Wland_W0,'Pcr_P0',aircraft.Pcr_P0,'Neng',aircraft.num_propeller,'alt_cr',aircraft.alt_cr, 'design_margin', aircraft.design_margin);

S_sweep = 500:10:4000;

[P_point, S_point, ps] = PS_constraintcurves(S_sweep, W0, W_S_point, p);
disp("P-S design power: " + P_point + " hp");
disp("P-S design wing area: " + S_point + "ft^2");
em = emergency_range(aircraft, W0_design, S_point, WeightStruct.W_batt, P_point);
% Get Weights at Design Point
[W0_design, WeightStruct] = weightIterationEstimate_corrected( ...
    1765, aircraft.W0_lb, 649, W_S_point, aircraft.prop_efficiency, aircraft);



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


% Improved weight estimation

[Wimproved] = supermegadetailedweightestimation(14389, 1765, aircraft);

%% Aerodynamic Refinement

aircraft.S_wet_horizontalStabilizer = 636.438; %ft^2 from CAD as of 11/7
aircraft.S_wet_verticalStabilizer = 155.915; %ft^2 from CAD as of 11/7
aircraft.S_wet_empennage = 133.989; %ft^2, from CAD as of 11/7
aircraft.wing_MAC = 7.68; %from PDR slides
aircraft.fuselage_length = 24.38; %ft, from CAD drawings from PDR
aircraft.empennage_length = 10.2895; %ft, from CAD drawings from PDR
aircraft.h_tail_MAC = 6.45; %ft, from PDR report
aircraft.v_tail_MAC = 9.17; %ft, from PDR report

CD0_clean_updated = aerodynamicRefinement(aircraft);

disp("Updated CD0_clean: " + CD0_clean_updated)
%% Cost Output based on Design Points

[c] = aircraftcost(aircraft_data_01);

disp("Total Cost = $" + c.tot_cost );
disp("COC", c.T1);
disp("FOC", c.T2);
disp("IOC", c.T3);
disp("Aircraft Cost", c.T0);