function[P_point, S_point] = PS_constraintcurves(S_sweep, W0, W_S_point, P_S_point)


    % Variables
    alt_cr = 12500; %feet
    Cf_clean = .0045;
    AR = 11;
    % Densities
    rho  = 0.001640; %slug/ft^3, warm day in colorado (6800 ft, 90degF)
    rho_sl = 0.002377; %slug/ft^3
    [~, ~, ~, rho_cr] = atmoscoesa((alt_cr/3.281)); %kg/m^3
    rho_cr = rho_cr/515.4; %slug/ft^3
    rho_ce = .001545; %14,000 ft, FAA regulations state that unpressurized aircraft flying above 14,000 feet for more than 30 minutes will require supplemental oxygen for flight crew
    rho_400 = 0.0016196; %7200ft, 90degF (400 ft above colorado) 
    % CL values
    CLmax_clean = 1.5;
    CLmax_to = 5;
    CLmax_climb = 3.472;

    %Preliminary Sizing function to create T/W - W/S design space

    %drag polar estimation

    %using Roskam's estimation to calculate S_wet assuming twin turboprop
    %coefficients

    c = -.0866;
    d = .8099;

    W0_lbs = 2.2*W0; %lbs

    S_wet = 10^(c + d*log10(W0_lbs)); %ft^2

    f_clean = S_wet*Cf_clean;

    S = W_S_point * W0; 

    CD0_clean = f_clean/S;

    %Roskam's assumptions on effect of flaps/landing gear (took the average
    %of each range)
    CD0_climb = CD0_clean + .0325;
    CD0_climb_gear = CD0_clean + .0325 + .02;
    %note takeoff currently = landing, assuming same configuration
    CD0_takeoff = CD0_clean + .065;
    CD0_landing = CD0_clean + .065;
    CD0_takeoff_gear = CD0_clean + .065 + .02; %flaps and landing gear
    CD0_landing_gear = CD0_clean + .065 + .02; %landing flaps and gear

    %Roskam's assumptions, real value may end up being lower if we go with
    %a simple rectangular wing, is going to be difficult to introduce wing
    %twist if we do a blown wing effect, can get funky with taper and
    %airfoil design tho
    e_clean = 0.825;
    e_climb = 0.8;
    %e_takeoff = .775;
    e_landing = .725;

    k_clean = 1/(pi*e_clean*AR);
    k_takeoff = 1/(pi*e_landing*AR);
    k_landing = 1/(pi*e_landing*AR);
    k_climb = 1/(pi*e_climb*AR);

    CL = linspace(-.5, 5, 1000);

    CD_clean = CD0_clean + k_clean.*CL.^2;
    CD_climb = CD0_climb + k_climb.*CL.^2;
    CD_takeoff = CD0_takeoff + k_takeoff.*CL.^2;
    CD_takeoff_gear = CD0_takeoff_gear + k_takeoff.*CL.^2;
    CD_landing = CD0_landing + k_landing.*CL.^2;
    CD_landing_gear = CD0_landing_gear + k_landing.*CL.^2;
    CD_climb_gear = CD0_climb_gear + k_climb.*CL.^2;

    %CD values for different configurations
    CD_to_gear_val = CD0_takeoff_gear + k_takeoff*CLmax_to^2;
    CD_land_gear_val = CD0_landing_gear + k_landing*CLmax_to^2;
    CD_climb_val = CD0_climb + k_climb*CLmax_climb^2;
    %CD values for different configurations
    L_D_climb = CLmax_to/CD_climb_val;
    L_D_to_gear = CLmax_to/CD_to_gear_val;
    L_D_land_gear = CLmax_to/CD_land_gear_val;

  

    Wguess = W0;
    
   %% VSTALL CONDITION

    for i = 1:length(S_sweep)

        % parameters for sweep
        S0 = S_sweep(i);
        P_vstall(i) = 1500; % initial power guess in hp
        tol = 0.1;
        converged = false;

        while converged == false
            W0 = weightIterationEstimate(P_vstall(i), Wguess, S0, W_S_point);
            W_S = W0 / S0;
            P_S_vstall = sqrt((2.*W_S)./(rho*CLmax_clean)); 
            P_new = P_S_vstall * S0;
            if P_new - P_vstall(i) <= tol
                converged =  true;
            end
            P_vstall(i) = P_new;
        end
    end

    
    
    %% TAKEOFF CONDITION
    sigma = rho/rho_sl;
    sTO = 300; %length required to clear an obstacle
    sTOG = sTO/1.66; 
    % sTOG = 4.9*TOP_23 + 0.009*TOP_23^2  ->  0.009*TOP_23^2 + 4.9*TOP_23 - sTOG = 0
    a = 0.009; b = 4.9; c = -sTOG;
    TOP_23_sol = (-b + sqrt(b^2 - 4*a*c)) / (2*a);   % positive root
    P_W_to = zeros(size(W_S_sweep));

    for i = 1:length(S_sweep)

        % parameters for sweep
        S0 = S_sweep(i);
        P_takeoff(i) = 1500; % initial power guess in hp
        tol = 0.1;
        converged = false;

        while converged == false
            W0 = weightIterationEstimate(P_takeoff(i), Wguess, S0, W_S_point);
            W_S = W0 / S0;
            P_S_takeoff = W_S / (TOP_23_sol * sigma * CLmax_to); 
            P_new = P_S_takeoff * S0;
            if P_new - P_takeoff(i)<= tol
                converged =  true;
            end
            P_takeoff(i) = P_new;
        end
    end


    
    
   %% Landing Condition 

    SF_land = 0.75; %est
    sland = 300*SF_land;
    %assume sa term is zero for FAR 23 (land in 300ft)
    
    
    W_S_land = (sland/80)*((rho/rho_sl)*CLmax_to);
    W_S_land_cor = W_S_land/Wland_W0;
    
    %% Cruise Condition

    V_cr = 379.76; %ft/s
    q_cr = (rho_cr*V_cr^2)/2;

    for i = 1:length(S_sweep)

        % parameters for sweep
        S0 = S_sweep(i);
        P_cruise(i) = 1500; % initial power guess in hp
        tol = 0.1;
        converged = false;

        while converged == false
            W0 = weightIterationEstimate(P_cruise(i), Wguess, S0, W_S_point);
            W_S = W0 / S0;
            P_S_cruise = (V_cr/(550*prop_efficiency)).*((q_cr./W_S).*CD0_clean + (W_S./q_cr).*k_clean); 
            P_new = P_S_cruise * S0;
            if P_new - P_cruise(i)<= tol
                converged =  true;
            end
            P_cruise(i) = P_new;
        end
    end
