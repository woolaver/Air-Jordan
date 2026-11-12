% aircraft struct

function [aircraft] = aircraft()
%% Main Assumptions:

aircraft.Cf_clean = 0.15;

aircraft.design_margin = .025; % 2.5% margin on P/W, W/S design point

%Initial weight properties
aircraft.electric_power_weight = (150 + 480)*2.205; %3118 kg to lbs, From Data Sheet (not including batteries)
aircraft.L_D = 11.8746; %From aircraftDesignDriver, comes from force balance at cruise
aircraft.AR = 11; %From aircraftDesignDriver
aircraft.W_S = 22.1; %lbs/ft, main restriction is landing from blown wing analysis
aircraft.alt_cr = 10000; %feet
aircraft.climb_rate = 1500; % 1500 f/m climb
aircraft.crew_weight = 1520; %lbs from RFP
aircraft.baggage_weight = 240; % lbs from RFP
aircraft.payload_weight = aircraft.crew_weight + aircraft.baggage_weight;

aircraft.specific_fuel_consumption_cruise = .412*1.64399; %lb/(hp*h) converted from kg/(kW*h) from turbogenerator analysis in report 5
aircraft.R_fuel = 200; %nmi, fuel range
aircraft.V_cr = 225; %kts, from RFP
aircraft.rho_takeoff = .002297; %slug/ft^3, ISA + 18F
aircraft.n_engine = 2; % number of turbogenerators

% Wing / Aerodynamic Qualities
aircraft.taperratio = 1;
aircraft.root_tip_ratio = 1;
aircraft.wing_sweep = 0;
%aircraft.wing_cont_surf_area = ; % wing mounted control surface area
aircraft.wing_area = 649; % ft^2, from design point
aircraft.wing_control_surf_area = 0.3 * aircraft.wing_area;

% Tail and Horizontal Stabilizer Quantities
aircraft.horiz_area = 154.8; % ft^2, horizontal tail area
aircraft.vert_area = 100; % ft^2, vertical tail area

% Load Factor
aircraft.n_limit = 3.08;
aircraft.ultimate_load_factor = 1.5 * aircraft.n_limit; % 1.5 x max load factor, 3.08 g's selected (FAR)

% Propulsion System Quantities
aircraft.num_propeller = 10; %from Data Sheet
aircraft.prop_efficiency = .82; % from Data Sheet
aircraft.prop_weight = 44.1; % lbs per propeller, chosen props
aircraft.n_turbogenerators = 2; % number of chosen turbogenerators
aircraft.weight_turbogenerators = 530.4; % lbs, weight of chosen turbogenerator
aircraft.weight_electric_motors = 33.07; % lbs, weight of electric motors

% CAD System Results
aircraft.S_fuselage = 931;



% Battery System Quantities
aircraft.e_range = 200; %nmi, 200 required
aircraft.electric_efficiency = .9032; %combined efficiencies of battery, motor, and wiring combined
aircraft.battery.e_cell_Whkg = 505;    % [Wh/kg] cell level (
aircraft.battery.pack_factor = 0.70;   % [-] pack/cell mass: BMS, structure, cooling  
aircraft.battery.soc_max     = 0.95;   % [-] max state of charge                                        
aircraft.battery.soc_min     = 0.10;   % [-] min state of charge                                     
aircraft.battery.fade        = 0.90;   % [-] end-of-life capacity 
aircraft.battery.p_spec_kWkg = 1.5;    % [kW/kg] pack-level discharge power 
b = aircraft.battery;
aircraft.eb_star = b.e_cell_Whkg * 3600 * b.pack_factor*(b.soc_max - b.soc_min);
aircraft.battery_degredation = b.fade; %assuing battery replacement at 90% of battery max charge
aircraft.DoD = b.soc_max - b.soc_min;

aircraft.emergency_eb_star = 900*3600; %Wh/kg converted to SI units J/kg, nonrechargable emergency range
aircraft.emergency_range = 225*.75; %45 minutes of range at 225 knots
aircraft.divert_time = 45; % 45 minutes of diversion time


% preliminary sizing

aircraft.CD0_clean = .015;
aircraft.CLmax_clean = 1.5;
aircraft.CLmax_to = 7;
aircraft.CLmax_climb = 3.472;
aircraft.Pcr_P0 = .8; %estimate from preliminary sizing


%Blown wing analysis properties
aircraft.W0 = 14389; %lbs
aircraft.prop_diameter = 5.5; %ft, initial estimate from blown wing analysis
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
aircraft.CL_tail_dot = .05; %random estimate
aircraft.Iyy = 20000; %slug*ft^2, estimate from light twin engine aircraft ~ 12500 lbs
aircraft.Cm_wb_0 = .05; %estimate from google
aircraft.S = 650; % from updated sizing plot
aircraft.c_bar = aircraft.S/aircraft.AR;
aircraft.x_mlg = .65*aircraft.c_bar; %estimate from Cinar
aircraft.x_cg = .35*aircraft.c_bar; %estimate from Cinar
aircraft.x_acw = .25*aircraft.c_bar; %assuming ac is at quarter chord
aircraft.Sh = .4*aircraft.S; %estimated 40% sizing of tail
aircraft.l_tail = 30; %ft, estimated from beechcraft baron
aircraft.z_cg = 10; %ft, estimated from beechcraft baron
aircraft.z_mlg = 0; %ft, main landing gear on the ground
aircraft.CL_max_stall = 10; %from blown wing analysis 



% emergency range parameters
aircraft.h_field    = 0;         % [ft] field elevation (rho_takeoff is sea-level ISA+18F)
aircraft.h_fail_agl = 5000;      % [ft] AGL at failure
aircraft.dT_K       = 18*5/9;    % [K]  ISA+18 F is a 10 K difference
aircraft.rho_em     = density_isa_offset(aircraft.h_field + aircraft.h_fail_agl, aircraft.dT_K);
aircraft.Wem_W0     = 1.0;       % [-]  weight at failure / MTOW
aircraft.G_em       = 0.0;       % [-]  gradient margin (0 = level flight)
aircraft.Hp         = 0.8;       % [-]  battery-fed share of installed P (the split hybrid_data hard-coded)

% weight values to be updated as script runs
aircraft.Wcr_W0 = 0;
aircraft.Wland_W0 = 0;
aircraft.Wclimb_W0 = 0;
aircraft.Wce_W0 = 0;
aircraft.Wto_W0 = 0;


aircraft.S_wet_horizontalStabilizer = 636.438; %ft^2 from CAD as of 11/7
aircraft.S_wet_verticalStabilizer = 155.915; %ft^2 from CAD as of 11/7
aircraft.S_wet_empennage = 133.989; %ft^2, from CAD as of 11/7
aircraft.wing_MAC = 7.68; %from PDR slides
aircraft.fuselage_length = 24.38; %ft, from CAD drawings from PDR
aircraft.empennage_length = 10.2895; %ft, from CAD drawings from PDR
aircraft.h_tail_MAC = 6.45; %ft, from PDR report
aircraft.v_tail_MAC = 9.17; %ft, from PDR report


end