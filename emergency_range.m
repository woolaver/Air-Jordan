

function out = emergency_range(aircraft, W0_lb, S, W_batt_lb, P_inst_hp)
  
    lb2kg = 0.45359237;  ftlbf_per_J = 0.737562;
    W   = aircraft.Wem_W0*W0_lb;                 
    rho = aircraft.rho_em;                        
    eta = aircraft.prop_efficiency;
    CD0 = aircraft.CD0_clean;                     %
    k   = 1/(pi*0.825*aircraft.AR);               
    h   = aircraft.h_fail_agl;
    

    E = W_batt_lb*lb2kg*aircraft.eb_star*aircraft.battery_degredation* ...
        aircraft.electric_efficiency*eta*ftlbf_per_J;
    
    kts = linspace(50, 250, 400);   V = kts*1.688;            % [ft/s]
    q   = 0.5*rho*V.^2;
    D   = q*S*CD0 + (W^2*k)./(q*S);                           
    P_req   = D.*V/(550*eta);                                 % [hp]
    P_avail = aircraft.Hp*P_inst_hp;                          % [hp]
    
    R_level = E./D/6076;                                      % [nmi] 
    R_alt   = (E + W*h)./D/6076;                              % [nmi] 
    bad = P_req > P_avail;   R_level(bad) = NaN;   R_alt(bad) = NaN;
    [R_best, i] = max(R_alt);
    
    out = struct('R_nmi_level',max(R_level),'R_nmi_with_alt',R_best,'V_best_kts',kts(i), ...
        'P_req_best_hp',P_req(i),'P_avail_hp',P_avail,'LD_max',1/(2*sqrt(CD0*k)));
    fprintf('Emergency range: %.0f nmi at %.0f kts (%.0f nmi holding altitude) | L/D max %.1f | %.0f of %.0f hp\n', ...
        R_best, kts(i), out.R_nmi_level, out.LD_max, P_req(i), P_avail);
    
    figure; tiledlayout(2,1);
    nexttile; plot(kts, R_level, kts, R_alt, 'LineWidth', 1.5); hold on; grid on
    plot(kts(i), R_best, 'ko', 'MarkerFaceColor', 'y');
    ylabel('Range (nmi)'); title('Battery-only emergency range, turbogenerator failed');
    legend('Hold altitude','Use 5,000 ft','Best range','Location','best');
    nexttile; plot(kts, P_req, 'LineWidth', 1.5); grid on
    yline(P_avail, 'r--', 'Battery-fed motor power');
    xlabel('Airspeed (kts)'); ylabel('Power required (hp)');
end