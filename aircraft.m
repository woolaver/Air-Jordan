% aircraft struct

function [aircraft] = aircraft()
%% Main Assumptions:

aircraft.Cf_clean = 0.0064261; %from aerodynamicRefinement

aircraft.design_margin = .025; % 2.5% margin on P/W, W/S design point

%Initial weight properties
aircraft.electric_power_weight = (150 + 480)*2.205; %3118 kg to lbs, From Data Sheet (not including batteries)
aircraft.L_D = 11.4862; %From aircraftDesignDriver, comes from force balance at cruise
aircraft.AR = 9; %From aircraftDesignDriver
aircraft.alt_cr = 35000; %feet
aircraft.climb_rate = 1500; % 1500 f/m climb
aircraft.crew_weight = 1520; %lbs from RFP
aircraft.num_crew = 8; % pilot + 7 passengers
aircraft.baggage_weight = 240; % lbs from RFP
aircraft.payload_weight = aircraft.crew_weight + aircraft.baggage_weight;

aircraft.specific_fuel_consumption_cruise = .412*1.64399; %lb/(hp*h) converted from kg/(kW*h) from turbogenerator analysis in report 5
aircraft.R_fuel = 200; %nmi, fuel range
aircraft.V_cr = 225; %kts, from RFP
aircraft.rho_takeoff = .002297; %slug/ft^3, ISA + 18F
aircraft.rho_cr = .000738; %slug/ft^3, 35000 ft
aircraft.n_engine = 2; % number of turbogenerators
aircraft.n_fuel_tanks = 1;

% Wing / Aerodynamic Qualities
aircraft.taperratio = 1;
aircraft.root_tip_ratio = 1;
aircraft.wing_sweep = 0;
%aircraft.wing_cont_surf_area = ; % wing mounted control surface area
aircraft.wing_area = 700; % initial guess
aircraft.wing_span = sqrt(aircraft.wing_area * aircraft.AR);
aircraft.wing_control_surf_area = 0.3 * aircraft.wing_area;
aircraft.w_fuelwing = 0; % weight of fuel stored in wings, currently none
aircraft.wing_tc = .15; % NLF-0115 airfoil

% Tail and Horizontal Stabilizer Quantities
aircraft.horiz_area = 145.8; % ft^2, horizontal tail area
aircraft.vert_area = 100; % ft^2, vertical tail area
aircraft.horiz_sweep = 4.76;
aircraft.horiz_taper = 0.5;
aircraft.horiz_AR = 4;
aircraft.vert_sweep = 40; % deg
aircraft.vert_taper = 0.8;
aircraft.vert_AR = 1.2;
aircraft.vert_tc = 0.12; % NACA 0012
aircraft.horiz_tc = 0.12; % NACA 0012


% Load Factor
aircraft.n_limit = 3.08;
aircraft.ultimate_load_factor = 1.5 * aircraft.n_limit; % 1.5 x max load factor, 3.08 g's selected (FAR)

% Landing Gear Quantities
aircraft.main_gear_length = 24;
aircraft.nose_gear_length = 24;


% Propulsion System Quantities
aircraft.num_propeller = 12; %from Data Sheet
aircraft.prop_efficiency = .82; % from Data Sheet
aircraft.prop_weight = 44.1; % lbs per propeller, chosen props
aircraft.n_turbogenerators = 1; % number of chosen turbogenerators
aircraft.weight_turbogenerators = 1010; % lbs, weight of chosen turbogenerator, 1MW honeywell
aircraft.weight_electric_motors = 30.2; % lbs, weight of electric motors

% CAD System Results
aircraft.S_fuselage = 931;
aircraft.Lt = 17.5; % ft, dist from 1/4 MAC to horiz tail
aircraft.u_upsweep = 19.9;   % deg; set 14 only once CAD has the 4.4 ft longer tail cone (and its extra wetted area)

