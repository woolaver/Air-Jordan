function[P_point, S_point, out] = PS_constraintcurves(S_sweep, W0, W_S_point, p)


    S_point = W0 / W_S_point;
    S_sweep = S_sweep(:);

    AR = 11;
    W_S = 10.1463; 

   
    Cf_clean = .0045;

  
    CLmax_clean = 1.5;
 
    CLMax_to = 5;
    CLmax_climb = 3.472;

    % constant parameters
    env.rho  = 0.001640; %slug/ft^3, warm day in colorado (6800 ft, 90degF)
    env.rho_sl = 0.002377; %slug/ft^3
    env.alt_cr = 12500 * .3048; % cruise alt in meters
    [~, ~, ~, env.rho_cr] = atmoscoesa((env.alt_cr/3.281)); %kg/m^3
    env.rho_cr = env.rho_cr/515.4; %slug/ft^3
    env.rho_ce = .001545; %14,000 ft, FAA regulations state that unpressurized aircraft flying above 14,000 feet for more than 30 minutes will require supplemental oxygen for flight crew
    env.rho_400 = 0.0016196; %7200ft, 90degF (400 ft above colorado) 
    env.V_cr = 379.76; % ft/sec
    env.q_cr = 0.5 * env.rho_cr * env.V_cr^2;  % dynamic pressure

    env.sTOG = 300 / 1.66; % FAR 23 Takeoff Parameter
    a = 0.009; b = 4.9;
    env.TOP = (-b + sqrt(b^2 + 4 * a * env.sTOG)) / (2*a);

    env.sland = 300 * 0.75;
    env.WS_land = (env.sland / 80) * (env.rho / env.rho_sl) * CLMax_to / p.Wland_W0;
    
    names = {'Takeoff', 'Cruise', 'Ceiling', 'Takeoff Climb', 'Critical Loss of Thrust', 'Balked Landing Climb', 'Maneuever'};

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
    for i = 1:nS
        S = S_sweep(i);
        for k = 1:nC
            Pk = P_prev(k);
            ok = false;
            for it = 1:100
                [W0, weightstruct] = weightIterationEstimate_new(Pk, W0, S, W_S_point, p.prop_efficiency);
               % disp("Pk = " + Pk)
              %  disp("W0 iteration = " + W0)
                if ~isfinite(W0), break, end            
                pw    = pw_all(W0, S, p, env);         
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

    % ---------- envelope, landing limit, design point ----------
    [Penv, kmax] = max(P, [], 2);                       
    W0env = Wc(sub2ind(size(Wc), (1:nS)', kmax));
    WS_of_S = W0env./S_sweep;
    m = isfinite(WS_of_S);
    if nnz(m) >= 2
        S_land = interp1(WS_of_S(m), S_sweep(m), env.WS_land, 'linear', 'extrap');
    else
        S_land = NaN;
    end

    % ---------- Design point: Landing / Maneuver intersection ----------
    
    maneuver_idx = find(strcmp(names, 'Maneuever'));

    P_maneuver_land = interp1( ...
        S_sweep, P(:,maneuver_idx), S_land, 'linear');

    S_design = S_land * p.design_margin;
    P_design = P_maneuver_land * (p.design_margin);

    P_point = P_design;
    S_point = S_design;


    out = struct('S',S_sweep, 'P',P, 'W0',Wc, 'names',{names}, ...
        'S_land',S_land, 'P_env',Penv, 'P_point', P_design, 'S_point', S_design, 'WeightStruct', weightstruct);
    %{
disp("P-S design point: S = " + S_point + " ft^2, P = " + P_point + ...
        " hp (governed by " + names{kd} + ")")
    %}
    disp("Landing limit: minimum S = " + S_land + " ft^2")


    
    

    % ---------- plot ----------
    %colors = {'blue','red','magenta','green',[0.85 0.7 0],'cyan',[0.729 0.1 0.925]};
    figure(); hold on;
    h = gobjects(1, nC+2);
    for k = 1:nC
        h(k) = plot(S_sweep, P(:,k), 'LineWidth', 1.5, 'DisplayName', names{k});
    end
    ytop = 1.3*max(Penv, [], 'omitnan');
    if isfinite(S_land)
        h(nC+1) = xline(S_land, 'LineWidth', 1.5, 'Color', 'black', ...
            'DisplayName', 'Landing (min S)');
        f = isfinite(Penv) & S_sweep >= S_land;         % feasible region shading
        if nnz(f) >= 2
            xs = S_sweep(f);  ys = Penv(f);
            fill([xs; flipud(xs)], [ytop*ones(size(xs)); flipud(ys)], ...
                [0.6 0.85 0.6], 'FaceAlpha', 0.35, 'EdgeColor', 'none', ...
                'HandleVisibility', 'off');
        end
    else
        h(nC+1) = plot(nan, nan, 'DisplayName', 'Landing (n/a)');
    end
    % h(nC+2) = plot(S_point, P_point, 'r.', 'MarkerSize', 20, 'DisplayName', 'Design Point');
    ylim([0 3000]);
    xlim([S_sweep(1) S_sweep(end)]);
    
    xlabel('Wing Area, S (ft^2)');
    ylabel('Installed Power, P (hp)');
    title('P vs S');
    grid off; hold on;

    scatter(S_point, P_point, 'r', 'filled');
    hold on;


    %%  Weight meshgrid over plot
    

    S_mesh = linspace(min(S_sweep), max(S_sweep), 200);
    P_mesh = linspace(0, 3000, 200);

    [Smesh, Pmesh] = meshgrid(S_mesh, P_mesh);

    Wmesh = nan(size(Smesh));

    for i = 1:size(Smesh,1)
        for j = 1:size(Smesh,2)

            Ptest = Pmesh(i,j);
            Stest = Smesh(i,j);

            [Wtest, ~] = weightIterationEstimate_new( ...
                Ptest, W0, Stest, W_S_point, p.prop_efficiency);

            Wmesh(i,j) = Wtest;

        end
    end

    hold on;

    % Weight contours
    Wlevels = 5000:100:11000;

    [C,hc] = contour(Smesh, Pmesh, Wmesh, Wlevels, ...
        'LineColor', 'k', 'LineStyle', '--',  'LineWidth', 0.75);

    clabel(C,hc,'FontSize',8);
    h_weight = plot(nan, nan, 'k--', 'LineWidth', 0.75, 'DisplayName', 'Weight Contours');

    legend([h(1:nC), h(nC+1), h_weight], 'Location', 'best');


    hold off;

 
end






%% function 'pw_all' contains all constraint equations from P/W - W/S Plot

function pw = pw_all(W0, S, p, env)
% Required P/W (hp/lb) for each constraint at a given W0 (lb) and S (ft^2)
eta = p.prop_efficiency;
WS  = W0/S;

Swet = 10^(-.0866 + .8099*log10(W0));
CD0  = p.Cf_clean*Swet/S;
k_clean = 1/(pi*0.825*p.AR);
k_to    = 1/(pi*0.725*p.AR);
k_land  = 1/(pi*0.725*p.AR);

CLm = p.CLmax_to;
LD_to   = CLm/((CD0 + .065 + .02) + k_to  *CLm^2);
LD_land = CLm/((CD0 + .065 + .02) + k_land*CLm^2);

pw = zeros(1,7);
pw(1) = WS/(env.TOP*(env.rho/env.rho_sl)*p.CLmax_to);                       % takeoff

WS_cr = WS*p.Wcr_W0;                                                        % cruise
pw(2) = (env.V_cr/(550*eta))*(env.q_cr/WS_cr*CD0 + WS_cr/env.q_cr*k_clean) ...
    *(p.Wcr_W0/p.Pcr_P0);

Pce_P0 = (env.rho_ce/env.rho_sl)^0.8;                                       % ceiling
pw(3) = (350/(550*eta))*(0.001 + 2*sqrt(CD0*k_clean))*(p.Wce_W0/Pce_P0);

pw(4) = climb_pw(0.04, p.CLmax_to, 1.2, eta, p.Wclimb_W0, env.rho,     env.rho_sl, LD_to,   WS);
pw(5) = p.Neng/(p.Neng-3)* ...                                              
    climb_pw(0.01, p.CLmax_to, 1.2, eta, p.Wclimb_W0, env.rho_400, env.rho_sl, LD_to,   WS);
pw(6) = climb_pw(0.03, 5.0,        1.3, eta, p.Wland_W0,  env.rho,     env.rho_sl, LD_land, WS);

n = 1/cos(deg2rad(60));                                                     % maneuver
pw(7) = (env.V_cr/(550*eta))*(env.q_cr*CD0/WS + WS*n^2*k_clean/env.q_cr) ...
    *(p.Wcr_W0/p.Pcr_P0);
end

function pw = climb_pw(G, CLmax, ks, eta, Wfrac, rho_c, rho_sl, LD, WS)
    CL = CLmax/ks^2;
    pw = (Wfrac^(2/3))*sqrt(WS)*(G + 1/LD)/(18.97*eta*(rho_c/rho_sl)*sqrt(CL));
end

