%% aircraft_cost.m

clc; clear; close all;
 
p = aircraft_data_01();

%% ---------------------------------------------------

function CEF = cost_escalation_factor(b_year, p)
    % escalates base-year dollars to p.then_year.
    bcef = 5.17053 + 0.104981*(b_year     - 2006);
    tcef = 5.17053 + 0.104981*(p.then_year - 2006);
    CEF  = tcef / bcef;
end

%% --------------------------------------------------- 
 
function [C_aircraft, C_airframe, C_engines, C_engine_each, a] = roskam_price(p)
    % Roskam turboprop commuter price equations, 1989 base, 6,000-50,000 lb.
    CEF = cost_escalation_factor(1989, p);
    
    % roskam equations + electric motor and battery estimates for aircraft
    % price
    C_aircraft_rosk = 10^(1.1846 + 1.2625*log10(p.MTOW)) * CEF;
    C_engines = 10^(2.5262 + 0.9465*log10(p.SHP_to)) * CEF;
    C_airframe = C_aircraft_rosk - C_engines;
    C_engine_each = C_engines / max(p.n_engines, 1);
    C_motors = p.C_motor_per_hp  * p.P_motor_hp;
    C_batteries = p.C_batt_kWh  * p.E_batt;     
    C_aircraft = C_airframe + C_engines + C_motors + C_batteries;
    
    % save values in struct for table later
    a.C_airframe = C_aircraft_rosk - C_engines;
    a.C_engine_each = C_engines / max(p.n_engines, 1);
    a.C_motors = p.C_motor_per_hp  * p.P_motor_hp;
    a.C_batteries = p.C_batt_kWh  * p.E_batt;     
    a.C_aircraft = C_airframe + C_engines + C_motors + C_batteries;
end

%% ---------------------------------------------------
 
% run roskam_price function
[C_aircraft, C_airframe, C_engines, C_engine_each, a] = roskam_price(p);
 
%% ---------------------------------------------------

function [COC, c] = cash_operating(p, C_airframe, C_engine_each)
    % per-trip cash operating cost. 
    CEF89 = cost_escalation_factor(1989, p);
    CEF99 = cost_escalation_factor(1999, p);
    
    % crew labor costs
    c.crew = p.AF * (p.K_route * p.MTOW^0.4 * p.tb) * CEF99;
     
    % fuel / oil / electricity costs
    c.fuel = 1.02 * p.W_f   * p.P_f   / p.rho_f;
    c.oil  = 1.02 * p.W_oil * p.P_oil / p.rho_oil;
    c.elec = 1.05 * p.W_b * p.P_elec;
     
    % landing and navigation fees
    c.airport = 1.5 * (p.MTOW/1000) * CEF99;
    c.nav     = 0.5 * CEF89 * (1.852*p.R/p.tb) * sqrt((0.00045359237*p.MTOW)/50);
     
    % airframe maintenance
    C_MLA     = 1.03 * (3 + 0.067*C_airframe/1000) * p.R_L;
    C_MMA     = 1.03 * (30*CEF89 + 0.79e-5 * C_airframe);
    c.maint_af = (C_MLA + C_MMA) * p.tb;
     
    % engine maintenance cost
    shp_each   = p.SHP_to / max(p.n_engines, 1);
    C_MLE      = 1.03 * 1.3 * (0.4956 + 0.0532*(shp_each/1000)*(1100/p.H_em) + 0.1) * p.R_L;
    C_MME      = 1.03 * (30*CEF89 + 0.79e-5 * C_engine_each);   % placeholder form
    c.maint_eng = p.n_engines * (C_MLE + C_MME) * p.tb;
    
    % total cash operating cost
    COC = c.crew + c.fuel + c.oil + c.elec + c.airport + c.nav + ...
          c.maint_af + c.maint_eng;
end
 
%% ---------------------------------------------------

% run cash operating function
[COC, c] = cash_operating(p, C_airframe, C_engine_each);

%% ---------------------------------------------------
 
