
function [CO2, NOx, parts] = emissions_objective(P, aircraft)
    p = emissions_params();
    lb = 0.4536; % lbs to kg conversion factor 
    [WeightStruct, aircraft] = supermegadetailedweightestimation(aircraft.W0, P, aircraft);
    CO2 = NaN; NOx = NaN; parts = [];
    
    if ~isfinite(aircraft.W0), return, end
    % fuel burn
    m_fuel = aircraft.Wf * lb;
    parts.fuel  = m_fuel*(p.EI_CO2 + p.EI_WTT);

    % power grid
    E_grid = aircraft.eb_star / p.eta_charge;
    parts.grid  = E_grid*p.CI_grid;

    % battery manufacturing
    C_kWh  = aircraft.W_battery*lb * aircraft.battery.e_cell_Whkg * aircraft.battery.pack_factor / 1000;
    parts.batt  = C_kWh*p.k_batt/p.N_cycle;
   
    % general manufacturing
    N_life = p.flights_per_yr * p.life_yr;
    m_pwr  = WeightStruct.prop_weight + WeightStruct.turbogenerator_weight + WeightStruct.electricmotor_weight;
    parts.mfg   = (WeightStruct.airframe*lb*p.k_airframe + m_pwr*lb*p.k_pwr)/N_life;
    
    % CO2 and NOx emissions in kg
    CO2 = parts.fuel + parts.grid + parts.batt + parts.mfg;
    NOx = (m_fuel*p.EI_NOx + E_grid*p.EI_NOx_grid)/1000;  % kg
end



function p = emissions_params()
p.EI_CO2 = 3.16;  
p.EI_WTT = 0.55;  
p.EI_NOx = 8;     % kg/kg, kg/kg, g/kg
p.CI_grid = 0.20; 
p.EI_NOx_grid = 0.25; 
p.eta_charge = 0.92;
p.k_batt = 80;    
p.N_cycle = 1500;
p.k_airframe = 25; 
p.k_pwr = 15;
p.flights_per_yr = 1200; 
p.life_yr = 20;
p.k_primary = 120; 
p.shelf_life_yr = 5;
end
