function S_wet = preliminary_Sizing(W0, AR, W_S, Cf_clean, CLmax_clean, CLmax_to, prop_efficiency, Wcr_W0, Wclimb_W0, Wce_W0, Wland_W0, Pcr_P0, Neng, alt_cr)

    %Preliminary Sizing function to create T/W - W/S design space
    
    %drag polar estimation
    
    %using Roskam's estimation to calculate S_wet assuming twin turboprop
    %coefficients
    
    c = -.0866;
    d = .8099;
    
    W0_lbs = 2.2*W0; %lbs
    
    S_wet = 10^(c + d*log10(W0_lbs)); %ft^2

    f_clean = S_wet*Cf_clean;

    S = W0_lbs/W_S; %ft^2

    CD0_clean = f_clean/S;

    %Roskam's assumptions on effect of flaps/landing gear (took the average
    %of each range)
    CD0_takeoff = CD0_clean + .015; %only takeoff flaps
    CD0_takeoff_gear = CD0_clean + .015 + .02; %flaps and landing gear
    CD0_landing_gear = CD0_clean + .065 + .02; %landing flaps and gear
    CD0_landing = CD0_clean + .065; %landing flaps only

    %Roskam's assumptions, real value may end up being lower if we go with
    %a simple rectangular wing, is going to be difficult to introduce wing
    %twist if we do a blown wing effect, can get funky with taper and
    %airfoil design tho
    e_clean = 0.825;
    e_takeoff = .775;
    e_landing = .725;

    k_clean = 1/(pi*e_clean*AR);
    k_takeoff = 1/(pi*e_takeoff*AR);
    k_landing = 1/(pi*e_landing*AR);

    CL = linspace(-.5, 5, 1000);

    CD_clean = CD0_clean + k_clean.*CL.^2;
    CD_takeoff = CD0_takeoff + k_takeoff.*CL.^2;
    CD_takeoff_gear = CD0_takeoff_gear + k_takeoff.*CL.^2;
    CD_landing = CD0_landing + k_landing.*CL.^2;
    CD_landing_gear = CD0_landing_gear + k_landing.*CL.^2;

    figure()
    hold on
    plot(CD_clean, CL, 'LineWidth', 1)
    plot(CD_takeoff, CL, 'LineWidth', 1)
    plot(CD_takeoff_gear, CL, 'LineWidth', 1)
    plot(CD_landing, CL, 'LineWidth', 1)
    plot(CD_landing_gear, CL, 'LineWidth', 1)
    title('Estimate Drag Polars')
    xlabel('CD')
    ylabel('CL')
    legend('Clean', 'Takeoff no Gear', 'Takeoff with Gear', 'Landing no Gear', 'Landing with Gear')
    hold off

    %variables
    W_S_sweep = linspace(0, 100, 200); %create a wing loading var to sweep over
    rho  = 0.001640; %slug/ft^3, warm day in colorado (6800 ft, 90degF)
    rho_sl = 0.002377; %slug/ft^3
    [~, ~, ~, rho_cr] = atmoscoesa((alt_cr/3.281)); %kg/m^3
    rho_cr = rho_cr/515.4; %slug/ft^3
    rho_ce = .001267; %20,000 ft
    rho_400 = 0.0016196; %7200ft, 90degF (400 ft above colorado) 

    %CD values for different configurations
    CD_clean_val = CD0_clean + k_clean*CLmax_clean^2;
    CD_to_val = CD0_takeoff + k_takeoff*CLmax_to^2;
    CD_to_gear_val = CD0_takeoff_gear + k_takeoff*CLmax_to^2;
    CD_land_gear = CD0_landing_gear + k_landing*CLmax_to^2;
    %CD values for different configurations
    L_D_clean = CLmax_clean/CD_clean_val;
    L_D_to = CLmax_to/CD_to_val;
    L_D_to_gear = CLmax_to/CD_to_gear_val;
    L_D_land_gear = CLmax_to/CD_land_gear;

    %stall speeds
    Vstall = sqrt((2.*W_S_sweep)./(rho*CLmax_clean));

    %Takeoff 
    sigma = rho/rho_sl;
    sTO = 300; %length required to clear an obstacle
    sTOG = sTO/1.66; 
    % sTOG = 4.9*TOP_23 + 0.009*TOP_23^2  ->  0.009*TOP_23^2 + 4.9*TOP_23 - sTOG = 0
    a = 0.009; b = 4.9; c = -sTOG;
    TOP_23_sol = (-b + sqrt(b^2 - 4*a*c)) / (2*a);   % positive root
    P_W_to = zeros(size(W_S_sweep));
    for i=1:length(W_S_sweep)
        P_W_to(i) = (W_S_sweep(i))/(TOP_23_sol*sigma*CLmax_to);
    end
    
    %landing field length
    SF_land = 0.75; %est
    sland = 300*SF_land;
    %assume sa term is zero for FAR 23 (land in 300ft)
    W_S_land = (sland/80)*((rho/rho_sl)*CLmax_to);
    W_S_land_cor = W_S_land/Wland_W0;

    %cruise
    V_cr = 379.76; %ft/s
    q = (rho_cr*V_cr^2)/2;
    W_S_cr = W_S_sweep.*Wcr_W0;
    P_W_cr = (V_cr/(550*prop_efficiency)).*((q./W_S_cr).*CD0_clean + (W_S_cr./q).*k_clean); 
    P_W_cr_cor = (P_W_cr).*(Wcr_W0/Pcr_P0); %hp/lb

    %ceiling
    G = 0.001;
    V_ce = 350;
    P_W_ce = (V_ce/(550*prop_efficiency))*(G + 2*sqrt(CD0_clean*k_clean));
    Pce_P0 = (rho_ce/rho_sl)^0.8;
    P_W_ce_cor = ones([1, 200]).*(P_W_ce)*(Wce_W0/Pce_P0);

    function P_W_climb_cor = climb(G,CLmax,ks,prop_efficiency,Wclimb_W0, rho_clm,rho_sl, L_D_clm)
        CL = CLmax/ks^2;
        P_W_climb = ((sqrt(W_S_sweep)*(G + (L_D_clm)^-1))/(18.97*prop_efficiency*(rho_clm/rho_sl)*(sqrt(CL))));
        P_W_climb_cor = (Wclimb_W0^(2/3))*P_W_climb;
    end
    %takeoff climb (denver hot day)
    G_to_clm = .04;
    ks = 1.2;
    P_W_to_clm = climb(G_to_clm, CLmax_to,ks,prop_efficiency,Wclimb_W0,rho,rho_sl,L_D_to_gear);
   
    %critical loss of thrust
    G_crit = 0.01;
    ks_crit = 1.2;
    P_W_crit = climb(G_crit, CLmax_to, ks_crit, prop_efficiency, Wclimb_W0, rho_400, rho_sl,L_D_to);
    P_W_crit_cor = (Neng/(Neng-1))*P_W_crit;

    %balked landing configuration
    CLmax_land = 3.0;
    %balked landing 
    G_land = 0.03;
    ks_land = 1.3;
    P_W_balked = climb(G_land, CLmax_land, ks_land, prop_efficiency, Wland_W0, rho, rho_sl,L_D_land_gear);

    %plot
    figure();
    hold on;
    
    % Plot lines and assign graphic handles
    h(1) = plot(W_S_sweep, P_W_to, 'LineWidth', 1.5, 'Color', 'blue', 'DisplayName', 'Takeoff');
    h(2) = xline(W_S_land_cor, 'LineWidth', 1.5, 'Color', 'black', 'DisplayName', 'Landing');
    h(3) = plot(W_S_sweep, P_W_cr_cor, 'LineWidth', 1.5, 'Color', 'red', 'DisplayName', 'Cruise');
    h(4) = plot(W_S_sweep, P_W_ce_cor, 'LineWidth', 1.5, 'Color', 'magenta', 'DisplayName', 'Ceiling');
    h(5) = plot(W_S_sweep, P_W_to_clm, 'LineWidth', 1.5, 'Color', 'green', 'DisplayName', 'Takeoff Climb');
    h(6) = plot(W_S_sweep, P_W_crit_cor, 'LineWidth', 1.5, 'Color', [0.85 0.7 0], 'DisplayName', 'Critical Loss of Thrust'); % Darker yellow for visibility
    h(7) = plot(W_S_sweep, P_W_balked, 'LineWidth', 1.5, 'Color', 'cyan', 'DisplayName', 'Balked Landing Climb');
    
    xlabel('Wing Loading, W/S (lb/ft^2)');
    ylabel('P/W');
    title('P/W vs W/S');
    grid on;
    
    % Explicitly generate the legend using the handles
    legend(h, 'Location', 'Northeast');
    
    hold off;

end