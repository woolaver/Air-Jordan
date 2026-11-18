function[P_point, S_point, aircraft] = PS_constraintcurves(S_sweep, W0, aircraft)

       %{ 
        require_fields(aircraft, {'AR','Cf_clean','CLmax_to','Wcr_W0','Wce_W0','Wclimb_W0', ...
        'Wland_W0','Pcr_P0','prop_efficiency','alt_cr','V_cr','rho_takeoff', ...
        'num_propeller','design_margin', 'rho_em', 'Wem_W0', 'G_em', 'Hp'}, mfilename); 
        %}
    
    W0_guess = aircraft.W0;                   
    S_sweep  = S_sweep(:);
    
    env.rho    = aircraft.rho_takeoff;     % same takeoff/landing density as preliminary_Sizing
    env.rho_sl = 0.002377;
    [~, ~, ~, rho_cr_SI] = atmoscoesa(aircraft.alt_cr*0.3048);   % alt_cr is ft, atmoscoesa wants m
    env.rho_cr  = rho_cr_SI/515.4;                               % kg/m^3 -> slug/ft^3
    env.rho_ce  = .001545;
    env.rho_400 = 0.0016196;
    env.V_cr = aircraft.V_cr*1.688;                              % kts -> ft/s
    env.q_cr = 0.5*env.rho_cr*env.V_cr^2;
    
    env.sTOG = 300/1.66;
    a = 0.009; b = 4.9;
    env.TOP = (-b + sqrt(b^2 + 4*a*env.sTOG))/(2*a);
    
    env.sland   = 300   ;
    env.WS_land = (env.sland/80)*(env.rho/env.rho_sl)*aircraft.CLmax_land/aircraft.Wland_W0;
    
    
    names = {'Takeoff', 'Cruise', 'Ceiling', 'Takeoff Climb', 'Critical Loss of Thrust', 'Balked Landing Climb', 'Maneuever', 'Emergency Range'};

    nC = numel(names);
    nS = numel(S_sweep);
    P = nan(nS, nC);
    Wc = nan(nS, nC);

   %{
    disp("W0 entering PS function = " + W0)
    disp("W/S design point = " + W_S_point)
    disp("S design point = " + S_point)
    disp("S sweep min = " + min(S_sweep))
    disp("S sweep max = " + max(S_sweep))
    %}

    % Solve each P-S Constraint
    P_prev = 1500 * ones(1, nC);
    weightstruct = struct();
    for i = 1:nS
        S = S_sweep(i);
        for k = 1:nC
            Pk = P_prev(k);
            ok = false;
            for it = 1:100
                [W0, weightstruct] = weightIterationEstimate_corrected(Pk, W0, S, aircraft.W_S, aircraft.prop_efficiency, aircraft);
               % disp("Pk = " + Pk)
              %  disp("W0 iteration = " + W0)
                if ~isfinite(W0), break, end            
                pw    = pw_all(W0, S, aircraft, env);         
               % disp("P/W values:")
               % disp(pw)
               
                P_new = pw(k)*W0;                       
               %  disp("P_new = " + P_new)
                if abs(P_new - Pk)/abs(P_new) < 1e-4
                    Pk = P_new;  ok = true;  break
                end
                Pk = Pk + 0.5*(P_new - Pk);             
            end
            if ok
                P(i,k) = Pk;  Wc(i,k) = W0;  P_prev(k) = Pk;
            else
                P_prev(k) = 1500;                       
            end
        end
    end

    % landing
    P_grid = linspace(0, 3500, 40)';
    S_landcurve = nan(size(P_grid));
    for i = 1:numel(P_grid)
        f = @(S) W0_of_PS(P_grid(i), S, aircraft.W0, aircraft)/S - env.WS_land;
        try
            S_landcurve(i) = fzero(f, [S_sweep(1) S_sweep(end)]);
        catch
            % no sign change in the sweep range, leave NaN
        end
    end
    % find intial design point
    
    % design point: landing curve meets the constraint envelope
    [Penv, ~] = max(P, [], 2);
    m = isfinite(S_landcurve);

    Penv_at = interp1(S_sweep, Penv, S_landcurve(m), 'linear');   % envelope power at each landing-curve S
    d = Penv_at - P_grid(m);                                      % sign change = crossing
    j = find(d(1:end-1).*d(2:end) <= 0, 1);

    if isempty(j)
        warning('Landing curve never crosses the constraint envelope in this sweep.');
        S_point = NaN;  P_point = NaN;
    else
        Sm = S_landcurve(m);  Pm = P_grid(m);
        t  = d(j)/(d(j) - d(j+1));
        S_design = Sm(j) + t*(Sm(j+1) - Sm(j));
        P_design = Pm(j) + t*(Pm(j+1) - Pm(j));
        S_point  = S_design*(1 + aircraft.design_margin);
        P_point  = P_design*(1 + aircraft.design_margin);
    end

    aircraft.P_point = P_point;
    aircraft.S_point = S_point;

   
    %{
disp("P-S design point: S = " + S_point + " ft^2, P = " + P_point + ...
        " hp (governed by " + names{kd} + ")")
    %}
 %   disp("Landing limit: minimum S = " + S_land + " ft^2")

    
    
    % -------------------------------
    %  plot 
    %colors = {'blue','red','magenta','green',[0.85 0.7 0],'cyan',[0.729 0.1 0.925]};
    figure(); hold on;
    h = gobjects(1, nC+2);
    for k = 1:nC
        h(k) = plot(S_sweep, P(:,k), 'LineWidth', 1.5, 'DisplayName', names{k});
    end
    m = isfinite(S_landcurve);
    h(nC + 1) = plot(S_landcurve(m), P_grid(m), 'k', 'LineWidth', 1.5, ...
        'DisplayName', 'Landing');

    % feasible region: above the envelope, to the right of the landing curve
    [Su, iu] = unique(S_landcurve(m));
    Pu = P_grid(m);  
    Pu = Pu(iu);
    P_up = interp1(Su, Pu, S_sweep, 'linear', NaN);
    f = isfinite(Penv) & isfinite(P_up) & P_up > Penv;
    if nnz(f) >= 2
        xs = S_sweep(f);
        fill([xs; flipud(xs)], [P_up(f); flipud(Penv(f))], [0.6 0.85 0.6], ...
            'FaceAlpha', 0.35, 'EdgeColor', 'none', 'HandleVisibility', 'off');
    end
  
    ylim([0 3500]);
    xlim([S_sweep(1) S_sweep(end)]);
    
    xlabel('Wing Area, S (ft^2)');
    ylabel('Power, P (hp)');
    title('P vs S');
    grid off; hold on;

    scatter(S_point, P_point, 'r', 'filled');
    hold on;

    %{
    %% Aircraft cost meshgrid over plot - objective function
    S_mesh = linspace(min(S_sweep), max(S_sweep), 40);
    P_mesh = linspace(0, 3200, 40);          % start above 0: price eq. uses log10(SHP)
    [Smesh, Pmesh] = meshgrid(S_mesh, P_mesh);
    Cmesh = nan(size(Smesh));
    N_motors = aircraft.num_propeller;
    for k = 1:numel(Smesh)
        Cmesh(k) = aircraft_cost_at_point(Pmesh(k), Smesh(k), W0_guess, W_S_point, aircraft);
    end
    Cmesh = Cmesh / 1e6;                       % $M

    hold on;
    Clevels = linspace(min(Cmesh(:)), max(Cmesh(:)), 12);   % or hand-pick, e.g. 4:0.5:12
    [C, hc] = contour(Smesh, Pmesh, Cmesh, Clevels, ...
        'LineColor', 'k', 'LineStyle', '--', 'LineWidth', 0.75);
    clabel(C, hc, 'FontSize', 8);
    h_cost = plot(nan, nan, 'k--', 'LineWidth', 0.75, 'DisplayName', 'Aircraft Cost Contours ($M, 2035)');
    
    % h3x motor design point
    N_motors = 10;    
    P_motor_kW = 140;   
    kW_to_hp = 1.34102;
    P_rated_hp = N_motors * P_motor_kW * kW_to_hp; 
    % Offtake losses
    eta_offtake = 0.94;                        
    P_avail_hp = P_rated_hp * eta_offtake;     
    S_discrete = S_land * 1.05; 

    %plot installed & net available power
    h_rated = yline(P_rated_hp, 'k--', 'LineWidth', 1.8, ...
        'DisplayName', sprintf('Installed Rated (%d x H3X, %.0f hp)', N_motors, P_rated_hp));
    h_avail = yline(P_avail_hp, ':', 'Color', [0.2 0.2 0.2], 'LineWidth', 1.5, ...
        'DisplayName', sprintf('Available Net (-6%% offtakes, %.0f hp)', P_avail_hp));
    %{
    %plot design point
    h_pt = plot(S_discrete, P_avail_hp, 'kp', 'MarkerSize', 14, ...
        'MarkerFaceColor', 'y', 'MarkerEdgeColor', 'k', 'LineWidth', 1.5, ...
        'DisplayName', sprintf('Final Design Point (S=%.0f ft^2, P=%.0f hp)', S_discrete, P_avail_hp));
    
    %}

   
    %}
    legend([h(1:nC+1)], 'Location', 'northeastoutside');
    hold off;


