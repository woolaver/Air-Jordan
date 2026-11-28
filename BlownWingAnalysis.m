function [takeoff_distance, landing_distance, aircraft] = BlownWingAnalysis(aircraft, converged)

    % Higher fidelity analysis of blown wing takeoff and landing parameters
    % Using geometric estimates when needed, will be commented when used
    
    %% Initial Wing and Propeller Layout
    
    AR = aircraft.AR; %From aircraftDesignDriver
    num_props = aircraft.num_propeller; 
    S = aircraft.wing_area; %ft^2 from updated P-S plot
    prop_diameter = aircraft.prop_diameter; %ft, just an initital guess, sized to get disk_area_ratio ~ .35
    Ad = num_props*(pi*prop_diameter^2)/4;
    
    disk_area_ratio = Ad/S;
    fB = min(num_props*prop_diameter/sqrt(AR*S), aircraft.f_span_max);   % blown span share n*D/b, x0.9 for slipstream contraction
    
    %% Thrust and slipstream speed from shaft power
    
    rho = aircraft.rho_takeoff; %slug/ft^3, 1.184 kg/m^3, ISA + 18F density
    P_sh = aircraft.max_power; %slug*ft^2/s^3, from updated P-S plot 1765 hp
    eta_a = aircraft.eta_a; %Taken from Cinar slides from X-57
    V = aircraft.landing_speed*1.688; %ft/s, from 55 kts landing speed
    delta_F = aircraft.delta_F; %deg, 60 degree flap deflection
    eta_F = aircraft.eta_F; %estimated from graph in Cinar slides
    
    function [delta_C_j, delta_j, T_c_prime, Vj] = calc_Tc(V, eta_a, rho, P_sh, Ad, disk_area_ratio, delta_F, eta_F) 
        fj = @(x) (rho*Ad/4)*(x - V).*((x + V).^2) - eta_a*P_sh;   % momentum balance, zero at the jet speed
        Vj = fzero(fj, [V, V + 1e4]);                               % same root, no symbolic toolbox
    
        T_c_prime = disk_area_ratio*((Vj^2/V^2) - 1);
        delta_C_j = T_c_prime*(1 + (V/Vj));
    
        delta_j = eta_F*delta_F;
    end
    
    [delta_C_j, delta_j, T_c_prime] = calc_Tc(V, eta_a, rho, P_sh, Ad, disk_area_ratio, delta_F, eta_F);
    
    
    %% Estimate the powered lift curve

    %Takeoff
    
    alpha = linspace(-10, 20, 1000);
    
    CL_u = .1856 + .0334*delta_F + .0667.*alpha;
    
    A0 = .1856 + .0334*delta_F + .0667.*alpha;
    A1 = .0121*delta_j - .0085.*alpha + .0426;
    A2 = .0140*delta_j + .0226.*alpha + .1407;
    
    F_Cj = A0 + A1*sqrt(delta_C_j) + A2*delta_C_j;
    
    F_0 = CL_u;
    
    CL_takeoff = CL_u + F_Cj - F_0;

    %Cruise
    rho_cr = aircraft.rho_cr;
    V_cr = aircraft.V_cr*1.688;

    CL_cruise = (aircraft.Wcr_W0 * aircraft.W0)/(.5*rho_cr*V_cr^2*aircraft.wing_area);

    CD_cruise = aircraft.CD0_clean + 1/(aircraft.e_cr*pi*AR)*CL_cruise^2;
    D_cruise = .5*rho_cr*V_cr^2*aircraft.wing_area*CD_cruise;

    Power_cruise = D_cruise*V_cr;

    throttle_cr = Power_cruise/P_sh;

    [delta_C_j, delta_j, T_c_prime] = calc_Tc(V_cr, eta_a, rho_cr, throttle_cr*P_sh, Ad, disk_area_ratio, delta_F, eta_F);

    delta_F_clean = 0;

    CL_u = .1856 + .0334*delta_F_clean + .0667.*alpha;
    
    A0 = .1856 + .0334*delta_F_clean + .0667.*alpha;
    A1 = .0121*delta_j - .0085.*alpha + .0426;
    A2 = .0140*delta_j + .0226.*alpha + .1407;
    
    F_Cj = A0 + A1*sqrt(delta_C_j) + A2*delta_C_j;
    
    F_0 = CL_u;

    CL_clean = CL_u + F_Cj - F_0;

    %Landing

    throttle = .15;

    [delta_C_j, delta_j, T_c_prime] = calc_Tc(V, eta_a, rho, throttle*P_sh, Ad, disk_area_ratio, delta_F, eta_F);

    CL_u = .1856 + .0334*delta_F+ .0667.*alpha;
    
    A0 = .1856 + .0334*delta_F + .0667.*alpha;
    A1 = .0121*delta_j - .0085.*alpha + .0426;
    A2 = .0140*delta_j + .0226.*alpha + .1407;
    
    F_Cj = A0 + A1*sqrt(delta_C_j) + A2*delta_C_j;
    
    F_0 = CL_u;

    CL_land = CL_u + F_Cj - F_0;


    
    %% Set the angle-of-attack limit (instead of a fixed CL_max)

    alpha_stall = min(16 + 1.5*T_c_prime, 22);
    
    delta_alpha = 10; % 10 degree stall marign from Courtin
    
    alpha_max = alpha_stall - delta_alpha;
    alpha_min = -8; %from Courtin, ref 73 NASA wind tunnel test

    CL_max_takeoff = CL_takeoff(find(alpha <= alpha_max, 1, "last"));
    CL_max_clean = CL_clean(find(alpha <= alpha_max, 1, "last"));
    CL_max_land = CL_land(find(alpha <= alpha_max, 1, "last"));

    CL_min_takeoff = CL_takeoff(find(alpha <= alpha_min, 1, "last"));
    CL_min_clean = CL_clean(find(alpha <= alpha_min, 1, "last"));
    CL_min_land = CL_land(find(alpha <= alpha_min, 1, "last"));

    figure()
    hold on
    plot(alpha, CL_takeoff, 'LineWidth', 1)
    plot(alpha, CL_clean, 'LineWidth', 1)
    plot(alpha, CL_land, 'LineWidth', 1)
    plot(alpha_max, CL_max_takeoff, '-o', 'LineWidth', 3)
    plot(alpha_max, CL_max_clean, '-o', 'LineWidth', 3)
    plot(alpha_max, CL_max_land, '-o', 'LineWidth', 3)
    plot(alpha_min, CL_min_takeoff, '-o', 'LineWidth', 3)
    plot(alpha_min, CL_min_clean, '-o', 'LineWidth', 3)
    plot(alpha_min, CL_min_land, '-o', 'LineWidth', 3)
    xlabel('\alpha (deg)')
    ylabel('C_L')
    legend('Lift Curve Slope Takeoff Configuration', 'Lift Curve Slope Clean Configuration', 'Lift Curve Slope Landing Configuration', 'Takeoff Max CL', 'Clean Max CL', 'Landing Max CL', 'Takeoff Min CL', 'Clean Min CL', 'Landing Min CL', 'Location', 'Best')
    title('Powered Lift Curve')

    %% Unblown CLmax from AVL (CLtot at alpha = 0 and 10 deg, body axis)
    i_w = 2;                          % deg, wing incidence in AVL model
    alpha_stall_u = 16 - i_w;         % deg (body); Courtin alpha_stall at T'c = 0
    CLavl = @(CL0, CL10) CL0 + (CL10 - CL0)/10*alpha_stall_u;
    CL_max_clean_unblown = CLavl(0.3772,  1.20569);   % 0 deg flap
    CL_max_TO_unblown    = CLavl(1.14806, 1.92767);   % 20 deg flap
    CL_max_land_unblown  = CLavl(2.71537, 3.36805);   % 60 deg flap

     %% Landing Configuration Max CL

    V_stall_flaps = 50; %ft/s, initial estimate

    tol = 0.01;
    diff = 10;

    landing_weight = aircraft.Wland_W0 * aircraft.W0;

    while diff > tol

        V_app = aircraft.k_app*V_stall_flaps;
        [delta_C_j, delta_j, T_c_prime, Vj] = calc_Tc(V_app, eta_a, rho, aircraft.approach_power_frac*P_sh, Ad, disk_area_ratio, delta_F, eta_F);
        CLf    = aircraft.CLmax_flap_LD;
        CL_loc = min(aircraft.CL_cap, CLf*(1 + aircraft.k_blow*((Vj/V_app)^2 - 1)));   % blown strip sees (Vj/V)^2
        CL_max = fB*CL_loc + (1 - fB)*CLf;                                             % stall reference, strip theory
        dCJe = aircraft.k_blow*delta_C_j;                                              % lift curve: team fit
        c0 = .1856 + .0334*delta_F + sqrt(dCJe)*(.0121*delta_j + .0426) + dCJe*(.0140*delta_j + .1407);
        c1 = .0667 - .0085*sqrt(dCJe) + .0226*dCJe;
        alpha_stall = min(16 + 1.5*T_c_prime, 22);
        CL_app = min(CL_max/aircraft.k_app^2, c0 + c1*(alpha_stall - aircraft.alpha_margin));  % usable approach C_L

        V_stall_calc = sqrt(2*landing_weight/(rho*S*CL_max));

        diff = abs(V_stall_flaps - V_stall_calc)/V_stall_flaps;

       V_stall_flaps = 0.5*(V_stall_flaps + V_stall_calc);   % relaxed update, converges to the true stall speed
    end
    alpha_app = (CL_app - c0)/c1;   % wing angle that gives the approach C_L [deg]
    aircraft.CL_app = CL_app;
    aircraft.CLmax_land = CL_max;
    V_d = aircraft.V_app_max*1.688;
    [dCj_d, dj_d, Tc_d, Vj_d] = calc_Tc(V_d, eta_a, rho, aircraft.approach_power_frac*P_sh, Ad, disk_area_ratio, delta_F, eta_F);
    CLloc_d = min(aircraft.CL_cap, CLf*(1 + aircraft.k_blow*((Vj_d/V_d)^2 - 1)));
    CLmax_d = fB*CLloc_d + (1 - fB)*CLf;
    dCJe_d  = aircraft.k_blow*dCj_d;
    c0_d = .1856 + .0334*delta_F + sqrt(dCJe_d)*(.0121*dj_d + .0426) + dCJe_d*(.0140*dj_d + .1407);
    c1_d = .0667 - .0085*sqrt(dCJe_d) + .0226*dCJe_d;
    aircraft.CL_app_size = min(CLmax_d/aircraft.k_app^2, c0_d + c1_d*(min(16 + 1.5*Tc_d, 22) - aircraft.alpha_margin));
    V_stall_land = V_stall_calc; %ft/s

    disp("Landing Configuration Blown Wing V_stall: " + V_stall_land/1.688 + " kts")
    disp("Landing Configuration Blown Wing CL_max: " + CL_max)

    CL_max_flap_unblown = 1.3226;
    V_stall_flap_unblown = sqrt(2*landing_weight/(rho*S*CL_max_flap_unblown));

    disp("Landing Configuration Unblown Wing V_stall: " + V_stall_flap_unblown/1.688 + " kts")
    disp("Landing Configuration Unblown Wing CL_max: " + CL_max_flap_unblown)

     %% Takeoff Configuration Max CL

    V_stall_flaps = 50; %ft/s, initial estimate

    tol = 0.01;
    diff = 10;

    takeoff_weight = aircraft.Wto_W0 * aircraft.W0;

    while diff > tol

        V_LO  = aircraft.k_TO*V_stall_flaps;                 % lift-off speed = 1.1 x current stall-speed guess
        dF_TO = aircraft.delta_F_to;                         % take-off flap (40 deg), not the landing flap

        % slipstream at lift-off, FULL power (take-off)
        [delta_C_j, delta_j, T_c_prime, Vj] = calc_Tc(V_LO, eta_a, rho, P_sh, Ad, disk_area_ratio, dF_TO, eta_F);

        % stall reference: blown strip sees (Vj/V)^2, capped; unblown strip keeps the flap value
        CLf    = aircraft.CLmax_flap_TO;                                                  % 2.28
        CL_loc = min(aircraft.CL_cap, CLf*(1 + aircraft.k_blow*((Vj/V_LO)^2 - 1)));
        CL_max = fB*CL_loc + (1 - fB)*CLf;

        % angle check with the team fit (calibrated blowing): wing at least alpha_margin below stall
        dCJe = aircraft.k_blow*delta_C_j;
        c0 = .1856 + .0334*dF_TO + sqrt(dCJe)*(.0121*delta_j + .0426) + dCJe*(.0140*delta_j + .1407);
        c1 = .0667 - .0085*sqrt(dCJe) + .0226*dCJe;
        alpha_stall = min(16 + 1.5*T_c_prime, 22);
        CL_LO = min(CL_max/aircraft.k_TO^2, c0 + c1*(alpha_stall - aircraft.alpha_margin));   % usable lift-off C_L

        V_stall_calc = sqrt(2*takeoff_weight/(rho*S*CL_max));
        diff = abs(V_stall_flaps - V_stall_calc)/V_stall_flaps;
        V_stall_flaps = 0.5*(V_stall_flaps + V_stall_calc);   % relaxed update
    end

    disp("Takeoff Configuration Blown Wing V_stall: " + V_stall_calc/1.688 + " kts")
    disp("Takeoff Configuration Blown Wing CL_max: " + CL_max)

    aircraft.CLmax_to = CL_max;
    aircraft.CL_LO = CL_LO;
    disp("Takeoff usable lift-off C_L: " + CL_LO)
    CL_max_flap_unblown = 1.3226;
    V_stall_flap_unblown = sqrt(2*takeoff_weight/(rho*S*CL_max_flap_unblown));

    disp("Takeoff Configuration Unblown Wing V_stall: " + V_stall_flap_unblown/1.688 + " kts")
    disp("Takeoff Configuration Unblown Wing CL_max: " + CL_max_flap_unblown)

    %% Clean Configuration Max CL

    V_stall_clean = 80; %ft/s, initial estimate

    tol = 0.01;
    diff = 10;

    delta_F_clean = 0;

    [~, ~, ~, rho_cr] = atmoscoesa((aircraft.alt_cr/3.281)); %kg/m^3
    rho_cr = rho_cr/515.4; %slug/ft^3

    cruise_weight = aircraft.Wcr_W0 * aircraft.W0;

    while diff > tol

        [delta_C_j, delta_j, T_c_prime] = calc_Tc(V_stall_clean, eta_a, rho_cr, aircraft.approach_power_frac*P_sh, Ad, disk_area_ratio, delta_F_clean, eta_F);
        alpha = linspace(-5, 20, 1000);
    
        CL_u = .1856 + .0334*delta_F_clean + .0667.*alpha;
        
        A0 = .1856 + .0334*delta_F_clean + .0667.*alpha;
        A1 = .0121*delta_j - .0085.*alpha + .0426;
        A2 = .0140*delta_j + .0226.*alpha + .1407;
        
        F_Cj = A0 + A1*sqrt(delta_C_j) + A2*delta_C_j;
        
        F_0 = CL_u;
        
        CL = min(CL_u + fB*(F_Cj - F_0), aircraft.CL_cap);   % only the blown span gets the jet lift; cap at the flight-test level

        alpha_stall = min(16 + 1.5*T_c_prime, 22);
    
        delta_alpha = 10; % 10 degree stall marign from Courtin
    
        alpha_max = alpha_stall - delta_alpha;
        CL_max_clean = CL(find(alpha <= alpha_max, 1, "last"));

        V_stall_calc = sqrt(2*cruise_weight/(rho_cr*S*CL_max_clean));

        diff = abs(V_stall_clean - V_stall_calc)/V_stall_clean;

               V_stall_clean = 0.5*(V_stall_clean + V_stall_calc);   % relaxed update: average of guess and result
    end

    disp("Clean Blown Wing V_stall: " + V_stall_calc/1.688 + " kts")
    disp("Clean Blown Wing CL_max: " + CL_max_clean)
    
    CL_max_clean_unblown = 1.3226;
    V_stall_clean_unblown = sqrt(2*cruise_weight/(rho_cr*S*CL_max_clean_unblown));

    disp("Clean Unblown Wing V_stall: " + V_stall_clean_unblown/1.688 + " kts")
    disp("Clean Unblown Wing CL_max: " + CL_max_clean_unblown)

    
    %% Landing Approach and Distance (OLD VERSION)
    %{
    CD0 = .015 + .065 + .02;
    
    gamma = deg2rad(linspace(-40, 10, 100)); %rad, sweep of flight path angles
    V_A = linspace(25, 65, 100); %kts, sweep of approach speeds
    
    CL_g = 1; %Courtin's EL-2 ground value
    CD0_g = aircraft.CD0_g; %Courtin's EL-2 ground value
    G = aircraft.G; %Courtin's EL-2, calculated based on height of the wing, don't know what this is
    e_g = aircraft.e_g; %Courtin's EL-2, oswald efficiency
    mu_b = aircraft.mu_b; %Courtin's EL-2, breaking coefficient
    W_S = aircraft.W_S; %preliminary wing loading estimate
    k1 = 0; %don't actually know what this is but Cinar used this
    
    V_TD = V_A.*1.688; %touchdown speed in ft/s = approach speed with no flare
    h_obs = 50; %50 foot obstacle
    g = 32.1; %ft/s^2
    t_d = 1; %sec, time before brakes applied in landing roll
    
    V_TD_vec = linspace(20, 60, 100).*1.688; %ft/s sweep over landing speeds from 20-60 kts
    P_sh_vec = linspace(0, 1, 100).*P_sh; %sweep over power settings from 0-100%
    
    e = aircraft.e_land; %estimated oswald efficiency factor
    
    alpha = zeros([100, 100]);
    alpha_stall = zeros([100, 100]);
    landingDistance = zeros([100, 100]);
    gamma_vec = zeros([100, 100]);
    
    for i = 1:100
        for j = 1:100
            [delta_C_j, delta_j, T_c_prime] = calc_Tc(V_TD_vec(i), eta_a, rho, P_sh_vec(j), Ad, disk_area_ratio, delta_F, eta_F);
            q_inf = .5*rho*V_TD_vec(i)^2;
    
            %iterate flight path angle
            gamma = deg2rad(0); %0 radian initial flight path angle
            for n = 1:8
                CL_k = (W_S*cos(gamma))/q_inf;
                Cx = CD0 + (CL_k^2)/(pi*e*AR + 2*delta_C_j) - T_c_prime;
                gamma = asin(-1*(q_inf*Cx)/W_S);
            end
    
            gamma_vec(i, j) = gamma;
    
            c0 = .1856 + .0334*delta_F + sqrt(delta_C_j)*(.0121*delta_j + .0426) + delta_C_j*(.014*delta_j + .1407);
            c1 = .0667 - .0085*sqrt(delta_C_j) + .0226*delta_C_j;
            alpha(i, j) = (CL_k - c0)/c1;
    
            alpha_stall(i, j) = min(16 + 1.5*T_c_prime, 22);
    
            J_A = (rho/(2*W_S))*(CD0_g + (k1 + (G/(pi*e_g*AR))*CL_k^2) - mu_b*CL_k);
            landingDistance(i, j) = h_obs/tan(abs(gamma)) + t_d*V_TD_vec(i) + 1/(2*g*J_A)*log(1 + ((J_A*V_TD_vec(i)^2)/mu_b));
        end
    end
    
    %shade region where alpha < alpha_stall - delta_alpha
    is_possible_alpha = alpha <= (alpha_stall - delta_alpha);
    
    figure()
    hold on
    contourf(V_TD_vec./1.688, (P_sh_vec./P_sh).*100, landingDistance, [100, 200, 300, 400, 500, 600, 700])
    contourf(V_TD_vec./1.688, (P_sh_vec./P_sh).*100, is_possible_alpha, [1, 1], 'g-', 'LineWidth', 2, 'FaceAlpha', .2)
    contour(V_TD_vec./1.688, (P_sh_vec./P_sh).*100, landingDistance, [300, 300], 'r-', 'LineWidth', 2)
    title('Steady approach and Landing Search')
    xlabel('Touchdown Speed (kts)')
    ylabel('Power Setting %')
    legend('Landing Distance', 'Allowed Angle of Attack', '300 ft landing')
    cb = colorbar;
    cb.Label.String = 'Landing Distance (ft)';
    hold off
    %}

    %% Integrate Landing

    W_land = aircraft.W0*aircraft.Wland_W0; %lbs, conservative estimate from preliminary sizing code
    m_land = W_land/32.1; %slugs
    dt = .01; %s
    V0 = 1.3*V_stall_land; %ft/s
    g = 32.1; %ft/s^2
    init_glide_path = deg2rad(-12); %initial estimate
    
    %initialize arrays for storage
    i = 1;
    s = 0;
    h = 50;
    t = 0;
    V = V0;
    CL_vec = 0;
    alpha = deg2rad(alpha_app);   % fly the approach at the angle that gives CL_app
    gamma = init_glide_path;
    throttle = aircraft.approach_power_frac; % same power as in the C_L,max loop
    q_pitch = 0;   % pitch rate [rad/s]

    %logic for controlling phase of landing
    approach = 1; %1 = true, 0 = false
    flare = 0;
    brake = 0;

    %Required Parameters
    CD0_land = aircraft.CD0_land;
    CD0_land_brake = aircraft.CD0_land_brake;
    e_land = aircraft.e_land;
    mu_brake = aircraft.mu_b + .1;

    %rotation quantity estimates
    CL_tail = aircraft.CL_tail; %initial CL_tail
    CL_tail_dot = aircraft.CL_tail_dot; %random estimate
    c_bar = aircraft.c_bar; %mean chord
    Iyy = aircraft.Iyy; %slug*ft^2, estimate from light twin engine aircraft ~ 12500 lbs
    Cm_wb_0 = aircraft.Cm_wb_0; %estimate from google
    x_mlg = aircraft.x_mlg; %estimate from Cinar
    x_cg = aircraft.x_cg; %estimate from Cinar
    x_acw = aircraft.x_acw; %assuming ac is at quarter chord
    Sh = aircraft.Sh; 
    l_tail = aircraft.l_tail; %ft, estimated from beechcraft baron
    z_cg = aircraft.z_cg; %ft, estimated from beechcraft baron
    z_mlg = aircraft.z_mlg; %ft, main landing gear on the ground

    K_f = .38;
    Cm_alpha_fus = K_f*(aircraft.fuselage_width^2*aircraft.fuselage_length)/(S*c_bar);

    dF  = delta_F;                    % landing flap (64 deg)
    CLf = aircraft.CLmax_flap_LD;     % 2.60
    % start on the steady glide path for the approach power (no phugoid)
    [dCj0, dj0, Tc0, Vj0] = calc_Tc(V0, eta_a, rho, throttle*P_sh, Ad, disk_area_ratio, delta_F, eta_F);
    CL0 = W_land/(.5*rho*V0^2*S);
    CX0 = CD0_land + CL0^2/(pi*e_land*AR + 2*dCj0) - Tc0*(Vj0*cosd(dj0) - V0)/(Vj0 - V0);
    gamma = -atan(CX0/CL0);
    aircraft.gamma_app = rad2deg(gamma);
    disp(['Approach path angle: ' num2str(rad2deg(gamma)) ' deg at ' num2str(V0/1.688) ' kt'])
    while V > 0
  
        [delta_C_j, delta_j, T_c_prime, Vj] = calc_Tc(V(i), eta_a, rho, throttle*P_sh, Ad, disk_area_ratio, delta_F, eta_F);
        if (approach == 1)
            dCJe   = aircraft.k_blow*delta_C_j;
            c0     = .1856 + .0334*dF + sqrt(dCJe)*(.0121*delta_j + .0426) + dCJe*(.0140*delta_j + .1407);
            c1     = .0667 - .0085*sqrt(dCJe) + .0226*dCJe;
            CL_loc = min(aircraft.CL_cap, CLf*(1 + aircraft.k_blow*((Vj/V(i))^2 - 1)));
            CL     = min(c0 + c1*rad2deg(alpha(i)), fB*CL_loc + (1 - fB)*CLf);
            CX = CD0_land + CL^2/(pi*e_land*AR + 2*delta_C_j)  - T_c_prime*(Vj*cosd(delta_j) - V(i))/(Vj - V(i));   % turned jet: only Vj*cos(dj) - V of its momentum pushes forward
    
            L = .5*rho*V(i)^2*S*CL; %lbs
            X = .5*rho*V(i)^2*S*CX; %lbs
    
            % stabilized approach: speed held at V0 = 1.3 V_S (never below it before the flare), steady glide path
            V(i+1) = V(i);
            CL = min(W_land*cos(gamma(i))/(.5*rho*V(i)^2*S), fB*CL_loc + (1 - fB)*CLf);   % lift = weight component
            CX = CD0_land + CL^2/(pi*e_land*AR + 2*delta_C_j) - T_c_prime*(Vj*cosd(delta_j) - V(i))/(Vj - V(i));
            gamma(i+1) = -atan(CX/CL);                    % path angle where drag and weight component balance: no deceleration
            s(i+1) = s(i) + V(i+1)*dt*cos(gamma(i+1));
            h(i+1) = h(i) + V(i+1)*dt*sin(gamma(i+1));
            alpha(i+1) = deg2rad(max((CL - c0)/c1, 0));   % wing angle for that C_L
            CL_vec(i+1) = CL;


            if(h(i+1) < 8)          % flare height [ft]
                sink_fl = -V(i+1)*sin(gamma(i+1));   % sink rate entering the flare [ft/s]
                approach = 0;       % keep approach power: no throttle step (the step made it climb away)
                flare = 1;
            end
        end

        if(flare == 1)
            dCJe   = aircraft.k_blow*delta_C_j;
            c0     = .1856 + .0334*dF + sqrt(dCJe)*(.0121*delta_j + .0426) + dCJe*(.0140*delta_j + .1407);
            c1     = .0667 - .0085*sqrt(dCJe) + .0226*dCJe;
            CL_loc = min(aircraft.CL_cap, CLf*(1 + aircraft.k_blow*((Vj/V(i))^2 - 1)));
            CL     = min(c0 + c1*rad2deg(alpha(i)), fB*CL_loc + (1 - fB)*CLf);
            CL = min(1.3*W_land*cos(gamma(i))/(.5*rho*V(i)^2*S), 0.95*(fB*CL_loc + (1 - fB)*CLf));   % n = 1.3 flare, 5 % below C_Lmax
            CX = CD0_land + CL^2/(pi*e_land*AR + 2*delta_C_j)  - T_c_prime*(Vj*cosd(delta_j) - V(i))/(Vj - V(i));   % turned jet: only Vj*cos(dj) - V of its momentum pushes forward

            alpha_stall = min(16 + 1.5*T_c_prime, 22); %deg
            alpha_target = deg2rad(alpha_stall - aircraft.alpha_margin);
    
            L = .5*rho*V(i)^2*S*CL; %lbs
            X = .5*rho*V(i)^2*S*CX; %lbs
    
            V_dot = (-X - W_land*sin(gamma(i)))/m_land;
            
            if(alpha(i) < alpha_target)
                Cm_wb = Cm_wb_0 + Cm_alpha_fus*alpha(i); % alpha in rad, fuselage destabilizing
                
                if(CL_tail > -2)
                    CL_tail = CL_tail - CL_tail_dot*dt;
                end
               
                Cm_mlg = Cm_wb + CL*((x_mlg - x_acw)/c_bar) - CL_tail*(Sh/S)*((l_tail - x_mlg + x_cg)/c_bar) - (W_land/(.5*rho*V(i)^2*S))*((x_mlg - x_cg)/c_bar) - CX*((z_cg - z_mlg)/c_bar) + ((m_land*V_dot)/(.5*rho*V(i)^2*S))*((z_cg - z_mlg)/c_bar);
                M_mlg = Cm_mlg*.5*rho*V(i)^2*S*c_bar;
                Iyy_mlg = Iyy + m_land*((z_cg - z_mlg) + (x_mlg - x_cg))^2;
    
                q_dot = M_mlg/Iyy_mlg;
                q_pitch = q_pitch + q_dot*dt;          % integrate acceleration to rate
                alpha(i+1) = alpha(i) + q_pitch*dt;    % integrate rate to angle

            else
                q_pitch = 0;
                alpha(i+1) = alpha(i); %keep alpha constant once it reaches target
            end
   
            V(i+1) = V(i) + V_dot*dt;
    
            gamma_dot = (L - W_land*cos(gamma(i)))/(m_land*V(i+1));
    
            gamma(i+1) = gamma(i) + gamma_dot*dt;
            gamma(i+1) = -asin(min(max(aircraft.sink_TD, sink_fl*h(i)/8)/V(i+1), 1));   % sink rate falls to 6 ft/s at touchdown
            s(i+1) = s(i) + V(i+1)*dt*cos(gamma(i+1));
            h(i+1) = h(i) + V(i+1)*dt*sin(gamma(i+1));
            CL_vec(i+1) = CL;

            if(h(i+1) < 0)
                alpha(i) = max(alpha(i) + gamma(i), deg2rad(aircraft.wing_incidence));   % on the ground the wing angle is the body pitch at touchdown
                gamma(i) = 0;
                throttle = 0; %used for CL calculation
                revThrottle = .5; %reverse thrust
                flare = 0;
                brake = 1;
    
                t_TD = t(i) + dt;   % touchdown time
                alpha(i) = 0;
            end
        end

        if(brake == 1)
            CL_u = .1856 + .0334*delta_F + .0667*rad2deg(alpha(i));
            A0 = .1856 + .0334*delta_F + .0667*rad2deg(alpha(i));
            A1 = .0121*delta_j - .0085*rad2deg(alpha(i)) + .0426;
            A2 = .0140*delta_j + .0226*rad2deg(alpha(i)) + .1407;
            F_Cj = A0 + A1*sqrt(delta_C_j) + A2*delta_C_j;
            F_0 = CL_u;
            
            %CL = min(CL_u + fB*(F_Cj - F_0), aircraft.CL_cap);   % only the blown span gets the jet lift; cap at the flight-test level
            CL = 0;

            L = .5*rho*V(i)^2*S*CL; %lbs

            [~, ~, T_c_prime_rev] = calc_Tc(V(i), eta_a, rho, revThrottle*P_sh, Ad, disk_area_ratio, delta_F, eta_F);

    
            %estimate CX
            CX = CD0_land_brake + CL^2/(pi*e_land*AR + 2*delta_C_j) + T_c_prime_rev;
            if t(i) < t_TD + aircraft.t_free_roll, CX = CD0_land + CL^2/(pi*e_land*AR + 2*delta_C_j); end   % free roll: no reverse thrust, no brake drag
            X = .5*rho*V(i)^2*S*CX; %lbs
        
            if t(i) < t_TD + aircraft.t_free_roll
                V_dot = (-X - aircraft.mu*(W_land-L))/m_land;     % free roll: rolling resistance only
            else
                V_dot = (-X - mu_brake*(W_land-L))/m_land;        % brakes + reverse thrust
                V_dot = max(V_dot, -aircraft.a_brake_max*g);      % at most 1 g
            end
        
            %no change in height during roll
            V(i+1) = V(i) + V_dot*dt;
            s(i+1) = s(i) + V(i+1)*dt;
            alpha(i+1) = max(alpha(i) - deg2rad(aircraft.q_derot)*dt, deg2rad(aircraft.wing_incidence));   % nose down at q_derot until the nose gear touches
            gamma(i+1) = gamma(i);
            h(i+1) = h(i);
            CL_vec(i+1) = CL;

        end
        if i > 20000, warning('Landing simulation stopped after 200 s'); break; end
        t(i+1) = t(i) + dt;
        i = i+1;
    end

    if converged == true
        figure()
    plot(s, h, 'LineWidth', 1, 'Color', 'Blue')
    title('Landing Roll Height vs. Distance')
    ylabel('Height (ft)')
    xlabel('Distance (ft)')
    
    figure()
    plot(t, h, 'LineWidth', 1, 'Color', 'Blue')
    title('Landing Roll Height vs. Time')
    ylabel('Height (ft)')
    xlabel('Time (s)')
    
    figure()
    plot(t, s, 'LineWidth', 1, 'Color', 'Blue')
    title('Landing Roll Distance vs. Time')
    xlabel('Time (s)')
    ylabel('Distance (ft)')
    
    figure()
    plot(t, V, 'LineWidth', 1, 'Color', 'Blue')
    title('Landing Roll Speed vs. Time')
    ylabel('Speed (ft/s)')
    xlabel('Time (s)')

    figure()
    plot(t, rad2deg(gamma), 'LineWidth', 1, 'Color', 'Blue')
    title('Landing Roll Flight Path Angle vs. Time')
    ylabel('Flight Path Angle (deg)')
    xlabel('Time (s)')
    
    figure()
    plot(t, rad2deg(alpha), 'LineWidth', 1, 'Color', 'Blue')
    title('Landing Roll Angle of Attack vs. Time')
    ylabel('Angle of Attack (deg)')
    xlabel('Time (s)')

    figure()
    plot(t, CL_vec, 'LineWidth', 1', 'Color', 'Blue')
    title('Landing Roll CL vs. Time')
    ylabel('CL')
    xlabel('Time (s)')

    figure()
    plot(V, CL_vec, 'LineWidth', 1, 'Color', 'Blue')
    title('Landing Roll CL vs. Speed')
    ylabel('CL')
    xlabel('Speed (ft/s)')

    end

    landing_distance = s(end);

    disp("Blown Wing Landing Distance: " + landing_distance + " ft")

    

    %% Integrate Takeoff 
    T0 = (2*rho*Ad)^(1/3)*(eta_a*P_sh)^(2/3); %Zero-velocity thrust
    
    W = aircraft.W0; %lbs, conservative estimate from preliminary sizing code
    m = W/32.1; %slugs
    dt = .01; %s
    V0 = 5*3.281; %ft/s, from 5m/s brake release speed from Cinar
    mu = aircraft.mu; %rolling resistance, common value used for transport aircraft
    g = 32.1; %ft/s^2
    
    a0 = g*(T0/W - mu);
    s0 = V0^2/(2*a0);
    
    %logic for controlling phase of takeoff
    roll = 1; %1 = true, 0 = false
    rotate = 0;
    climb = 0;
    
    %rotation quantity estimates
    CL_tail = aircraft.CL_tail; %initial CL_tail
    CL_tail_dot = aircraft.CL_tail_dot; %random estimate
    c_bar = aircraft.c_bar; %mean chord
    Iyy = aircraft.Iyy; %slug*ft^2, estimate from light twin engine aircraft ~ 12500 lbs
    Cm_wb_0 = aircraft.Cm_wb_0; %estimate from google
    x_mlg = aircraft.x_mlg; %estimate from Cinar
    x_cg = aircraft.x_cg; %estimate from Cinar
    x_acw = aircraft.x_acw; %assuming ac is at quarter chord
    Sh = aircraft.Sh; %estimated 40% sizing of tail
    l_tail = aircraft.l_tail; %ft, estimated from beechcraft baron
    z_cg = aircraft.z_cg; %ft, estimated from beechcraft baron
    z_mlg = aircraft.z_mlg; %ft, main landing gear on the ground
    CD0_takeoff = aircraft.CD0_takeoff;
    e_takeoff = aircraft.e_takeoff;

    K_f = .38;
    Cm_alpha_fus = K_f*(aircraft.fuselage_width^2*aircraft.fuselage_length)/(S*c_bar);
    
    %initialize arrays for storage
    i = 1;
    s = s0;
    h = 0;
    t = 0;
    V = V0;
    CL_vec = 0;
    alpha = deg2rad(aircraft.wing_incidence); %deg
    gamma = deg2rad(0);
    q_pitch = 0;

    V_stall = sqrt(2*W/(rho*S*aircraft.CLmax_to));
    
    %explicit euler method to time march
    %assuming no mass loss during takeoff, fuel loss is pretty negligible
    %anyway
    dF  = aircraft.delta_F_to;        % take-off flap (40 deg)
    CLf = aircraft.CLmax_flap_TO;     % 2.28
        % tail-strike attitude: start of the upsweep and tail end (fuselage underside), both seen from the main gear
    x_end = aircraft.fuselage_length;
    h_end = aircraft.h_ups + (x_end - aircraft.x_ups)*tand(aircraft.u_upsweep);
    th_ts = min(atand(aircraft.h_ups/(aircraft.x_ups - x_mlg)), atand(h_end/(x_end - x_mlg)));   % deg
    theta_max = th_ts - 2;                                                 % 2 deg clearance
    th_5ft = 14;  gam_max = 22;  qmax = 8;  n_max = 1.3;                   % deg, deg, deg/s, -: pitch below 5 ft, path angle, pitch rate, load factor
    aircraft.th_tailstrike = th_ts;
    aircraft.tipback = atand((x_mlg - aircraft.x_cg)/aircraft.z_cg);       % deg, must exceed the tail-strike angle (Raymer ch. 11)
    disp(['Tail-strike attitude: ' num2str(th_ts) ' deg, pitch limit ' num2str(theta_max) ' deg, tip-back ' num2str(aircraft.tipback) ' deg'])   
        thr_vec = 1;   % throttle history (climb power reduction)
    while h < 50
        %assuming full throttle constantly, assuming constant rho, changes in
        %density are negligble from 0 - 50 ft
       [delta_C_j, delta_j, T_c_prime, Vj] = calc_Tc(V(i), eta_a, rho, P_sh, Ad, disk_area_ratio, dF, eta_F);
    
        if(climb == 1)
            %estimate CL
            dCJe   = aircraft.k_blow*delta_C_j;
            c0     = .1856 + .0334*dF + sqrt(dCJe)*(.0121*delta_j + .0426) + dCJe*(.0140*delta_j + .1407);
            c1     = .0667 - .0085*sqrt(dCJe) + .0226*dCJe;
            CL_loc = min(aircraft.CL_cap, CLf*(1 + aircraft.k_blow*((Vj/V(i))^2 - 1)));
            CL     = min(c0 + c1*rad2deg(alpha(i)), fB*CL_loc + (1 - fB)*CLf);
          
            CX = CD0_takeoff + CL^2/(pi*e_takeoff*AR + 2*delta_C_j)  - T_c_prime*(Vj*cosd(delta_j) - V(i))/(Vj - V(i));   % turned jet: only Vj*cos(dj) - V of its momentum pushes forward
    
            L = .5*rho*V(i)^2*S*CL; %lbs
            X = .5*rho*V(i)^2*S*CX; %lbs
    
            V_dot = (-X - W*sin(gamma(i)))/m;

            V(i+1) = V(i) + V_dot*dt;
    
            gamma_dot = (L - W*cos(gamma(i)))/(m*V(i+1));
            % limits: load factor n <= 1.3, path angle <= 22 deg, pitch rate <= 8 deg/s (wing angle held)
            gd_max = min([32.174*(n_max - cos(gamma(i)))/V(i), (deg2rad(gam_max) - gamma(i))/dt, deg2rad(qmax)]);
            throttle_to = 1;
            if gamma_dot > gd_max          % too much lift: hold the attitude and reduce power (as C17), alpha stays >= 0
                CL_req = (m*V(i)*gd_max + W*cos(gamma(i)))/(.5*rho*V(i)^2*S);
                lo = 0.05;  hi = 1;
                for kk = 1:14              % bisection on the throttle
                    throttle_to = 0.5*(lo + hi);
                    [dCj_t, dj_t, Tc_t, Vj_t] = calc_Tc(V(i), eta_a, rho, throttle_to*P_sh, Ad, disk_area_ratio, dF, eta_F);
                    dCJe_t = aircraft.k_blow*dCj_t;
                    c0_t = .1856 + .0334*dF + sqrt(dCJe_t)*(.0121*dj_t + .0426) + dCJe_t*(.0140*dj_t + .1407);
                    c1_t = .0667 - .0085*sqrt(dCJe_t) + .0226*dCJe_t;
                    CLl_t = min(aircraft.CL_cap, CLf*(1 + aircraft.k_blow*((Vj_t/V(i))^2 - 1)));
                    CL_t  = min(c0_t + c1_t*rad2deg(alpha(i)), fB*CLl_t + (1 - fB)*CLf);
                    if CL_t > CL_req, hi = throttle_to; else, lo = throttle_to; end
                end
                CL = CL_t;  delta_C_j = dCj_t;  delta_j = dj_t;  T_c_prime = Tc_t;  Vj = Vj_t;
                CX = CD0_takeoff + CL^2/(pi*e_takeoff*AR + 2*delta_C_j) - T_c_prime*(Vj*cosd(delta_j) - V(i))/(Vj - V(i));
                L = .5*rho*V(i)^2*S*CL;  X = .5*rho*V(i)^2*S*CX;
                V(i+1) = V(i) + (-X - W*sin(gamma(i)))/m*dt;
                gamma_dot = min((L - W*cos(gamma(i)))/(m*V(i+1)), gd_max);
            end
            thr_vec(i+1) = throttle_to;
            gamma(i+1) = gamma(i) + gamma_dot*dt;
            s(i+1) = s(i) + V(i+1)*dt*cos(gamma(i+1));
            h(i+1) = h(i) + V(i+1)*dt*sin(gamma(i+1));
            % wing angle: held; pitch limits near the ground (14 deg below 5 ft, tail strike below 10 ft); pitch rate +-8 deg/s; alpha >= 0
            th_lim = 90;  if h(i+1) < 10, th_lim = theta_max; end;  if h(i+1) < 5, th_lim = min(th_lim, th_5ft); end
            th_old = rad2deg(alpha(i) + gamma(i)) - aircraft.wing_incidence;
            th_new = min([th_old + qmax*dt, th_lim, rad2deg(alpha(i) + gamma(i+1)) - aircraft.wing_incidence]);
            th_new = max(th_new, th_old - qmax*dt);
            alpha(i+1) = max(deg2rad(th_new + aircraft.wing_incidence) - gamma(i+1), 0);
           
            CL_vec(i+1) = CL;
        end
    
        if(rotate == 1)
            %estimate CL
            dCJe   = aircraft.k_blow*delta_C_j;
            c0     = .1856 + .0334*dF + sqrt(dCJe)*(.0121*delta_j + .0426) + dCJe*(.0140*delta_j + .1407);
            c1     = .0667 - .0085*sqrt(dCJe) + .0226*dCJe;
            CL_loc = min(aircraft.CL_cap, CLf*(1 + aircraft.k_blow*((Vj/V(i))^2 - 1)));
            CL     = min(c0 + c1*rad2deg(alpha(i)), fB*CL_loc + (1 - fB)*CLf);
            CX = CD0_takeoff + CL^2/(pi*e_takeoff*AR + 2*delta_C_j)  - T_c_prime*(Vj*cosd(delta_j) - V(i))/(Vj - V(i));   % turned jet: only Vj*cos(dj) - V of its momentum pushes forward

            L = .5*rho*V(i)^2*S*CL; %lbs
            X = .5*rho*V(i)^2*S*CX; %lbs
    
            V_dot = (-X - mu*(W - L))/m;
    
            if (rad2deg(alpha(i)) < alpha_target)
                Cm_wb = Cm_wb_0 + Cm_alpha_fus*alpha(i); % alpha in rad, fuselage destabilizing
    
                if(CL_tail > -2)
                    CL_tail = CL_tail - CL_tail_dot*dt;
                end
               
                Cm_mlg = Cm_wb + CL*((x_mlg - x_acw)/c_bar) - CL_tail*(Sh/S)*((l_tail - x_mlg + x_cg)/c_bar) - (W/(.5*rho*V(i)^2*S))*((x_mlg - x_cg)/c_bar) - CX*((z_cg - z_mlg)/c_bar) + ((m*V_dot)/(.5*rho*V(i)^2*S))*((z_cg - z_mlg)/c_bar);
                M_mlg = Cm_mlg*.5*rho*V(i)^2*S*c_bar;
                Iyy_mlg = Iyy + m*((z_cg - z_mlg) + (x_mlg - x_cg))^2;
    
                q_dot = M_mlg/Iyy_mlg;
                q_pitch = min(q_pitch + q_dot*dt, deg2rad(qmax));   % integrate acceleration to rate, at most 8 deg/s
                alpha(i+1) = alpha(i) + q_pitch*dt;    % integrate rate to angle
                if alpha(i+1) > deg2rad(min(theta_max, th_5ft) + aircraft.wing_incidence)   % on the ground: body pitch = alpha - incidence <= 14 deg
                    alpha(i+1) = deg2rad(min(theta_max, th_5ft) + aircraft.wing_incidence);  q_pitch = 0;
                    alpha_target = rad2deg(alpha(i+1));                         % rotation ends at the pitch limit
                end
    
            else
                q_pitch = 0;
                alpha(i+1) = alpha(i); %keep alpha constant once it reaches target
            end
    
                V(i+1) = V(i) + V_dot*dt;
               
                s(i+1) = s(i) + V(i+1)*dt;

                %no change in height during rotation
                h(i+1) = h(i);
                CL_vec(i+1) = CL;
                gamma(i+1) = gamma(i);
    
                                if (rad2deg(alpha(i+1)) >= alpha_target) || (L >= W)   % lift-off as soon as the lift carries the weight
                    rotate = 0;
                    climb = 1;
                end
        end
    
        if (roll == 1)
            %estimate CL
            dCJe   = aircraft.k_blow*delta_C_j;
            c0     = .1856 + .0334*dF + sqrt(dCJe)*(.0121*delta_j + .0426) + dCJe*(.0140*delta_j + .1407);
            c1     = .0667 - .0085*sqrt(dCJe) + .0226*dCJe;
            CL_loc = min(aircraft.CL_cap, CLf*(1 + aircraft.k_blow*((Vj/V(i))^2 - 1)));
            CL     = min(c0 + c1*rad2deg(alpha(i)), fB*CL_loc + (1 - fB)*CLf);
            L = .5*rho*V(i)^2*S*CL; %lbs
    
            %estimate CX
            CX = CD0_takeoff + CL^2/(pi*e_takeoff*AR + 2*delta_C_j)  - T_c_prime*(Vj*cosd(delta_j) - V(i))/(Vj - V(i));   % turned jet: only Vj*cos(dj) - V of its momentum pushes forward
        
            X = .5*rho*V(i)^2*S*CX; %lbs
        
            V_dot = (-X - mu*(W-L))/m;
        
            %no change in height during roll
            V(i+1) = V(i) + V_dot*dt;
            s(i+1) = s(i) + V(i+1)*dt;
            alpha(i+1) = alpha(i);
            gamma(i+1) = gamma(i);
            h(i+1) = h(i);
            CL_vec(i+1) = CL;
    
            alpha_stall = min(16 + 1.5*T_c_prime, 22); %deg
            alpha_allowed = alpha_stall - aircraft.alpha_margin; %deg
    
            CL_u = .1856 + .0334*delta_F + .0667*alpha_allowed;
            A0 = .1856 + .0334*delta_F + .0667*alpha_allowed;
            A1 = .0121*delta_j - .0085*alpha_allowed + .0426;
            A2 = .0140*delta_j + .0226*alpha_allowed + .1407;
            F_Cj = A0 + A1*sqrt(delta_C_j) + A2*delta_C_j;
            F_0 = CL_u;
            
            %CL_potential = CL_u + F_Cj - F_0;
    
            %L_potential = .5*rho*V(i+1)^2*S*CL_potential;

            %if (L_potential >= W)
               % roll = 0;
              %  rotate = 1;
             %   alpha_target = alpha_stall - 8 - 4; %deg
            %end

            if (V(i+1) >= V_stall*1.1)
                roll = 0;
                rotate = 1;
                alpha_target = alpha_stall - aircraft.alpha_margin; %deg
            end
            if (L >= W)                % blown lift carries the weight before rotation: lift off
                roll = 0;  rotate = 0;  climb = 1;
            end
        end
        if i > 20000, warning('Take-off simulation stopped after 200 s'); break; end
        t(i+1) = t(i) + dt;
        i = i+1;
    end
    if converged == true
    figure()
    plot(s, h, 'LineWidth', 1, 'Color', 'Blue')
    title('Takeoff Roll Height vs. Distance')
    ylabel('Height (ft)')
    xlabel('Distance (ft)')
    
    figure()
    plot(t, h, 'LineWidth', 1, 'Color', 'Blue')
    title('Takeoff Roll Height vs. Time')
    ylabel('Height (ft)')
    xlabel('Time (s)')
    
    figure()
    plot(t, s, 'LineWidth', 1, 'Color', 'Blue')
    title('Takeoff Roll Distance vs. Time')
    xlabel('Time (s)')
    ylabel('Distance (ft)')
    
    figure()
    plot(t, V, 'LineWidth', 1, 'Color', 'Blue')
    title('Takeoff Roll Speed vs. Time')
    ylabel('Speed (ft/s)')
    xlabel('Time (s)')

    figure()
    plot(t, rad2deg(gamma), 'LineWidth', 1, 'Color', 'Blue')
    title('Takeoff Roll Flight Path Angle vs. Time')
    ylabel('Flight Path Angle (deg)')
    xlabel('Time (s)')
    
    figure()
    plot(t, rad2deg(alpha), 'LineWidth', 1, 'Color', 'Blue')
    title('Takeoff Roll Angle of Attack vs. Time')
    ylabel('Angle of Attack (deg)')
    xlabel('Time (s)')

    figure()
    plot(t, CL_vec, 'LineWidth', 1', 'Color', 'Blue')
    title('Takeoff Roll CL vs. Time')
    ylabel('CL')
    xlabel('Time (s)')

    figure()
    plot(V, CL_vec, 'LineWidth', 1, 'Color', 'Blue')
    title('Takeoff Roll CL vs. Speed')
    ylabel('CL')
    xlabel('Speed (ft/s)')
    end

    takeoff_distance = s(end);

    disp("Blown Wing Takeoff Distance: " + takeoff_distance + " ft")


    %}
end
