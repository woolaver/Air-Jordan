function [W0, out] = weightIterationEstimate_corrected(P, W0, S, WdivSDesign, eta, aircraft)
    require_fields(aircraft, {'AR','eb_star','e_range','battery_degredation', ...
        'electric_efficiency','prop_efficiency','specific_fuel_consumption_cruise', ...
        'R_fuel','L_D'}, mfilename);
    aircraft = defaults(aircraft);
    elec = hybrid_data(aircraft);
    eta  = aircraft.prop_efficiency;   % single source; the eta input is kept so old calls still run
    
    tol = 1e-5; maxit = 200;
    A = 1.4; C = -0.10;                       % Raymer GA twin
    W_crew    = 190*8;
    W_payload = 30*8;
    
    P_electric   = P*elec.Hp;
    W_elec_motor = (P_electric/elec.motor_power_each)*elec.w_motor_each;
    R_ft      = elec.R*6076;
    e_battery = elec.eb_Whkg*3600;
    
    for i = 1:maxit
        [Wf, Wf_W0, L_D] = fuel_fraction_calc(P, W0, aircraft);
    
        W_ec   = W0*(1 - Wf_W0);
        work_J = (W_ec*R_ft/L_D)*1.35582;
        W_batt = work_J/(eta*elec.eta_batt*e_battery*elec.degradation)*2.20462;
    
        S_ref   = W0/aircraft.WS_ref;
        dW_wing = aircraft.rhoWing*aircraft.f_exposed*(S - S_ref);
        dW_tail = aircraft.rhoTail*(tail_area(S, aircraft) - tail_area(S_ref, aircraft));
    
        WE    = A*W0^(1+C) + dW_wing + dW_tail + W_elec_motor + W_batt;
        WE_W0 = WE/W0;
        denom = 1 - Wf_W0 - WE_W0;
        if denom <= 0
            W0 = NaN;
            break
        end
        W0_new = (W_crew + W_payload)/denom;
        if abs(W0_new - W0)/abs(W0_new) < tol    % test the un-relaxed step (old test ran after relaxing W0)
            W0 = W0_new;
            break
        end
        W0 = W0 + 0.2*(W0_new - W0);
    end
    
    [~, Sh, Sv] = tail_area(S, aircraft);
    out = struct('W0',W0,'WE',WE,'Wf',Wf,'W_batt',W_batt,'W_ec',W_ec, ...
        'W_elec_motor',W_elec_motor,'W_crew',W_crew,'W_payload',W_payload, ...
        'dW_wing',dW_wing,'dW_tail',dW_tail,'S_ht',Sh,'S_vt',Sv,'L_D',L_D);
end

function [St, Sh, Sv] = tail_area(S, aircraft)
    b  = sqrt(aircraft.AR*S);  c = S/b;
    Sh = aircraft.cHT*c*S/aircraft.l_ht;
    Sv = aircraft.cVT*b*S/aircraft.l_vt;
    St = Sh + Sv;
end

function aircraft = defaults(aircraft)
    d = struct('rhoWing',2.5,'rhoTail',2.0,'f_exposed',0.90,'WS_ref',26, ...
        'cHT',0.90,'cVT',0.06,'l_ht',30.8,'l_vt',23.3);
    f = fieldnames(d);
    for i = 1:numel(f)
        if ~isfield(aircraft,f{i}), aircraft.(f{i}) = d.(f{i}); end
    end
end

function elec = hybrid_data(aircraft)
    elec.Hp               = 0.8;                            % hybrid power split
    elec.motor_power_each = 188;                            % hp per motor
    elec.w_motor_each     = 33;                             % lb
    elec.R                = aircraft.e_range;               % nmi electric cruise
    elec.eb_Whkg          = aircraft.eb_star/3600;          % driver stores J/kg
    elec.degradation      = aircraft.battery_degredation;   % driver's spelling
    elec.eta_batt         = aircraft.electric_efficiency;   % battery+motor+wiring
end