% Battery System Quantities
aircraft.e_range = 200; %nmi, 200 required
aircraft.electric_efficiency = .9032; %combined efficiencies of battery, motor, and wiring combined
aircraft.battery.e_cell_Whkg = 505;    % [Wh/kg] cell level (
aircraft.battery.pack_factor = 0.9;   % [-] pack/cell energy ratio: BMS, structure, cooling  
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
aircraft.reserve_battery_weight = 0; % lbs


% preliminary sizing

aircraft.CD0_clean = .025665; %from aerodynamicRefinement.m
aircraft.CLmax_clean = 1.5;
aircraft.CLmax_to = 7;
aircraft.CLmax_climb = 3.472;
aircraft.Pcr_P0 = .8; %estimate from preliminary sizing


%Blown wing analysis properties
aircraft.prop_diameter = 4.5; %ft, initial estimate from blown wing analysis
aircraft.fB = 0.9*min(num_props*prop_diameter/b, 1)); % initial estimate from Courtin, how much of the wing is actually being blown
aircraft.max_power = 550*2896; %slug*ft^2/s^3, from P-S plot 1765 hp
aircraft.approach_power_frac = 0.22 %max power approach
aircraft.k_blow        = 1.1;    %blowing factor: 1.0 baseline el9 calibrated
aircraft.CL_cap = 15; %upper limit blown C_L
aircraft.eta_a = .84; %rotor loss factor, not prop efficiency, from Cinar slides
aircraft.delta_F = 64; %deg, flap deflection, assuming same for landing and takeoff for now
aircraft.landing_speed = 32.6; %kts, from blown wing landing analysis
aircraft.eta_F = .81; %Estimate from Cinar slides
aircraft.delta_F_to    = 40;    % deg, take-off flap
aircraft.CLmax_flap_LD = 2.60;  % unblown C_Lmax, double-slotted Fowler 30 % chord, landing flap
aircraft.CLmax_flap_TO = 2.28;  % same, take-off flap
aircraft.alpha_margin  = 5;     % deg below stall in take-off, approach and flare
aircraft.k_app         = 1.3;   % V_app >= 1.3 V_S
aircraft.k_TO          = 1.1;   % V_LOF >= 1.1 V_S
aircraft.e_cr = .8; % Raymer eq. 12.48 for AR 9, straight wing with fuselage
aircraft.e_land = .78; %oswald efficiency with landing flaps from AVL
aircraft.e_g = .8; %oswald efficiency at ground, estimate from Courtin
aircraft.mu_b = .5; %braking coefficient, estimate from Cinar slides
aircraft.CD0_g = .5; %ground parasitic drag coefficient, from Courtin
aircraft.G = .87; %not sure what this is, taken from Courtin
aircraft.mu = .0165; %rolling resistance estimate, used for transport aircraft
aircraft.CL_tail = -.5; %initial CL_tail
aircraft.CL_tail_dot = .5; %random estimate
aircraft.Iyy = 30000; %slug*ft^2, estimate twin engine turboprop
aircraft.Cm_wb_0 = .05; %estimate from google
aircraft.c_bar = 9.0268; %from AR of 9
aircraft.x_mlg = 18.38; %ft, from CAD as of 11/7
aircraft.x_cg = 16.5; %ft
aircraft.x_acw = 11.72 + .25*aircraft.c_bar; %assuming ac is at quarter chord
aircraft.Sh = 200; %Marley Estimation
aircraft.l_tail = 27; %ft, from PDR
aircraft.z_cg = 11.591207/2; %estimating half the distance from top of wing to bottom of landing gear
aircraft.z_mlg = 0; %ft, on the ground
aircraft.wing_incidence = 2; %deg, from PDR slides

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

aircraft.S_wet_fuselage = 517.96; %ft^2 from CAD as of 11/7
aircraft.S_wet_horizontalStabilizer = 2.05*aircraft.horiz_area;   % about 299 ft^2 for the 145.8 ft^2 tail (both sides + thickness)
aircraft.S_wet_verticalStabilizer = 155.915; %ft^2 from CAD as of 11/7
aircraft.wing_MAC = 9.0268; %from updated AR = 9
aircraft.fuselage_length = 34.5625; %ft, from CAD drawings from PDR
aircraft.h_tail_MAC = 6.45; %ft, from PDR report
aircraft.v_tail_MAC = 9.17; %ft, from PDR report
aircraft.fuselage_height = 6.9985; %from PDR drawings
aircraft.fuselage_width = 5.67; %from PDR drawings
aircraft.V_land = 40; %kts, estimation for now, needs to come from landing analysis
aircraft.V_takeoff = 40; %kts, estimation for now, needs to come from takeoff analysis
aircraft.CD0_land = .071465;
aircraft.CD0_land_brake = .2591;
aircraft.CD0_takeoff = .053412;

% cost driver parameters
aircraft.n_pax       = 8;        % [-]      passengers, from RFP
aircraft.R           = 400;      % [nmi]    design range, from RFP
aircraft.then_year   = 2035;     % [yr]     entry into service

% ----------- Logistics -------------
aircraft.tb          = 3;        % [hr]     block time
aircraft.PLF         = 0.75;     % [-]      passenger load factor
aircraft.R_p         = 1.0;      % [-]      ratio of pax legs (Roskam IOC term)
aircraft.K_route     = 2.75;     % [-]      route factor (2.75 = regional)
aircraft.ticket_price = 200;     % [$]      average one-way fare on the target route

aircraft.P_f         = 2.24;     % [$/gal]  Jet-A price (then-year $)
aircraft.rho_f       = 6.7;      % [lb/gal] Jet-A density
aircraft.oil_frac    = 0.01;     % [-]      oil consumed as a fraction of block fuel
aircraft.P_oil       = 46;       % [$/gal]  oil price based on current data
aircraft.rho_oil     = 3.7;      % [lb/gal] density of aircraft lubricant oil

aircraft.C_motor_per_hp = 150;   % [$/hp]
aircraft.C_batt_kWh     = 520;   %   [$/kWh]

aircraft.AF          = 1.0;      % [-]      crew airline factor (1.0 = high estimate)
aircraft.R_L         = 125;      % [$/hr]   maintenance labour rate
aircraft.H_em        = 4000;     % [hr]     hours between engine overhaul/swap

% ---------- ownership ----------
aircraft.n_life      = 20;       % [yr]     depreciation period
aircraft.K_dep       = 0.10;     % [-]      residual value fraction
aircraft.IR_a        = 0.02;     % [1/yr]   hull insurance rate 
aircraft.f_financing = 0.07;     % [-]      financing as a fraction of DOC


end
