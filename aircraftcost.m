%% aircraft_cost.m

function [c] = aircraftcost(aircraft)
 
    
    %% ---------------------------------------------------
    
    function CEF = cost_escalation_factor(b_year, aircraft)
        % Escalates base-year dollars to aircraft.then_year.
        bcef = 5.17053 + 0.104981*(b_year     - 2006);
        tcef = 5.17053 + 0.104981*(aircraft.then_year - 2006);
        CEF  = tcef / bcef;
    end
    
    %% --------------------------------------------------- 
     
    function [C_aircraft, C_airframe, C_engines, C_engine_each, a] = roskam_price(aircraft)
        % Roskam turboprop commuter price equations, 1989 base, 6,000-50,000 lb.
        CEF = cost_escalation_factor(1989, aircraft);
         
        C_aircraft_rosk = 10^(1.1846 + 1.2625*log10(aircraft.MTOW)) * CEF;
        C_engines = 10^(2.5262 + 0.9465*log10(aircraft.SHP_to)) * CEF;
        C_airframe = C_aircraft_rosk - C_engines;
        C_engine_each = C_engines / max(aircraft.n_engines, 1);
        C_motors = aircraft.C_motor_per_hp  * aircraft.P_motor_hp;
        C_batteries = aircraft.C_batt_kWh  * aircraft.E_batt;     
        C_aircraft = C_airframe + C_engines + C_motors + C_batteries;
        
        % save values in struct for table later
        a.C_airframe = C_aircraft_rosk - C_engines;
        a.C_engine_each = C_engines / max(aircraft.n_engines, 1);
        a.C_motors = aircraft.C_motor_per_hp  * aircraft.P_motor_hp;
        a.C_batteries = aircraft.C_batt_kWh  * aircraft.E_batt;     
        a.C_aircraft = C_airframe + C_engines + C_motors + C_batteries;
    end
    
    %% ---------------------------------------------------
     
    % run roskam_price function
    [C_aircraft, C_airframe, C_engines, C_engine_each, a] = roskam_price(aircraft);
     
    %% ---------------------------------------------------
    
    function [COC, c] = cash_operating(aircraft, C_airframe, C_engine_each)
        % Per-trip cash operating cost. Acquisition cost is NOT included here --
        % it enters through depreciation and insurance in fixed_operating().
        CEF89 = cost_escalation_factor(1989, aircraft);
        CEF99 = cost_escalation_factor(1999, aircraft);
         
        c.crew = aircraft.AF * (aircraft.K_route * aircraft.MTOW^0.4 * aircraft.tb) * CEF99;
         
        c.fuel = 1.02 * aircraft.W_f   * aircraft.P_f   / aircraft.rho_f;
        c.oil  = 1.02 * aircraft.W_oil * aircraft.P_oil / aircraft.rho_oil;
        c.elec = 1.05 * aircraft.W_b * aircraft.P_elec;
         
        c.airport = 1.5 * (aircraft.MTOW/1000) * CEF99;
        c.nav     = 0.5 * CEF89 * (1.852*aircraft.R/aircraft.tb) * sqrt((0.00045359237*aircraft.MTOW)/50);
         
        % airframe maintenance ($/block hr -> $/trip)
        C_MLA     = 1.03 * (3 + 0.067*C_airframe/1000) * aircraft.R_L;
        C_MMA     = 1.03 * (30*CEF89 + 0.79e-5 * C_airframe);
        c.maint_af = (C_MLA + C_MMA) * aircraft.tb;
         
        % engine maintenance ($/block hr per engine -> $/trip, all engines)
        shp_each   = aircraft.SHP_to / max(aircraft.n_engines, 1);
        C_MLE      = 1.03 * 1.3 * (0.4956 + 0.0532*(shp_each/1000)*(1100/aircraft.H_em) + 0.1) * aircraft.R_L;
        C_MME      = 1.03 * (30*CEF89 + 0.79e-5 * C_engine_each);   % placeholder form
        c.maint_eng = aircraft.n_engines * (C_MLE + C_MME) * aircraft.tb;
         
        COC = c.crew + c.fuel + c.oil + c.elec + c.airport + c.nav + ...
              c.maint_af + c.maint_eng;
    end
     
    %% ---------------------------------------------------
    
    % run cash operating function
    [COC, c] = cash_operating(aircraft, C_airframe, C_engine_each);
    
    %% ---------------------------------------------------
     
    function [FOC, DOC, f] = fixed_operating(aircraft, C_aircraft, COC)
        % Per-trip ownership cost. Financing and registration are fractions of DOC,
        % and DOC contains them, so solve in closed form:
        %   DOC = (COC + dep + ins) / (1 - f_fin - k_reg)
        f.U_annual = 1.5e3 * (3.4546*aircraft.tb + 2.994 - ...
                     (12.289*aircraft.tb^2 - 5.6626*aircraft.tb + 8.964)^0.5);   % [block hr/yr]
         
        f.dep = C_aircraft * (1 - aircraft.K_dep) * aircraft.tb / (aircraft.n_life * f.U_annual);
        f.ins = (aircraft.IR_a * C_aircraft / f.U_annual) * aircraft.tb;
         
        k_reg = 0.001 + 1e-8 * aircraft.MTOW;
        DOC   = (COC + f.dep + f.ins) / (1 - aircraft.f_financing - k_reg);
        f.fin = aircraft.f_financing * DOC;
        f.reg = k_reg   * DOC;
         
        FOC = f.dep + f.ins + f.fin + f.reg;
    end
    
    %% ---------------------------------------------------
    
    % run fixed operating cost code
    [FOC, DOC, f] = fixed_operating(aircraft, C_aircraft, COC);
    
    %% ---------------------------------------------------
     
    function [IOC, i] = indirect_operating(aircraft)
        % Per-trip indirect operating cost, 2001 base.
        CEF = cost_escalation_factor(2001, aircraft);
        n = aircraft.n_pax; PLF = aircraft.PLF; tb = aircraft.tb; R = aircraft.R;
         
        C_f = aircraft.ticket_price / R;          % [$/pax-nmi] yield
         
        i.serv    = (0.285 + 0.0025) * (n/tb) * CEF;
        i.food    = 1.05 * (2.42*(n/(1+aircraft.R_p)) + (n*aircraft.R_p)/(1+aircraft.R_p)) * CEF;
        i.ent     = 196/tb * CEF;
        i.pax_ins = 0.52 * (n*PLF*R/(1000*tb)) * CEF;
         
        i.paxh  = 2.87   * (n*PLF/tb) * CEF;
        i.bagh  = 1.31   * (n*PLF/tb) * CEF;
        i.cargh = 131.08 * (n*PLF/tb) * CEF;
         
        i.res = 4.4   * (n*PLF/tb) * CEF;
        i.pub = 0.023 * (R*C_f*n*PLF/tb) * CEF;
         
        i.comm = 2.35 * (n*PLF*R/(1000*tb)) * CEF;
        i.gen  = 0.18 * (n/tb) * CEF;
         
        IOC = i.serv + i.food + i.ent + i.pax_ins + i.paxh + i.bagh + i.cargh + ...
              i.res + i.pub + i.comm + i.gen;
    end
    
    %% ---------------------------------------------------
    
    % run indirect operating cost function
    [IOC, i] = indirect_operating(aircraft);
    
    %% ---------------------------------------------------
    
    % function takes structs created by each cost calculation step and
    % generates tables 
    
    function T = struct_to_table(s, total_name, total_value)
        % Turns any scalar-valued struct into an Item/Cost table, with a total
        % row appended at the bottom. Field names become row labels (underscores
        % -> spaces, capitalized).
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
    
    
    c.T1 = struct_to_table(c, 'Cash Operating Cost', COC);
    c.T2 = struct_to_table(f, 'Fixed Operating Cost', FOC);
    c.T3 = struct_to_table(i, 'Indirect Operating Cost', IOC);
    c.T0 = struct_to_table(a, 'Aircraft Cost', C_aircraft);
    c.tot_cost = C_aircraft + IOC + DOC + FOC;

    % scalar outputs for plotting / sweeps 
    c.COC = COC;  c.FOC = FOC;  c.DOC = DOC;  c.IOC = IOC;
    c.C_aircraft = C_aircraft;
    c.tot_cost = C_aircraft + IOC + DOC + FOC;

end