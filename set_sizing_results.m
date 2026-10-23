function a = set_sizing_results(aircraft, P, W0, Ws)
    % The one place sizing results are mapped onto the fields aircraftcost reads.
    % Called by the driver AND by the P-S cost mesh, so they can't drift apart.
    a = aircraft;
    a.MTOW       = W0;                                        % [lb]
    a.SHP_to     = P;                                         % [hp]
    a.P_motor_hp = a.f_motor_power*P;                         % [hp]
    a.W_f        = Ws.Wf;                                     % [lb]
    a.W_oil      = 0.0125*Ws.Wf*a.tb/100;                     % [lb]
    a.W_b        = Ws.W_batt;                                 % [lb]
    a.E_batt     = a.W_b*0.45359237*(a.eb_star/3600)/1000;    % [kWh] installed pack energy
end