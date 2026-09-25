function p = aircraft_data_01()
% AIRCRAFT_DATA_01 - Input parameters for hybrid-electric commuter cost model.
%
% Configuration: Mild-Hybrid Twin Turboprop
% Note: Base airframe weight retained; MTOW reduced strictly by the 
%       reduction in battery pack weight (4,093 lb -> 1,100 lb).

%% ==================== RFP REQUIREMENTS ====================
p.n_pax          = 8;        % [-]      Passenger capacity
p.R              = 400;      % [nmi]    Design flight range
p.then_year      = 2035;     % [yr]     Entry into service year

%% ==================== MISSION & LOGISTICS ==================
p.tb             = 3.0;      % [hr]     Block time (~200 kt commuter speed)
p.PLF            = 0.75;     % [-]      Passenger load factor
p.R_p            = 0.0;      % [-]      First-class to coach ratio (0 for commuter)
p.K_route        = 2.75;     % [-]      Route wage factor (regional airline)
p.ticket_price   = 200;      % [$]      One-way fare per passenger

%% ==================== AIRCRAFT & SIZING ===================
% Original MTOW was 14,455 lb with a 4,093 lb pack.
% With original airframe kept constant and battery reduced to 1,100 lb:
% New MTOW = 14,455 - (4,093 - 1,100) - delta_fuel ~= 11,330 lb
p.MTOW           = 11330;    % [lb]     Takeoff weight reflecting only battery/fuel delta
p.n_engines      = 2;        % [-]      Twin turboprop layout

% Installed power calculation:
p.PW_kWkg        = 0.18;     % [kW/kg]  Power loading
p.total_power_hp = p.MTOW * (p.PW_kWkg * 0.6084); % [hp] Total takeoff power (~1,241 hp)

% Power split (25% electric takeoff boost, 75% thermal):
p.f_electric     = 0.25;     % [-]      Electric boost fraction
p.P_motor_hp     = p.total_power_hp * p.f_electric;       % [hp] Electric motor power (~310 hp)
p.SHP_to         = p.total_power_hp * (1 - p.f_electric);  % [hp] Turboprop shaft power (~931 hp)

%% ==================== FUEL & OIL CONSUMPTION =============
% Fuel reduced from 1,252 lb to 1,120 lb due to lower cruise drag (less gross weight)
p.W_f            = 1120;     % [lb]     Block fuel burned per trip
p.P_f            = 2.24;     % [$/gal]  Jet-A fuel price (then-year $)
p.rho_f          = 6.7;      % [lb/gal] Jet-A density

p.oil_frac       = 0.01;     % [-]      Oil consumed as fraction of fuel weight
p.W_oil       = 0.0125 * p.W_f * p.tb / 100; % [lb] Oil weight consumed per trip
p.P_oil          = 46;       % [$/gal]  Engine lubricant oil price
p.rho_oil        = 3.7;      % [lb/gal] Lubricant oil density

%% ==================== BATTERY & ELECTRIC =================
p.W_batt_pack    = 1100;     % [lb]     Installed battery pack weight (downsized)
p.e_b_Whkg       = 215;      % [Wh/kg]  2035 pack-level specific energy

% Installed battery capacity:
p.E_batt         = (p.W_batt_pack / 2.20462) * (p.e_b_Whkg / 1000); % [kWh] (~149.7 kWh)

p.DoD            = 0.85;     % [-]      Usable depth of discharge per trip
p.eta_chg        = 0.92;     % [-]      Wall-to-pack charging efficiency
p.P_elec         = 0.15;     % [$/kWh]  Aviation electricity price

% Grid electrical energy consumed per trip:
p.W_b            = (p.E_batt * p.DoD) / p.eta_chg; % [kWh] (~138.3 kWh)

% Unit component costs:
p.C_motor_per_hp = 150;      % [$/hp]   Electric motor acquisition cost
p.C_batt_kWh     = 520;      % [$/kWh]  Projected 2035 certified pack cost

%% ==================== CREW & MAINTENANCE =================
p.AF             = 1.0;      % [-]      Crew airline calibration factor
p.R_L            = 150;      % [$/hr]   Maintenance labor rate
p.H_em           = 4000;     % [hr]     Turbine TBO (extended by peak takeoff derate)

%% ==================== OWNERSHIP & FINANCIAL ==============
p.n_life         = 20;       % [yr]     Aircraft economic depreciation period
p.K_dep          = 0.10;     % [-]      Residual/scrap value fraction (10%)
p.IR_a           = 0.02;     % [1/yr]   Annual hull insurance rate fraction (2%)
p.f_financing    = 0.07;     % [-]      Financing cost as fraction of DOC

end