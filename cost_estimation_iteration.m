function [] = cost_estimation_iteration(tb, K, R, Neng, W_b, eb_star, P_elec)

    % design variables
    % MTOW
    % SHP_to
    % Cruise Speed
    % AF ? 
    % Weight aircraft
    % engine weight - can give empty weight
    % battery design values - Weight, Price of electricity, specific energy of
    % battery
    
    
    
    % constants
    
    tb = 3; % our block time is 3 hours based on research
    % maintenance labor rate in USD
    n_pax = 8; % value generated from RFP
    then_year = 2035; % entry date into service
    % jet-a values - Weight, Price per gallon, density
    
    % apply cost adjust formula
    function [cost_thenyear] = inflation_adjustment (r, n, cost_baseyear)
       
        cost_thenyear = cost_baseyear(1 + r)^n;
    end
    
    % cost estimation factor
    function [CEF] = cost_estimation_factor(b_year, t_year)
    
        bcef = 5.17053 + 0.104981* (b_year - 2006);
        tcef = 5.17053 + 0.104981 * (t_year - 2006);
        CEF = tcef / bcef;
    end
    
    
    % Roskam Aircraft Price
    function [roskam_cost] = roskam_price(MTOW, SHP_to, CEF)
        % using Roskam turboprop commuter aircraft values (between 6,000 and
        % 50,000 lbs)
    
        % function takes in MTOW, Shaft Power of Turboprop (SHP_to), and Cost
        % Estimation Factor (CEF) and returns the Roskam price for the
        % aircraft, engine, and airframe
        C_aircraft = 10^(1.1846 + 1.2625*log10(MTOW)) * CEF; % 
        C_engines = 10^(2.5262 + 0.9465 *log10(SHP_to)) * CEF;
        C_airframe = C_aircraft - C_engines;
    
         % Create table
        roskam_cost = table( ...
            {'Total Aircraft'; 'Engines'; 'Airframe'}, ...
            [C_aircraft; C_engines; C_airframe], ...
            'VariableNames', {'Cost_Category', 'Cost'});
    
    end
    
    % cash operating costs
    
    function [direct_operating_cost] = direct(AF, MTOW, tb, CEF_1989, CEF_1999, R, C_airframe, C_aircraft, C_engines, SHP_to, K, Neng, W_b, )
        
    
        Neng = 6; % engine number = ~6
        
        % Jet-A Parameters
        W_f = 1252; % lbs 
        P_f = 2.24; % $ / gal
        rho_f = 6.7; % lbs / gal
    
        % Oil Parameters
        P_oil = 46; % $ / gal
        rho_oil = 3.7; % lbs / gal;
        W_oil = rho_oil * (W_f / rho_f); % ballpark guess, lbs
    
        % Labor Rates
        R_L = 150; % $ / hr based on research data
        
        % Hours Between Engine Swap-Out
        H_em = 4000; % hours
        
    
        C_crew = AF * (K * MTOW^0.4 * tb) * CEF_1999; % 1999
    
        C_fuel = 1.02 * W_f * P_f / rho_f;  % 
        C_elec = 1.05 * W_b * P_elec * eb_star;
        C_oil = 1.02 * W_oil * P_oil / rho_oil;
        C_airport =  1.5 * (MTOW / 1000) * CEF_1999; % landing fees - 1999
        C_navigation = 0.5 * (CEF_1989) * (1.852 * R / tb) * sqrt((0.00045359237 * MTOW) / 50);
        C_ML = 1.03 * (3 + (0.067 * C_airframe) / 1000) * R_L; % 1989
        C_MM = 1.03 * (30*CEF_1989) + (0.79 * 10^-5) * C_airframe; % 1989
        C_airframe_maintenance = (C_ML + C_MM) * tb; % 2007
        
        % engine maintenance (using turbo engines)
        C_ML = 1.03 * 1.3*(0.4956 + 0.0532 * (SHP_to / Neng) / 1000 * (1100 / H_em) + 0.1) * R_L;
        C_engine_maintenance = Neng * (C_ML + C_MM) * tb; 
    
        % assuming maintenance costs are negligible for electric motors and
        % batterues
        C_motors = 150; % * battery horsepower % h/p
        C_batteries = 520; % kWh
    
        C_electric_aircraft = C_aircraft - C_engines + C_motors + C_batteries;
    
        total_cash_operating_cost = C_electric_aircraft + C_engine_maintenance + C_airframe_maintenance + C_navigation + C_airport + C_oil + C_elec + C_fuel + C_crew;
         % Create table
        direct_operating_cost = table( ...
            {'Crew'; ...
             'Fuel'; ...
             'Electricity'; ...
             'Oil'; ...
             'Airport'; ...
             'Navigation'; ...
             'Airframe Maintenance'; ...
             'Engine Maintenance'; ...
             'Electric Aircraft'; ...
             'Total Cash Operating Cost'}, ...
            [C_crew; ...
             C_fuel; ...
             C_elec; ...
             C_oil; ...
             C_airport; ...
             C_navigation; ...
             C_airframe_maintenance; ...
             C_engine_maintenance; ...
             C_electric_aircraft; ...
             total_cash_operating_cost], ...
            'VariableNames', {'Cost_Category', 'Cost'});
    
    end
    
    
    
    % FIXED OPERATING COST
    
    function [fixed_operating_cost] = fixed(MTOW, tb, C_electric_aircraft, DOC)
    
        C_unit = C_electric_aircraft; % unit cost
        K_depreciation = 0.1; 
        n = 20; % operational lifetime
    
        IR_a = 1.02; % assumed hull insurance 
        U_annual = (1.5*10^3) * (3.4546 * tb + 2.994 - (12.289 * tb^2 - 5.6626 * tb + 8.964) ^0.5);
    
        C_insurance = (IR_a * C_electric_aircraft / U_annual) * tb;
        C_financing = 0.07 * DOC;
        C_depreciation = (C_unit * (1 - K_depreciation) * tb) / (n * U_annual);
    
        C_registration = (0.001 + 10^-8 * MTOW) * DOC ; % DOC is sum of all twelve costs above
        total_fixed_operating_cost = C_insurance + C_depreciation + C_registration;
      
        % Create table
        Cost_Category = { ...
            'Annual Utilization'; ...
            'Insurance'; ...
            'Financing'; ...
            'Depreciation'; ...
            'Registration'; ...
            'Total Fixed Operating Cost'};
    
        Cost = [ ...
            U_annual; ...
            C_insurance; ...
            C_financing; ...
            C_depreciation; ...
            C_registration; ...
            total_fixed_operating_cost];
    
        fixed_operating_cost = table(Cost_Category, Cost);
    end
    
        
    % INDIRECT OPERATING COST
    
    function [indirect_operating_cost, tot_indirect_operating_cost] = idc(tb, CEF)
    
        n_pax = 8; % passenger number given by RFP
        PLF = 0.75; % assuming average 3/4 full flights for PLF
        R_p = 1; % assuming everyone gets on and then gets off 
        R = 400; % nmi range given by RFP
        average_ticket_price = 200; % found average price for Big Island - Ni'ihau regional flight
        C_f = average_ticket_price / (400 * n_pax);
    
        % 2001 - CEF
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
    
        tot_indirect_operating_cost = C_serv + C_food + C_ent + C_pax_ins + C_payload_handling + C_marketing + C_admin;
        
        indirect_operating_cost = table( ...
            [C_serv; C_food; C_ent; C_pax_ins; ...
             Cpaxh; Cbagh; Ccargh; ...
             C_res; C_pub; ...
             C_comm; C_gen; ...
             tot_indirect_operating_cost], ...
            'VariableNames', {'Cost'}, ...
            'RowNames', { ...
            'Service', ...
            'Food', ...
            'Entertainment', ...
            'Passenger Insurance', ...
            'Passenger Handling', ...
            'Baggage Handling', ...
            'Cargo Handling', ...
            'Reservations', ...
            'Publicity', ...
            'Communications', ...
            'General', ...
            'Total Indirect Operating Cost'});
    
    end
    
    
    
    
    
    % cost estimation factors for all years considered in equations
    [CEF_2001] = cost_estimation_factor(2001, 2035);
    [CEF_1999] = cost_estimation_factor(1999, 2035);
    [CEF_1989] = cost_estimation_factor(1989, 2035);
    [CEF_2007] = cost_estimation_factor(2007, 2035);
    
    
    % calculate indirect operating cost
    [indirect_operating_cost] = idc(tb, CEF_2001);
    
    % Roskam - Aircraft Price
    
    [roskam_cost] = roskam_price(14455, 0.2*14455, CEF_1989);
    
    
    % Cash Operating Price
    
    R = 400; % nmi range
    MTOW = 14455; % lbs
    AF = 1; % AF is based on high estimate
    C_airframe = 5.0925 * 10^6; % $
    C_engine = 1.5382 * 10^6; % $
    C_aircraft = 6.6307 * 10^6; % $
    SHP_to = 0.2 * MTOW;
    [cash_operating_cost] = direct(AF, MTOW, tb, CEF_1989, CEF_1999, R, C_airframe, C_aircraft, C_engine, SHP_to);
    
    
    % Fixed-Operating Cost
    C_electric_aircraft = 5.093 * 10^6; % $
    DOC = 5.687 * 10^6; % $
    [fixed_operating_cost] = fixed(MTOW, tb, C_electric_aircraft, DOC);
end
