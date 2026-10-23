%updated version of aircraftDesignDriver

%utilize struct to contain all aircraft information in a single object to
%make function calls easier

clear
clc
close all

% RFP Values
% ---------- RFP given values -----------------
aircraft.n_pax       = 8;        % [-]      passengers, from RFP
aircraft.R           = 400;      % [nmi]    design range, from RFP
aircraft.then_year   = 2035;     % [yr]     entry into service

% ----------- Logistics -------------
aircraft.tb          = 3;        % [hr]     block time
aircraft.PLF         = 0.75;     % [-]      passenger load factor
aircraft.R_p         = 1.0;      % [-]      ratio of pax legs (Roskam IOC term)
aircraft.K_route     = 2.75;     % [-]      route factor (2.75 = regional)
aircraft.ticket_price = 200;     % [$]      average one-way fare on the target route

% ---------- Fuel / Oil Specific (per trip) ----------
aircraft.P_f         = 2.24;     % [$/gal]  Jet-A price (then-year $)
aircraft.rho_f       = 6.7;      % [lb/gal] Jet-A density
aircraft.oil_frac    = 0.01;     % [-]      oil consumed as a fraction of block fuel
aircraft.P_oil       = 46;       % [$/gal]  oil price based on current data
aircraft.rho_oil     = 3.7;      % [lb/gal] density of aircraft lubricant oil

% ---------- Crew & Maintenance ----------
aircraft.AF          = 1.0;      % [-]      crew airline factor (1.0 = high estimate)
aircraft.R_L         = 150;      % [$/hr]   maintenance labour rate
aircraft.H_em        = 4000;     % [hr]     hours between engine overhaul/swap

% ---------- ownership ----------
aircraft.n_life      = 20;       % [yr]     depreciation period
aircraft.K_dep       = 0.10;     % [-]      residual value fraction
aircraft.IR_a        = 0.02;     % [1/yr]   hull insurance rate 
aircraft.f_financing = 0.07;     % [-]      financing as a fraction of DOC

%% Main Assumptions:

%Initial weight properties
aircraft.electric_power_weight = (150 + 480)*2.205; %3118 kg to lbs, From Data Sheet (not including batteries)
aircraft.L_D = 11.8746; %From aircraftDesignDriver, comes from force balance at cruise
aircraft.AR = 11; %From aircraftDesignDriver
aircraft.W_S = 16; %lbs/ft, main restriction is landing from blown wing analysis
aircraft.e_range = 200; %nmi, 200 required
aircraft.electric_efficiency = .9032; %combined efficiencies of battery, motor, and wiring combined
aircraft.eb_star = 505*3600; %505 Wh/kg converted to SI units J/kg
aircraft.battery_degredation = .9; %assuing battery replacement at 90% of battery max charge
aircraft.alt_cr = 12500; %feet
aircraft.num_propeller = 10; %from Data Sheet
aircraft.prop_efficiency = .82; % from Data Sheet
aircraft.payload_weight = 1519; %lbs from Data Sheet
aircraft.specific_fuel_consumption_cruise = .412*1.64399; %lb/(hp*h) converted from kg/(kW*h) from turbogenerator analysis in report 5
aircraft.R_fuel = 200; %nmi, fuel range
aircraft.emergency_eb_star = 900*3600; %Wh/kg converted to SI units J/kg, nonrechargable emergency range
aircraft.emergency_range = 225*.75; %45 minutes of range at 225 knots
aircraft.V_cr = 225; %kts, from RFP
aircraft.rho_takeoff = .002297; %slug/ft^3, ISA + 18F

%% Initial Weight Estimation

[W0, Wcr_W0, Wl_W0, Wclimb_W0, Wce_W0, Wto_W0] = weight_Estimate_Iteration_old(aircraft);

aircraft.W0 = W0;
aircraft.Wcr_W0 = Wcr_W0;
aircraft.Wland_W0 = Wl_W0;
aircraft.Wclimb_W0 = Wclimb_W0;
aircraft.Wce_W0 = Wce_W0;
aircraft.Wto_W0 = Wto_W0;

%% Preliminary Sizing Estimate

aircraft.CD0_clean = .015;
aircraft.CLmax_clean = 1.5;
aircraft.CLmax_to = 7;
aircraft.CLmax_climb = 3.472;
aircraft.Pcr_P0 = .8; %estimate from preliminary sizing

