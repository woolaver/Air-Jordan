% super mega detailed weight estimation (adapted from Algorithm 5 Metabook)

function [W] = supermegadetailedweightestimation(Wguess, P, aircraft)
% more detailed weight buildup using metabook and chosen systems

    W0 = Wguess;

    % constant weights (RFP)
    W_payload = aircraft.payload_weight;

    % chosen design weights/parameters
    n_prop = aircraft.num_propeller;
    W_prop_weight = aircraft.prop_weight  * n_prop;
    n_turbogenerators = aircraft.n_turbogenerators;
    W_turbogenerators = n_turbogenerators * aircraft.weight_turbogenerators;
    W_electric_motors = n_prop * aircraft.weight_electric_motors;
    W_reserve_battery = aircraft.reserve_battery_weight;   % 100 nmi diversion sizing

    % airframe component weights
    W_fuselage = 1.4 * aircraft.S_fuselage;
    W_horizontaltail = 2 * aircraft.horiz_area;
    W_verticaltail = 2 * aircraft.vert_area;
    Nz = aircraft.ultimate_load_factor;
    % W_wing = 0.0051 * (W0 * N_zg) ^0.557 * S0^0.649 * (AR)^0.5 * ();  %
    % which is better guess? long form or Raymer based on area
    % W_wing = 2.5 * aircraft.wing_area;


    R_ft = aircraft.e_range * 6076; % electric cruise range in feet
    e_battery = aircraft.eb_star; % Joules

    % set-up iteration
    converged = false;
    tol = 0.1;
    W_press = 0;
    if isfield(aircraft,'W_pressurization'), W_press = aircraft.W_pressurization; 
    end
    it = 0; maxit = 200;
    while ~converged
        % components that scale with W0 (all use the current W0)
        [Wf, Wf_W0, L_D] = fuel_fraction_calc_refined(P, W0, aircraft);
        W_ec       = W0*(1 - Wf_W0);
        work_J     = (W_ec*R_ft/L_D)*1.35582;                                   % J
        W_battery  = work_J/(aircraft.prop_efficiency*aircraft.electric_efficiency* ...
                     e_battery*aircraft.battery_degredation)*2.20462;           % lb
        W_wing     = 0.0051*(W0*Nz)^0.557 * aircraft.wing_area^0.649 * aircraft.AR^0.5 * ...
                     (0.154)^(-0.4) * (1 + aircraft.taperratio)^0.1 * ...
                     (cos(aircraft.wing_sweep))^(-1) * aircraft.wing_control_surf_area^0.1;
        W_landinggear = 0.043*W0;
        W_extra       = 0.1*W0;

        % total weight
        W0_new = Wf + W_payload + W_prop_weight + W_turbogenerators + W_electric_motors + ...
                 W_battery + W_reserve_battery + W_fuselage + W_horizontaltail + ...
                 W_verticaltail + W_wing + W_landinggear + W_extra + W_press;

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
    
    W.prop_weight = W_prop_weight;
    W.turbogenerator_weight = W_turbogenerators;
    W.electricmotor_weight = W_electric_motors;
    W.battery_weight = W_battery;
    W.fuselage_weight = W_fuselage;
    W.horizontaltail_weight = W_horizontaltail;
    W.verticaltail_weight = W_verticaltail;
    W.wing_weight = W_wing;
    W.landinggear_weight = W_landinggear;
    W.extra_weight = W_extra;
    W.reserve_battery_weight = W_reserve_battery;
    W.airframe = W_fuselage + W_verticaltail + W_horizontaltail + W_wing + W_landinggear + W_extra + W_press;
    W.emptyweight = W.airframe + W_prop_weight + W_turbogenerators + W_electric_motors + W_battery + W_reserve_battery;
    W.MTOW = W.emptyweight + W_payload + Wf;

    names = {'Payload','Fuel','Fuselage','Wing','H-Tail','V-Tail','Landing Gear', ...
        'Props','Turbogens','E-Motors','Battery', 'Reserve Battery', 'Extra', 'Airframe','Empty','MTOW'};
    vals  = [W.payload, W.fuel_weight, W.fuselage_weight, W_wing, W.horizontaltail_weight, ...
        W.verticaltail_weight, W.landinggear_weight, W.prop_weight, ...
        W.turbogenerator_weight, W.electricmotor_weight, W_battery, W_reserve_battery, W_extra ...
        W.airframe, W.emptyweight, W.MTOW]';
    T = table(names', vals, 100*vals/W.MTOW, 'VariableNames', {'Component','Weight_lb','Pct_MTOW'});
    disp(T)
end
