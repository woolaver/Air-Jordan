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

[W_S_point, P_W_point, aircraft] = preliminary_Sizing(aircraft, aircraft.design_margin);

%% Blown Wing Analysis

aircraft.wing_area = 700; % initial guess
converged = 0;
[takeoff_distance, landing_distance, aircraft] = BlownWingAnalysis(aircraft, converged);

disp("Takeoff Distance: " + takeoff_distance + " ft")
disp("Landing Distance: " + landing_distance + " ft")

%W_S_sweep = linspace(0, 50, 100); %create a wing loading var to sweep over

%max_W_S_blown_land = blown_wing_landing(aircraft, W_S_sweep);


%% Updated Sizing Estimate

[aircraft] = Blown_Lift_Sizing(aircraft, aircraft.design_margin);


%% Updated Weight Estimate and P-S Curves

design_margin = 1.025;

p = struct('AR',aircraft.AR,'Cf_clean',aircraft.Cf_clean,'CLmax_to', aircraft.CLmax_to, ...
    'prop_efficiency', aircraft.prop_efficiency,'Wcr_W0', aircraft.Wcr_W0,'Wclimb_W0', aircraft.Wclimb_W0, ...
    'Wce_W0',aircraft.Wce_W0,'Wland_W0',aircraft.Wland_W0,'Pcr_P0',aircraft.Pcr_P0,'Neng',aircraft.num_propeller,'alt_cr',aircraft.alt_cr, 'design_margin', aircraft.design_margin);

S_sweep = 200:10:1500;

[P_point, S_point, aircraft] = PS_constraintcurves(S_sweep, aircraft.W0, aircraft);
disp("P-S design power: " + P_point + " hp");
disp("P-S design wing area: " + S_point + "ft^2");


% Get Weights at Design Point
[W0_design, WeightStruct] = weightIterationEstimate_corrected( ...
    aircraft.P_point, aircraft.W0, aircraft.S_point, W_S_point, aircraft.prop_efficiency, aircraft);

% calculate emergency range
em = emergency_range(aircraft, W0_design, S_point, WeightStruct.W_batt, P_point);


disp('New Weight Values (lbs):')
disp(WeightStruct);

aircraft.battery_pack_density = 1.5*62.428; %1.5 kg/L from baseline assumption converted to lbs/ft^3
aircraft.battery_volume = WeightStruct.W_batt/aircraft.battery_pack_density;

disp('Battery Volume (ft^3): ')
disp(aircraft.battery_volume)

aircraft.fuel_density = 760/16.018;% 100% Sustainable Aviation Fuel, what the RR550 turbogenerator is designed to run on, 760 kg/m^3 converted to lbs/ft^3
aircraft.fuel_volume = WeightStruct.Wf/aircraft.fuel_density;

disp('Fuel Volume (ft^3): ')
disp(aircraft.fuel_volume)

%% Aerodynamic Refinement
134
[CD0_clean_updated, CD0_land_updated, CD0_takeoff_updated, CD0_land_brake_updated] = aerodynamicRefinement(aircraft);

aircraft.CD0_clean = CD0_clean_updated;
aircraft.CD0_land = CD0_land_updated;
aircraft.CD0_takeoff = CD0_takeoff_updated;
aircraft.CD0_land_brake = CD0_land_brake_updated;

disp("Updated CD0_clean: " + CD0_clean_updated)
disp("Updated CD0_land: " + CD0_land_updated)
disp("Updated CD0_takeoff: " + CD0_takeoff_updated)
disp("Updated CD0_land_brake: " + CD0_land_brake_updated)

%% Improved weight estimation

[Wimproved, aircraft] = supermegadetailedweightestimation(WeightStruct.W0, P_point, aircraft);



%% Emissions Objective Function

[CO2, Nox, parts] = emissions_objective(P_point, aircraft);

%% Cost Output based on Design Points
%{
aircraft.SHP_to = aircraft.P_W*aircraft.W0; 
aircraft.W_oil = 0.0125 * aircraft.Wf * aircraft.tb / 100; % [lbs] weight of oil 
[c] = aircraftcost(aircraft);

fprintf('Total Cost = $%.2f\n', c.tot_cost);
fprintf('COC = $%.2f\n', c.T1);
fprintf('FOC = $%.2f\n', c.T2);
fprintf('IOC = $%.2f\n', c.T3);
fprintf('Aircraft Cost = $%.2f\n', c.T0);
%}

[aircraft] = Blown_Lift_Sizing(aircraft, aircraft.design_margin);
converged = 1;

[takeoff_distance, landing_distance, aircraft] = BlownWingAnalysis(aircraft, converged);

[aircraft] = Blown_Lift_Sizing(aircraft, aircraft.design_margin);