end


function val = aircraft_cost_at_point(P, S, W0_guess, W_S, aircraft)
    % Aircraft acquisition cost [$] at one (P [hp], S [ft^2]) point.
    val = NaN;
    try
        [W0_pt, Ws] = weightIterationEstimate_corrected(P, W0_guess, S, aircraft.W_S, ...
            aircraft.prop_efficiency, aircraft);
        if ~isfinite(W0_pt), return, end
        c   = aircraftcost(set_sizing_results(aircraft, P, W0_pt, Ws));
        val = c.C_aircraft;
    catch ME
        warning('Cost eval failed at P=%.0f hp, S=%.0f ft^2: %s', P, S, ME.message);
    end
end




%% function 'pw_all' contains all constraint equations from P/W - W/S Plot

function pw = pw_all(W0, S, aircraft, env)
    % Required P/W (hp/lb) for each constraint at a given W0 (lb) and S (ft^2)
    eta = aircraft.prop_efficiency;
    WS  = W0/S;
    
    Swet = 10^(-.0866 + .8099*log10(W0));
    CD0  = aircraft.Cf_clean*Swet/S;
    k_clean = 1/(pi*0.825*aircraft.AR);
    k_to    = 1/(pi*0.725*aircraft.AR);
    k_land  = 1/(pi*0.725*aircraft.AR);
    
    
    pw = zeros(1,8);
    pw(1) = WS/(env.TOP*(env.rho/env.rho_sl)*aircraft.CLmax_to);                       % takeoff
    
    WS_cr = WS*aircraft.Wcr_W0;                                                        % cruise
    pw(2) = (env.V_cr/(550*eta))*(env.q_cr/WS_cr*CD0 + WS_cr/env.q_cr*k_clean) ...
        *(aircraft.Wcr_W0/aircraft.Pcr_P0);
    
    Pce_P0 = (env.rho_ce/env.rho_sl)^0.8;                                       % ceiling
    WS_ce = WS*aircraft.Wce_W0;
    V_ce  = sqrt(2*WS_ce/(env.rho_ce*sqrt(CD0/k_clean)));     % best-L/D speed at ceiling [ft/s]
    pw(3) = (V_ce/(550*eta))*(0.001 + 2*sqrt(CD0*k_clean))*(aircraft.Wce_W0/Pce_P0);
    
    CD0_cfg = CD0 + .065 + .02;     % takeoff/landing flaps + gear
    pw(4) = climb_pw(0.04, aircraft.CLmax_to, 1.2, eta, aircraft.Wclimb_W0, env.rho,     env.rho_sl, CD0_cfg, k_to,   WS);
    pw(5) = aircraft.num_propeller/(aircraft.num_propeller-3)* ...
        climb_pw(0.01, aircraft.CLmax_to, 1.2, eta, aircraft.Wclimb_W0, env.rho_400, env.rho_sl, CD0_cfg, k_to,   WS);
    pw(6) = climb_pw(0.03, 5.0,               1.3, eta, aircraft.Wland_W0,  env.rho,     env.rho_sl, CD0_cfg, k_land, WS);
    
    n = 1/cos(deg2rad(25));                                                     % maneuver
    pw(7) = (env.V_cr/(550*eta))*(env.q_cr*CD0/WS_cr + WS_cr*n^2*k_clean/env.q_cr) ...
        *(aircraft.Wcr_W0/aircraft.Pcr_P0);
    CL_br = sqrt(CD0/k_clean);
    V_br  = sqrt(2*WS*aircraft.Wem_W0/(aircraft.rho_em*CL_br));        % ft/s
    pw(8) = aircraft.Wem_W0*(V_br/(550*eta))*(aircraft.G_em + 2*sqrt(CD0*k_clean))/aircraft.Hp;
    end
    
function pw = climb_pw(G, CLmax, ks, eta, Wfrac, rho_c, rho_sl, CD0_cfg, k, WS)
    CL = CLmax/ks^2;                       % CL actually flown at V = ks*Vstall
    LD = CL/(CD0_cfg + k*CL^2);            % L/D at that CL
    pw = Wfrac^(3/2)*sqrt(WS)*(G + 1/LD)/(18.97*eta*sqrt(rho_c/rho_sl)*sqrt(CL));
end

function W0 = W0_of_PS(P, S, W0_seed, aircraft)
W0 = W0_seed;
for j = 1:50
    W0_new = weightIterationEstimate_corrected(P, W0, S, aircraft.W_S, ...
        aircraft.prop_efficiency, aircraft);
    if ~isfinite(W0_new), W0 = NaN; return, end
    if abs(W0_new - W0) < 0.1, W0 = W0_new; return, end
    W0 = 0.5*W0 + 0.5*W0_new;
end
W0 = NaN;
end