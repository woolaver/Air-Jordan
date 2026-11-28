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
P_point = max(aircraft.P_W*aircraft.W0, aircraft.P_install);   % hp, start power for the loop
aircraft.max_power = 550*P_point;                              % ft*lbf/s, used by BlownWingAnalysis and the battery


%% Converged design loop: aerodynamics -> weights -> sizing -> field performance, repeated until W0 stops changing
W0_old = 0;  it = 0;
set(0, 'DefaultFigureVisible', 'off');   % no figure windows during the loop
while abs(aircraft.W0 - W0_old) > 1 && it < 60
    W0_old = aircraft.W0;  it = it + 1;
    close all   % keep only the figures of the latest pass
    % props, wing geometry and tails follow the wing. HT: all-moving T-tail at V_H = 1.05, the C17 trim requirement
    % (nose-down moment of the blown flap on the approach at aft CG, thrust above the CG at lift-off); VT: requirements below
    b_w = sqrt(aircraft.AR*aircraft.wing_area);  aircraft.wing_span = b_w;
    if aircraft.props_fill_span, aircraft.prop_diameter = aircraft.f_span_max*b_w/aircraft.num_propeller; end
    t_sz = tailSizing(aircraft.wing_area, aircraft.AR, aircraft.taperratio, 0, aircraft.l_tail, aircraft.l_tail - 2.5, struct('cHT', 1.05, 'T_tail', false));   % V_H 1.05 (no extra T-tail credit), arms from the PDR tail (27 ft + longer cone)
    aircraft.horiz_area = t_sz.S_ht;  aircraft.Sh = t_sz.S_ht;
    % vertical tail from its requirements, not a volume coefficient:
    %  VT-1 positive directional stability with a yaw damper (14 CFR 23.2145, 23.2140): C_nbeta >= 0.020 /rad,
    %       C_nbeta = -0.031 + 2.11*V_V (team AVL fin trade, A8: 0.049 at V_V 0.038)
    %  VT-2 rudder holds a 16 kt crosswind/gust at lift-off/touchdown speed (27 kt): delta_r <= 25 deg
    %  one motor out is handled by automatic shutdown of the mirror motor (differential thrust), not by the fin
    Cnb_min = 0.020;  V_V = (Cnb_min + 0.031)/2.11;
    l_v  = aircraft.l_tail - 2.5;                                  % ft, fin arm
    a_v  = 2*pi*1.86/(2 + sqrt(1.86^2 + 4));                       % 1/rad, fin lift slope, AR_v 1.2 x 1.55 end-plate (T-tail)
    beta = atan(16/27);                                            % rad, sideslip in a 16 kt crosswind at 27 kt
    aircraft.delta_r_xw = rad2deg((-0.031 + 2.11*V_V)*beta/(a_v*0.55*V_V));   % deg rudder (tau_r 0.55)
    if aircraft.delta_r_xw > 25, warning('Rudder %.1f deg > 25 deg in the 16 kt crosswind', aircraft.delta_r_xw); end
    aircraft.vert_area = V_V*b_w*aircraft.wing_area/l_v;
    aircraft.S_wet_horizontalStabilizer = 2.05*t_sz.S_ht;
    aircraft.S_wet_verticalStabilizer   = 155.915/100*t_sz.S_vt;     % CAD ratio wetted/planform of the VT
    aircraft.c_bar = t_sz.mac;  aircraft.x_acw = 11.72 + .25*t_sz.mac;
    % aerodynamics with the current wing and weight
    [CD0_clean_updated, CD0_land_updated, CD0_takeoff_updated, CD0_land_brake_updated] = aerodynamicRefinement(aircraft);
    aircraft.CD0_clean      = CD0_clean_updated;
    aircraft.CD0_land       = CD0_land_updated;
    aircraft.CD0_takeoff    = CD0_takeoff_updated;
    aircraft.CD0_land_brake = CD0_land_brake_updated;

    % weights at the current power (sets aircraft.W0 and aircraft.wing_area = W0/W_S)
    [Wimproved, aircraft] = supermegadetailedweightestimation(aircraft.W0, P_point, aircraft);
    aircraft.Wland_W0 = 1 - aircraft.Wf_trip/aircraft.W0;   % lands with the reserve fuel still on board
    % wing loading and power from the constraints, then take-off and landing
    WS_old = aircraft.W_S;
    [aircraft] = Blown_Lift_Sizing(aircraft, aircraft.design_margin);
    converged = 1;
    [takeoff_distance, landing_distance, aircraft] = BlownWingAnalysis(aircraft, converged);
    [aircraft] = Blown_Lift_Sizing(aircraft, aircraft.design_margin);
    aircraft.W_S = 0.5*(aircraft.W_S + WS_old);   % half step: damps the jump between the landing limit and the prop-span limit

    P_point = max(aircraft.P_W*aircraft.W0, aircraft.P_install);   % installed motor power is fixed; constraints only raise it
    aircraft.max_power = 550*P_point;
    fprintf('Pass %d: W0 = %.0f lb, S = %.0f ft^2, P = %.0f hp, TO %.0f ft, LD %.0f ft\n', ...
            it, aircraft.W0, aircraft.wing_area, P_point, takeoff_distance, landing_distance);
end
set(0, 'DefaultFigureVisible', 'on');
set(findall(0, 'Type', 'figure'), 'Visible', 'on');   % show the figures of the last (converged) pass
if it == 60, warning('Design loop did not converge in 60 passes'); end

%% Emissions Objective Function (once, on the converged design)
[CO2, Nox, parts] = emissions_objective(P_point, aircraft);

%% Cost Output based on Design Points
aircraft.SHP_to     = P_point;                             % installed shaft power [hp]
aircraft.P_motor_hp = P_point;
aircraft.W_f        = aircraft.Wf_trip;                    % trip fuel only: the IFR reserve stays in the tank
aircraft.W_oil      = aircraft.oil_frac*aircraft.W_f;      % lb oil per trip
aircraft.W_b        = aircraft.E_mission_kWh/0.92;         % kWh from the grid for the mission (charger 92 %), not the emergency reserve
aircraft.W_airframe = Wimproved.airframe;                  % lb, for airframe maintenance
aircraft.P_TG_hp    = 1000/0.7457;                         % hp, 1 MW turbogenerator
[c] = aircraftcost(aircraft);
fprintf('DOC = $%.0f per trip | COC = $%.0f | FOC = $%.0f | IOC = $%.0f | aircraft price = $%.2f M\n', c.DOC, c.COC, c.FOC, c.IOC, c.C_aircraft/1e6);

aircraft_final = aircraft;  P_final = P_point;   % converged design (the legacy P-S block below overwrites some fields of aircraft)
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



