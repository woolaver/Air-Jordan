clc; clear; close all;


% design variables
% MTOW
% SHP_to
% Cruise Speed
% AF ? 
% Weight aircraft
% engine weight - can give empty weight

% constants
% block time
% maintenance labor rate in USD


% apply cost adjust formula
function [cost_thenyear] = inflation_adjustment (r, n, cost_baseyear)
   
    cost_thenyear = cost_baseyear(1 + r)^n;
end

% cost estimation factor
function [CEF] = cost_estimation_factor(b_year, t_year)

    bcef = 5.17053 + 0.104981*(b_year - 2006);
    tcef = 5.17053 + 0.104981 * (t_year - 2006);
    CEF = tcef / bcef;
end


% Roskam Aircraft Price
function [C_aircraft, C_engines, C_airframe] = roskam_price(MTOW, SHP_to, CEF)
    % using Roskam turboprop commuter aircraft values (between 6,000 and
    % 50,000 lbs)

    % function takes in MTOW, Shaft Power of Turboprop (SHP_to), and Cost
    % Estimation Factor (CEF) and returns the Roskam price for the
    % aircraft, engine, and airframe

    C_aircraft = 10^(1.1846 + 1.2625*log10(MTOW)) * CEF;
    C_engines = 10^(2.5262 + 0.9465 *log10(SHP_to)) * CEF;
    C_airframe = C_aircraft - C_engines;
end





% cash operating costs

function [cash_operating_cost] = indirect(AF, MTOW, tb, CEF, R)
    
    K = 2.75 % using regional route factor
    C_crew = AF * (K * MTOW^0.4 * tb) * CEF;

    C_fuel = 1.02 * W_f * P_f / rho_f
    C_elec = 1.05 * W_b * P_elec * e_elec;
    C_oil = 1.02 * W_oil * P_oil / rho_oil;
    C_airport =  1.5 * (MTOW / 1000) * CEF; % landing fees
    C_navigation = 0.5 * (CEF) * (1.852 * R / tb) * sqrt((0.00045359237 * MTOW) / 50);
    C_ML = 1.03 * (3 + (0.067 * W_A) / 1000) * R_L;
    C_MM = 1.03 * (30*CEF) + (0.79 * 10^-5) * C_airframe;
    C_airframe_maintenance = (C_ML + C_MM) * tb;
    
    % engine maintenance (using turbo engines)
    C_ML = 1.03 * 1.3*(0.4956 + 0.0532 * (SHP_to / n_engines) / 1000 * (1100 / H_em) + 0.1) * R_L;
    C_engine_maintenance = n_engines * (C_ML + C_MM) * tb;

    % assuming maintenance costs are negligible for electric motors and
    % batterues
    c_motors = 150; % * battery horsepower % h/p
    c_batteries = 520; % kWh

    C_electric_aircraft = C_aircraft - C_engines + C_motors + C_batteries;

end



% FIXED OPERATING COST

function [fixed_operating_cost] = fixed(MTOW, tb, C_electric_aircraft)


    IR_a = 0.02; % assumed hull insurance 
    U_annual = (1.5*10^3) * (3.4546 * tb + 2.994 - (12.289 * tb^2 - 5.6626 * tb + 8.964) ^0.5));

    C_insurance = (IR_a * C_electric_aircraft / U_annual) * tb;

    C_depreciation = (C_unit * (1 - K_depreciation) * tb) / (n * U_annual);

    C_registration = (0.001 + 10^-8 * MTOW) * DOC ; % DOC is sum of all twelve costs above


end

    
% INDIRECT OPERATING COST

function [indirect_operating_cost] = indirect(MTOW, tb, n_pax, CEF)

    C_serv = (0.285 + 0.0025) * (n_pax / tb) * CEF;
    C_food = 1.05 * (2.42 * (n_pax / (1+R_p)) + (n_pax * R_p) / (1 + R_p)) * CEF;
    C_ent = 196 / tb * CEF;
    C_pax_ins = 0.52 * (n_pax * PLF * R / (1000 * tb)) * CEF;
    Cpaxh = 2.87 * (n_pax * PLF / tb) * CEF;
    Cbagh = 1.31 * (n_pax * PLF / tb) * CEF;
    Ccargh = 131.08 * (n_pax * PLF / tb) * CEF;
    C_payload_handling = Cpaxh + Cbagh + Ccargh;


    C_res = 4.4 * (n_pax * PLF / tb) * CEF;
    C_pub = 0.023 * (R * C_f * n_pax * PLF / tb) * CEF;
    C_marketing = C_res + C_pub;

    C_comm = 2.35 * (n_pax * PLF * R / (1000 * tb)) * CEF;
    C_gen = (0.18 * n_pax / tb) * CEF;

    C_admin = C_comm + C_gen;

    indirect_operating_cost = C_serv + C_food + C_ent + C_pax_ins + C_payload_handling + C_marketing + C_admin;
    

end