design_margin = .025; % 2.5% margin on P/W, W/S design point

[W_S_point, P_W_point] = preliminary_Sizing(aircraft, design_margin);

%% Blown Wing Analysis

%Blown wing analysis properties
aircraft.prop_diameter = 7; %ft, initial estimate from blown wing analysis
aircraft.fB = .65; % initial estimate from Courtin, how much of the wing is actually being blown
aircraft.max_power = 550*1765; %slug*ft^2/s^3, from P-S plot 1765 hp
aircraft.eta_a = .84; %rotor loss factor, not prop efficiency, from Cinar slides
aircraft.delta_F = 60; %deg, flap deflection, assuming same for landing and takeoff for now
aircraft.landing_speed = 55; %kts, from blown wing landing analysis
aircraft.eta_F = .81; %Estimate from Cinar slides
aircraft.e_land = .725; %oswald efficiency with landing flaps estimate from Roskam's
aircraft.e_g = .8; %oswald efficiency at ground, estimate from Courtin
aircraft.mu_b = .4; %braking coefficient, estimate from Cinar slides
aircraft.CD0_g = .5; %ground parasitic drag coefficient, from Courtin
aircraft.G = .87; %not sure what this is, taken from Courtin
aircraft.mu = .0165; %rolling resistance estimate, used for transport aircraft
aircraft.CL_tail = -.5; %initial CL_tail
aircraft.CL_tail_dot = .5; %random estimate
aircraft.Iyy = 20000; %slug*ft^2, estimate from light twin engine aircraft ~ 12500 lbs
aircraft.Cm_wb_0 = .05; %estimate from google
aircraft.S = 1065; % from updated sizing plot
aircraft.c_bar = aircraft.S/aircraft.AR;
aircraft.x_mlg = .65*aircraft.c_bar; %estimate from Cinar
aircraft.x_cg = .35*aircraft.c_bar; %estimate from Cinar
aircraft.x_acw = .25*aircraft.c_bar; %assuming ac is at quarter chord
aircraft.Sh = .4*aircraft.S; %estimated 40% sizing of tail
aircraft.l_tail = 30; %ft, estimated from beechcraft baron
aircraft.z_cg = 10; %ft, estimated from beechcraft baron
aircraft.z_mlg = 0; %ft, main landing gear on the ground

%BlownWingAnalysis(aircraft)

W_S_sweep = linspace(0, 50, 100); %create a wing loading var to sweep over

max_W_S_blown_land = blown_wing_landing(aircraft, W_S_sweep);


%% Updated Weight Estimate and P-S Curves

aircraft.design_margin = 1.025;
aircraft.Cf_clean = 0.0045;
aircraft.CLmax_clean = 1.5;
aircraft.CLMax_to = 5;
aircraft.CLmax_climb = 3.472;


S_sweep = 500:10:4000;

[P_point, S_point, ps] = PS_constraintcurves(S_sweep, W0, W_S_point, aircraft);
disp("P-S design power: " + P_point + " hp");
disp("P-S design wing area: " + S_point + "ft^2");

[W0_design, WeightStruct] = weightIterationEstimate_corrected( ...
    P_point, W0, S_point, W_S_point, aircraft.prop_efficiency, aircraft);

aircraft.W_oil = 0.0125 * WeightStruct.Wf * aircraft.tb / 100;   % was W_f

aircraft.MTOW       = W0_design;                      % [lb]
aircraft.SHP_to     = P_point;                        % [hp]
aircraft.n_engines  = 7;                              % [-] (your call: 6 electric + 1 combustion?)
aircraft.W_f        = WeightStruct.Wf;                % [lb]
aircraft.W_b        = WeightStruct.W_batt;            % [lb]
aircraft.E_batt     = aircraft.W_b*0.45359237*(aircraft.eb_star/3600)/1000;  % [kWh]
aircraft.f_motor_power  = 1.0;
aircraft.P_motor_hp     = aircraft.f_motor_power*P_point;
aircraft.C_motor_per_hp = 150;                        % [$/hp]
aircraft.C_batt_kWh     = 520;                        % [$/kWh]
aircraft.DoD = 0.85;  aircraft.eta_chg = 0.92;  aircraft.P_elec = 0.15;
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



%% Cost Estimate

[c] = aircraftcost(aircraft);
