function p = aircraft_data_01()

% This function keeps track of our variable inputs for cost and weight
% functions. The function can be called, and then values from this file can
% be referenced by p.[value]

% VARIABLE    % VALUE     % UNITS
% ---------- RFP given values -----------------
p.n_pax       = 8;        % [-]      passengers, from RFP
p.R           = 400;      % [nmi]    design range, from RFP
p.then_year   = 2035;     % [yr]     entry into service

% ----------- Logistics -------------
p.tb          = 3;        % [hr]     block time
p.PLF         = 0.75;     % [-]      passenger load factor
p.R_p         = 1.0;      % [-]      ratio of pax legs (Roskam IOC term)
p.K_route     = 2.75;     % [-]      route factor (2.75 = regional)
p.ticket_price = 200;     % [$]      average one-way fare on the target route

% ---------- Aircraft Specific ----------
p.MTOW        = 14455;    % [lb]
p.PW          = 0.20;     % [kW/kg]  Power - Weight ratio
p.SHP_to      = p.PW*p.MTOW; % [shp] set directly to override SHP_per_lb
p.n_engines   = 6;        % [-]      number of engines

% ---------- Fuel / Oil Specific (per trip) ----------
p.W_f         = 1252;     % [lb]     Fuel Weight (weight iteration code)
p.P_f         = 2.24;     % [$/gal]  Jet-A price (then-year $)
p.rho_f       = 6.7;      % [lb/gal] Jet-A density
p.oil_frac    = 0.01;     % [-]      oil consumed as a fraction of block fuel
p.P_oil       = 46;       % [$/gal]  oil price based on current data
p.rho_oil     = 3.7;      % [lb/gal] density of aircraft lubricant oil
p.W_oil       = 0.0125 * p.W_f * p.tb / 100; % [lbs] weight of oil 

% ---------- Battery / Electric (per trip) ----------
p.W_b         = 4093;     % [lb]     installed pack weight
p.DoD         = 0.85;     % [-]      usable depth of discharge per trip
p.eta_chg     = 0.92;     % [-]      wall-to-pack charging efficiency
p.P_elec      = 0.15;     % [$/kWh]  electricity price (then-year $)

% ---------- Hybrid Architecture ----------
p.f_motor_power  = 1.0;   % [-]      electric motor power as a fraction of SHP_to
p.P_motor_hp     = 180;   % engine horsepower
p.C_motor_per_hp = 150;   % [$/hp]
p.C_batt_kWh     = 520;   %   [$/kWh]
p.E_batt         = 400  % [kWh]

% ---------- Crew & Maintenance ----------
p.AF          = 1.0;      % [-]      crew airline factor (1.0 = high estimate)
p.R_L         = 150;      % [$/hr]   maintenance labour rate
p.H_em        = 4000;     % [hr]     hours between engine overhaul/swap

% ---------- ownership ----------
p.n_life      = 20;       % [yr]     depreciation period
p.K_dep       = 0.10;     % [-]      residual value fraction
p.IR_a        = 0.02;     % [1/yr]   hull insurance rate 
p.f_financing = 0.07;     % [-]      financing as a fraction of DOC

end