function [FOC, DOC, f] = fixed_operating(p, C_aircraft, COC)
    % per-trip ownership cost
    f.U_annual = 1.5e3 * (3.4546*p.tb + 2.994 - ...
                 (12.289*p.tb^2 - 5.6626*p.tb + 8.964)^0.5);
    % depreciation and insurance costs 
    f.dep = C_aircraft * (1 - p.K_dep) * p.tb / (p.n_life * f.U_annual);
    f.ins = (p.IR_a * C_aircraft / f.U_annual) * p.tb;
    % direct operating cost, financing, registration 
    k_reg = 0.001 + 1e-8 * p.MTOW;
    DOC   = (COC + f.dep + f.ins) / (1 - p.f_financing - k_reg);
    f.fin = p.f_financing * DOC;
    f.reg = k_reg   * DOC;
     
    FOC = f.dep + f.ins + f.fin + f.reg;
end

%% ---------------------------------------------------

% run fixed operating cost code
[FOC, DOC, f] = fixed_operating(p, C_aircraft, COC);

%% ---------------------------------------------------
 
function [IOC, i] = indirect_operating(p)
    % per-trip indirect operating cost
    
    % cost escalation factor for 2001
    CEF = cost_escalation_factor(2001, p);
    
    % pull aircraft data from struct
    n = p.n_pax; 
    PLF = p.PLF; 
    tb = p.tb; 
    R = p.R;
   
    % ticket fare price factor
    C_f = p.ticket_price / R;         
     
    i.serv    = (0.285 + 0.0025) * (n/tb) * CEF;
    i.food    = 1.05 * (2.42*(n/(1+p.R_p)) + (n*p.R_p)/(1+p.R_p)) * CEF;
    i.ent     = 196/tb * CEF;
    i.pax_ins = 0.52 * (n*PLF*R/(1000*tb)) * CEF;
    
    % passenger and cargo handling costs
    i.paxh  = 2.87   * (n*PLF/tb) * CEF;
    i.bagh  = 1.31   * (n*PLF/tb) * CEF;
    i.cargh = 131.08 * (n*PLF/tb) * CEF;
    
    % marketing costs
    i.res = 4.4   * (n*PLF/tb) * CEF;
    i.pub = 0.023 * (R*C_f*n*PLF/tb) * CEF;
     
    % administrative costs
    i.comm = 2.35 * (n*PLF*R/(1000*tb)) * CEF;
    i.gen  = 0.18 * (n/tb) * CEF;
     
    % total indirect operating costs
    IOC = i.serv + i.food + i.ent + i.pax_ins + i.paxh + i.bagh + i.cargh + ...
          i.res + i.pub + i.comm + i.gen;
end

%% ---------------------------------------------------

% run indirect operating cost function
[IOC, i] = indirect_operating(p);

%% ---------------------------------------------------

% function takes structs created by each cost calculation step and
% generates tables to report costs 

function T = struct_to_table(s, total_name, total_value)

    fields = fieldnames(s);
    labels = cell(size(fields));
    values = zeros(size(fields));
    for k = 1:numel(fields)
        words = strsplit(fields{k}, '_');
        words = cellfun(@(w) [upper(w(1)) w(2:end)], words, 'UniformOutput', false);
        labels{k} = strjoin(words, ' ');
        values(k) = s.(fields{k});
    end
    labels{end+1}  = total_name;
    values(end+1)  = total_value;
    T = table(labels(:), values(:), 'VariableNames', {'Item','Cost'});
end

%% ---------------------------------------------------

% collect and report cost data in tables

T1 = struct_to_table(c, 'Cash Operating Cost', COC);
T2 = struct_to_table(f, 'Fixed Operating Cost', FOC);
T3 = struct_to_table(i, 'Indirect Operating Cost', IOC);
T0 = struct_to_table(a, 'Aircraft Cost', C_aircraft);
tot_cost = C_aircraft + IOC + DOC + FOC;
disp('Total Cost = ' + tot_cost);