%{
    W_S_cr = W_S_sweep.*Wcr_W0;
    P_W_cr = (V_cr/(550*prop_efficiency)).*((q_cr./W_S_cr).*CD0_clean + (W_S_cr./q_cr).*k_clean); 
    P_W_cr_cor = (P_W_cr).*(Wcr_W0/Pcr_P0); %hp/lb
%}  

    % includes correction value for power above, will consider later

    %% Ceiling Condition 

    G = 0.001;
    V_ce = 350;
    
    for i = 1:length(S_sweep)

        % parameters for sweep
        S0 = S_sweep(i);
        P_ceiling(i) = 1500; % initial power guess in hp
        tol = 0.1;
        converged = false;

        while converged == false
            W0 = weightIterationEstimate(P_ceiling(i), Wguess, S0, W_S_point);
            P_S_ceiling = V_ce/(550*prop_efficiency)*(G + 2*sqrt(CD0_clean*k_clean));
            P_new = P_S_ceiling * S0;
            if P_new - P_ceiling(i)<= tol
                converged =  true;
            end
            P_ceiling(i) = P_new;
        end
    end
    
    P_W_ce = (V_ce/(550*prop_efficiency))*(G + 2*sqrt(CD0_clean*k_clean));
    Pce_P0 = (rho_ce/rho_sl)^0.8;
    P_W_ce_cor = ones([1, 1000]).*(P_W_ce)*(Wce_W0/Pce_P0);
    
    %% Climb Function

    function [P_climb] = climb(G,CLmax,ks,prop_efficiency,Wclimb_W0, rho_clm,rho_sl, L_D_clm)
        CL = CLmax/ks^2;
        
        for i = 1:length(S_sweep)
    
            % parameters for sweep
            S0 = S_sweep(i);
            P_climb(i) = 1500; % initial power guess in hp
            tol = 0.1;
            converged = false;
    
            while converged == false
                W0 = weightIterationEstimate(P_climb(i), Wguess, S0, W_S_point);
                W_S = W0 / S0;
                P_S_climb = ((sqrt(W_S)*(G + (L_D_clm)^-1))/(18.97*prop_efficiency*(rho_clm/rho_sl)*(sqrt(CL))));
                P_new = P_S_climb * S0;
                if P_new - P_climb(i)<= tol
                    converged =  true;
                end
                P_climb(i) = P_new;
            end
        end
    end
    
    %% Takeoff Climb

    %takeoff climb (denver hot day)
    G_to_clm = .04;
    ks = 1.2;
    P_climb_to = climb(G_to_clm, CLmax_to,ks,prop_efficiency,Wclimb_W0,rho,rho_sl,L_D_to_gear);
    
    %% Critical Loss of Thrust

    %critical loss of thrust
    G_crit = 0.01;
    ks_crit = 1.2;
    P_climb_crit = climb(G_crit, CLmax_to, ks_crit, prop_efficiency, Wclimb_W0, rho_400, rho_sl,L_D_to_gear);
    P_W_crit_cor = (Neng/(Neng-3))*P_W_crit;
    

    %% Balked Landing
    %balked landing configuration

    CLmax_land = 5.0;
    %balked landing 
    G_land = 0.03;
    ks_land = 1.3;
    P_balked = climb(G_land, CLmax_land, ks_land, prop_efficiency, Wland_W0, rho, rho_sl,L_D_land_gear);
    
    %% Maneuver

    %maneuver
    phi = deg2rad(60);
    n = 1/cos(phi);
    
    for i = 1:length(S_sweep)

        % parameters for sweep
        S0 = S_sweep(i);
        P_maneuever(i) = 1500; % initial power guess in hp
        tol = 0.1;
        converged = false;

        while converged == false
            W0 = weightIterationEstimate(P_climb(i), Wguess, S0, W_S_point);
            W_S = W0 / S0;
            P_S_maneuever = (V_cr/(550*prop_efficiency)).*((q_cr*CD0_clean)./W_S)+(W_S).*(n^2/(q_cr*pi*AR*e_clean));
            P_new = P_S_maneuever * S0;
            if P_new - P_maneuever(i)<= tol
                converged =  true;
            end
            P_maneuever(i) = P_new;
        end
    end
    
    P_W_man_cor = P_W_man .* (Wcr_W0 / Pcr_P0);
    
    %plot
    figure();
    hold on;

    % plot each curve
    h(1) = plot(S_sweep, P_takeoff, 'LineWidth', 1.5, 'Color', 'blue', 'DisplayName', 'Takeoff');
    h(2) = xline(W_S_land_cor, 'LineWidth', 1.5, 'Color', 'black', 'DisplayName', 'Landing');
    h(3) = plot(S_sweep, P_cruise, 'LineWidth', 1.5, 'Color', 'red', 'DisplayName', 'Cruise');
    h(4) = plot(S_sweep, P_ceiling, 'LineWidth', 1.5, 'Color', 'magenta', 'DisplayName', 'Ceiling');
    h(5) = plot(S_sweep, P_climb_to, 'LineWidth', 1.5, 'Color', 'green', 'DisplayName', 'Takeoff Climb');
    h(6) = plot(S_sweep, P_climb_crit, 'LineWidth', 1.5, 'Color', [0.85 0.7 0], 'DisplayName', 'Critical Loss of Thrust'); % Darker yellow for visibility
    h(7) = plot(S_sweep, P_balked, 'LineWidth', 1.5, 'Color', 'cyan', 'DisplayName', 'Balked Landing Climb');
    h(8) = plot(S_sweep, P_maneuever, 'LineWidth', 1.5, 'Color', [0.7290, 0.1, 0.9250], 'DisplayName', 'Maneuver'); %orange

    hold on;
    legend(h, 'Location', 'Northeast');

    hold off;

    xlabel('Wing Area, S (ft^2)');
    ylabel('Power (hp)');
    title('P vs S');
    xlim([0, 20])
    ylim([0, 1.5])


end