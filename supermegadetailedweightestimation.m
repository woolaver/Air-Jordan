% super mega detailed weight estimation (adapted from Algorithm 5 Metabook)

function [W, aircraft] = supermegadetailedweightestimation(Wguess, P, aircraft)
% more detailed weight buildup using metabook and chosen systems

    W0 = Wguess;

    % constant weights (RFP)
    W_payload = aircraft.payload_weight;

    % composite fudge factors
    composite_wing_factor = 0.9;
    composite_stabilizer_factor = 0.85;
    composite_fuselage_factor = 0.92;

    % chosen design weights/parameters
    n_prop = aircraft.num_propeller;
    W_prop_weight = aircraft.prop_weight  * n_prop;
    W_electric_motors = n_prop * aircraft.weight_electric_motors;
    % load factor
    Nz = aircraft.ultimate_load_factor;
    
    % calculate dynamic pressure
    rho = density_isa_offset(aircraft.alt_cr, aircraft.dT_K);                 % slug/ft^3
    V_cr = aircraft.V_cr * 1.688;          % ft/s
    q_cruise = 0.5 * rho * V_cr^2;         % lb/ft^2

    
    R_ft = aircraft.e_range * 6076; % electric cruise range in feet
    e_battery = aircraft.eb_star; % Joules
    
    PW = aircraft.P_W;
    WS = aircraft.W_S;
    

    % set-up iteration
    converged = false;
    tol = 0.1;
    W_press = 104; % weight of pressurization, lbs
    if isfield(aircraft,'W_pressurization'), W_press = aircraft.W_pressurization; 
    end
    it = 0; maxit = 250;
    while ~converged
        % components that scale with W0 (all use the current W0)
        P = PW * W0;
        [Wf, Wf_W0, L_D, ff] = fuel_fraction_calc_refined(P, W0, aircraft);   % ff.W_reserve: IFR reserve fuel
        Wf_res = aircraft.k_F_res*ff.W_reserve;  Wf = aircraft.k_F_trip*(Wf - ff.W_reserve) + Wf_res;  ff.W_reserve = Wf_res;   % calibrated to the time-stepped 400 nmi mission (TG in climb, hold at 5,000 ft)
        aircraft.L_D = L_D;
        aircraft.wing_area = (WS / W0)^-1;
        % aircraft.wing_area = 733;
        Wl = 0.97*W0;
        % get fuel volume
        aircraft.fuel_density = 760/16.018; % fuel dens used in turbogenerators
        aircraft.fuel_volume = Wf/aircraft.fuel_density;
        W_ec       = W0*(1 - Wf_W0);
        work_cruise_J = (W_ec*R_ft/L_D)*1.35582;              % 200 nmi cruise [J]
        work_climb_J  = 0;   % W*h comes back in the glide descent (h*L/D, about 75 nmi of the 200 nmi)
        LD_max_e   = 1/(2*sqrt(aircraft.CD0_clean/(pi*aircraft.e_cr*aircraft.AR)));   % best-range L/D for the divert
        work_app_J = aircraft.approach_power_frac*aircraft.max_power*aircraft.t_app*3600*1.35582;   % one approach at approach power [J]
        work_TO_J  = aircraft.max_power*60*1.35582 + work_app_J + 0.02*W0*15190*1.35582;   % 1 min full power + approach at the destination + electric taxi (rolling resistance 0.02*W over 2.5 nmi) [J]
        work_em_J  = (W_ec*aircraft.R_em*6076.1/LD_max_e)*1.35582;   % TG fails at 5,000 ft in the descent: 25 nmi to the alternate at L/D max [J];
                                                                  % no missed approach; the approach + landing at the alternate replaces the destination approach already in work_TO_J
        work_J        = work_cruise_J + work_climb_J + work_TO_J + work_em_J;                                % J
        eta_e = aircraft.prop_efficiency*aircraft.electric_efficiency;
        W_battery = aircraft.k_E*(work_cruise_J + work_climb_J + work_TO_J + work_em_J)/(eta_e*e_battery)*2.20462;   % NEW pack: 200 nmi + divert end at the 10 % SOC floor [lb]% emergency reserve still there at end of life [lb]
        W_wing     = composite_wing_factor * 0.036*aircraft.wing_area^(0.758) * (aircraft.AR / cosd(aircraft.wing_sweep)^2)^0.6 * q_cruise ^0.006 * ...
                     aircraft.taperratio^0.04 *(100 * aircraft.wing_tc / cosd(aircraft.wing_sweep))^-0.3 * (Nz*W0)^0.49;
        W_horizontaltail = composite_stabilizer_factor * 0.016 * (Nz * W0)^0.414 * q_cruise^0.168 * aircraft.horiz_area^0.896 * (100 * aircraft.horiz_tc / ...
                            cosd(aircraft.wing_sweep))^-0.12 * (aircraft.horiz_AR / cosd(aircraft.horiz_sweep)^2)^0.043 * aircraft.horiz_taper ^-0.02;
        W_verticaltail = composite_stabilizer_factor * 0.073 * (1 + 0.2 *1) * (Nz * W0) ^0.376 * q_cruise^0.122 * aircraft.vert_area^0.873 * (100 * aircraft.vert_tc / ...
                           cosd(aircraft.vert_sweep))^-0.49 * (aircraft.vert_AR / cosd(aircraft.vert_sweep)^2)^0.357 * aircraft.vert_taper ^0.039;
        W_fuselage    = composite_fuselage_factor * 0.052 * aircraft.S_wet_fuselage^1.086 * (Nz * W0) ^0.177 * aircraft.Lt ^-0.051 * (aircraft.L_D) ^-0.072 * q_cruise^0.241 + W_press;
        %W_mainlanding_gear = 0.095*(Nl * Wl)^0.768 *(aircraft.main_gear_length /12 )^0.845;
        %W_noselanding_gear = 0.125 * (Nl * W1)^0.566 *  (aircraft.nose_gear_length / 12)^0.845;

        W_turbogenerators = aircraft.weight_turbogenerators * aircraft.n_turbogenerators;
        
        W_fuel_system = 2.49 * aircraft.fuel_volume^0.726 * (1 / (1 + aircraft.fuel_volume * 1.1 / aircraft.fuel_volume))^0.363 * aircraft.n_fuel_tanks^0.242 * aircraft.n_turbogenerators^0.157;
        W_flight_controls = 0.053 * aircraft.fuselage_length^1.536 * aircraft.wing_span^0.371 * (Nz*W0 * 1e-4)^0.8;
        W_hydraulics = 0.001 * W0;
        W_avionics = 2.117 * 150^0.933;
        W_electrical = 12.57 * (W_fuel_system + W_avionics)^0.51;
        W_aircon_anti_ice = 0.265 * W0^0.52 * aircraft.num_crew^0.68 * W_avionics^0.17 * (V_cr / 589)^0.08;
        W_furnishings = 0.0582 * W0 - 65;
        W_landinggear = 0.043 * W0 * (0.8*(aircraft.main_gear_length/24)^0.409 + 0.2*(aircraft.nose_gear_length/24)^0.845);   % length exponents Raymer GA main/nose gear
 

        % total weight
        W0_new = Wf + W_payload + W_prop_weight + W_turbogenerators + W_electric_motors + ...
                 W_battery + W_fuselage + W_horizontaltail + ...
                 W_verticaltail + W_wing + W_landinggear + W_fuel_system + ... 
                 W_flight_controls + W_hydraulics + W_avionics + W_electrical + W_furnishings + W_aircon_anti_ice;
       
        converged = abs(W0_new - W0) <= tol;
        W0 = W0_new;
                it = it + 1;
        if it >= maxit || W0 > 60000 || ~isfinite(W0)
            warning('Weight iteration did not converge (alt %.0f ft, W0 = %.0f lb)', aircraft.alt_cr, W0);
            W0 = NaN;  Wf = NaN;  W_battery = NaN;
            break
        end
    end

    W.payload = W_payload;
    W.fuel_weight = Wf;
    W.fuel_system_weight = W_fuel_system;
    
    W.prop_weight = W_prop_weight;
    W.turbogenerator_weight = W_turbogenerators;
    W.electricmotor_weight = W_electric_motors;
    W.battery_weight = W_battery;
    W.fuselage_weight = W_fuselage;
    W.horizontaltail_weight = W_horizontaltail;
    W.verticaltail_weight = W_verticaltail;
    W.wing_weight = W_wing;
    W.landinggear_weight = W_landinggear;
    W.aircon_and_anti_ice = W_aircon_anti_ice;
    W.furnishings = W_furnishings;
    W.electrical = W_electrical;
    W.avionics = W_avionics;
    W.hydraulics = W_hydraulics;
    W.flight_controls = W_flight_controls;
    W.airframe = W_fuselage + W_verticaltail + W_horizontaltail + W_wing + W_landinggear + W_hydraulics;
    W.emptyweight = W.airframe + W_prop_weight + W_turbogenerators + W_electric_motors + W_battery + ...
                     W_fuel_system + W_furnishings + W_avionics + W_electrical + W_aircon_anti_ice + W_flight_controls;
    W.MTOW = W.emptyweight + W_payload + Wf;

    names = {'Payload','Fuel','Fuel System Weight','Fuselage','Wing','H-Tail','V-Tail','Landing Gear', 'Anti-Ice & Airconditioning', ...
        'Furnishings', 'Avionics', 'Flight Controls', 'Hydraulics', 'Props','Turbogens','E-Motors','Wiring', 'Battery', 'Airframe','Empty','MTOW'};
    vals  = [W.payload, W.fuel_weight, W.fuel_system_weight, W.fuselage_weight, W_wing, W.horizontaltail_weight, ...
        W.verticaltail_weight, W.landinggear_weight, W.aircon_and_anti_ice, W.furnishings, W.avionics, W.flight_controls, W.hydraulics,  W.prop_weight, ...
        W.turbogenerator_weight, W.electricmotor_weight, W.electrical, W_battery, ...
        W.airframe, W.emptyweight, W.MTOW]';
    T = table(names', vals, 100*vals/W.MTOW, 'VariableNames', {'Component','Weight_lb','Pct_MTOW'});
    disp(T)

    % update aircraft struct
    aircraft.wing_area = (WS/ W0)^-1;
    aircraft.W0 = W.emptyweight + W_payload + Wf;
    aircraft.Wf = Wf;
    aircraft.W_payload = W_payload;
    aircraft.W_electric_motors = W_electric_motors;
    aircraft.W_battery = W_battery;
        aircraft.Wf_reserve    = ff.W_reserve;                       % lb, IFR reserve: in MTOW, not burned on the design mission
    aircraft.Wf_trip       = Wf - ff.W_reserve;                  % lb, design-mission fuel (cost, emissions)
    aircraft.E_mission_kWh = aircraft.k_E*(work_cruise_J + work_climb_J + work_TO_J)/eta_e/3.6e6;   % battery energy of the 200 nmi mission
    aircraft.E_em_kWh      = aircraft.k_E*work_em_J/eta_e/3.6e6;             % emergency reserve energy: in the pack, not used on the mission
    aircraft.E_batt        = W_battery/2.20462*e_battery/3.6e6; % kWh usable pack capacity (purchase price)
    aircraft.P = P;
   
end
