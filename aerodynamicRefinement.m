function [CD0_clean, CD0_land, CD0_takeoff, CD0_land_brake] = aerodynamicRefinement(aircraft)
%Using Cinar slides 15-Aerodynamic Refinement, update aerodynamic values,
%Computes updated drag polar
%Inputs:
%   aircraft: struct containing all aircraft values
%Outputs:
%   CD0_clean: Clean aircraft CD0 estimate
%   CD0_takeoff: Takeoff configuration CD0 estimate
%   CD0_landing: Takeoff configuration CD0 estimate
    
    %Component Build-up Method to get Parasite Drag
    %Components: fuselage, wing, horizontal stabilizer, vertical
    %stabilizer
    Sref = aircraft.wing_area;
    S_wet_wing = aircraft.wing_area*2;
    S_wet_fus = aircraft.S_wet_fuselage;
    S_wet_h_tail = aircraft.S_wet_horizontalStabilizer;
    S_wet_v_tail = aircraft.S_wet_verticalStabilizer;

    %Calculate flat-plate skin friction coefficient
    %assuming cruise condition
    alt_cr = aircraft.alt_cr; %ft converted to meters
    [~, a_cr, ~, rho_cr] = atmoscoesa(alt_cr/3.281);
    rho_cr = rho_cr/515.4; %slug/ft^3
   
    a_cr = a_cr*3.281; %ft/s

    [T_land, ~, ~, ~] = atmoscoesa(0);
    T_land = T_land + (18*(5/9)); %ISA + 18F
    T_takeoff = T_land;

    gamma = 1.4;
    R = 287; %J/kg*K

    a_land = sqrt(gamma*R*T_land)*3.281; %ft/s
    a_takeoff = sqrt(gamma*R*T_takeoff)*3.281; %ft/s

    rho_takeoff = aircraft.rho_takeoff;
    rho_land = aircraft.rho_takeoff;
    
    lc_wing = aircraft.wing_MAC;
    V_cr = aircraft.V_cr*1.688; %225 kts to ft/s
    V_land = aircraft.V_land*1.688;
    V_takeoff = aircraft.V_takeoff*1.688;
    mu = 3.582*10^(-7); %lbf*s/ft^2, assuming constant mu at STP
    Rec_wing = (rho_cr*lc_wing*V_cr)/mu;
    Rec_wing_land = (rho_land*lc_wing*V_land)/mu;
    Rec_wing_takeoff = (rho_takeoff*lc_wing*V_takeoff)/mu;

    lc_fus = aircraft.fuselage_length;
    Rec_fus = (rho_cr*lc_fus*V_cr)/mu;
    Rec_fus_land = (rho_land*lc_fus*V_land)/mu;
    Rec_fus_takeoff = (rho_takeoff*lc_fus*V_takeoff)/mu;

    lc_h_tail = aircraft.h_tail_MAC;
    Rec_h_tail = (rho_cr*lc_h_tail*V_cr)/mu;
    Rec_h_tail_land = (rho_land*lc_h_tail*V_land)/mu;
    Rec_h_tail_takeoff = (rho_takeoff*lc_h_tail*V_takeoff)/mu;

    lc_v_tail = aircraft.v_tail_MAC;
    Rec_v_tail = (rho_cr*lc_v_tail*V_cr)/mu;
    Rec_v_tail_land = (rho_land*lc_v_tail*V_land)/mu;
    Rec_v_tail_takeoff = (rho_takeoff*lc_v_tail*V_takeoff)/mu;
    
    %using Raymer's estimations for laminar and turbulent flow
    lam_percent_wing = .5;
    lam_percent_fus = .25;
    lam_percent_h_tail = .5;
    lam_percent_v_tail = .5;

    Cf_lam_wing = 1.328/sqrt(Rec_wing);
    Cf_lam_fus = 1.328/sqrt(Rec_fus);
    Cf_lam_h_tail = 1.328/sqrt(Rec_h_tail);
    Cf_lam_v_tail = 1.328/sqrt(Rec_v_tail);

    Cf_lam_wing_land = 1.328/sqrt(Rec_wing_land);
    Cf_lam_fus_land = 1.328/sqrt(Rec_fus_land);
    Cf_lam_h_tail_land = 1.328/sqrt(Rec_h_tail_land);
    Cf_lam_v_tail_land = 1.328/sqrt(Rec_v_tail_land);

    Cf_lam_wing_takeoff = 1.328/sqrt(Rec_wing_takeoff);
    Cf_lam_fus_takeoff = 1.328/sqrt(Rec_fus_takeoff);
    Cf_lam_h_tail_takeoff = 1.328/sqrt(Rec_h_tail_takeoff);
    Cf_lam_v_tail_takeoff = 1.328/sqrt(Rec_v_tail_takeoff);

    M_cr = V_cr/a_cr;
    M_land = V_land/a_land;
    M_takeoff = V_takeoff/a_takeoff;

    Cf_turb_wing = .455/(log10(Rec_wing)^(2.58) * (1 + .144*M_cr^2)^(.65));
    Cf_turb_fus = .455/(log10(Rec_fus)^(2.58) * (1 + .144*M_cr^2)^(.65));
    Cf_turb_h_tail = .455/(log10(Rec_h_tail)^(2.58) * (1 + .144*M_cr^2)^(.65));
    Cf_turb_v_tail = .455/(log10(Rec_v_tail)^(2.58) * (1 + .144*M_cr^2)^(.65));

    Cf_turb_wing_land = .455/(log10(Rec_wing_land)^(2.58) * (1 + .144*M_land^2)^(.65));
    Cf_turb_fus_land = .455/(log10(Rec_fus_land)^(2.58) * (1 + .144*M_land^2)^(.65));
    Cf_turb_h_tail_land = .455/(log10(Rec_h_tail_land)^(2.58) * (1 + .144*M_land^2)^(.65));
    Cf_turb_v_tail_land = .455/(log10(Rec_v_tail_land)^(2.58) * (1 + .144*M_land^2)^(.65));

    Cf_turb_wing_takeoff = .455/(log10(Rec_wing_takeoff)^(2.58) * (1 + .144*M_takeoff^2)^(.65));
    Cf_turb_fus_takeoff = .455/(log10(Rec_fus_takeoff)^(2.58) * (1 + .144*M_takeoff^2)^(.65));
    Cf_turb_h_tail_takeoff = .455/(log10(Rec_h_tail_takeoff)^(2.58) * (1 + .144*M_takeoff^2)^(.65));
    Cf_turb_v_tail_takeoff = .455/(log10(Rec_v_tail_takeoff)^(2.58) * (1 + .144*M_takeoff^2)^(.65));
    
    Cf_tot_wing = Cf_lam_wing*lam_percent_wing + Cf_turb_wing*(1-lam_percent_wing);
    Cf_tot_fus = Cf_lam_fus*lam_percent_fus + Cf_turb_fus*(1-lam_percent_fus);
    Cf_tot_h_tail = Cf_lam_h_tail*lam_percent_h_tail + Cf_turb_h_tail*(1-lam_percent_h_tail);
    Cf_tot_v_tail = Cf_lam_v_tail*lam_percent_v_tail + Cf_turb_v_tail*(1-lam_percent_v_tail);

    Cf_tot_wing_land = Cf_lam_wing_land*lam_percent_wing + Cf_turb_wing_land*(1-lam_percent_wing);
    Cf_tot_fus_land = Cf_lam_fus_land*lam_percent_fus + Cf_turb_fus_land*(1-lam_percent_fus);
    Cf_tot_h_tail_land = Cf_lam_h_tail_land*lam_percent_h_tail + Cf_turb_h_tail_land*(1-lam_percent_h_tail);
    Cf_tot_v_tail_land = Cf_lam_v_tail_land*lam_percent_v_tail + Cf_turb_v_tail_land*(1-lam_percent_v_tail);

    Cf_tot_wing_takeoff = Cf_lam_wing_takeoff*lam_percent_wing + Cf_turb_wing_takeoff*(1-lam_percent_wing);
    Cf_tot_fus_takeoff = Cf_lam_fus_takeoff*lam_percent_fus + Cf_turb_fus_takeoff*(1-lam_percent_fus);
    Cf_tot_h_tail_takeoff = Cf_lam_h_tail_takeoff*lam_percent_h_tail + Cf_turb_h_tail_takeoff*(1-lam_percent_h_tail);
    Cf_tot_v_tail_takeoff = Cf_lam_v_tail_takeoff*lam_percent_v_tail + Cf_turb_v_tail_takeoff*(1-lam_percent_v_tail);

    %Pressure drag estimation

    fus_height = aircraft.fuselage_height; %from PDR drawings
    fus_width = aircraft.fuselage_width; %from PDR drawings
    A_fus_max = pi*(fus_height/2)*(fus_width/2);
    f_fus = lc_fus/sqrt((4/pi)*A_fus_max);

    x_c_wing = .441;
    t_c_wing = .15;
    sweep_wing = deg2rad(0);

    x_c_h_tail = x_c_wing; %horizontal tail uses same airfoil as wing
    t_c_h_tail = t_c_wing;
    sweep_h_tail = deg2rad(4.76);

    x_c_v_tail = .3; %from NACA 0012 airfoil
    t_c_v_tail = .12;
    sweep_v_tail = deg2rad(40);

    FF_wing = (1 + (.6/x_c_wing)*(t_c_wing) + 100*(t_c_wing)^4)*(1.34*M_cr^(.18)*cos(sweep_wing)^(.28)); %equation from slide 13 of Cinar slides, x/c, t/c values from NLF-0115 airfoil
    FF_fus = (.9 + (5/f_fus^(1.5)) + (f_fus/400)); %equation from slide 13 of Cinar slides
    FF_h_tail = 1.1*(1 + (.6/x_c_h_tail)*(t_c_h_tail) + 100*(t_c_h_tail)^4)*(1.34*M_cr^(.18)*cos(sweep_h_tail)^(.28)); %1.1* due to tail surface with hinged rudder/elevator having 10% higher form factor
    FF_v_tail = 1.1*(1 + (.6/x_c_v_tail)*(t_c_v_tail) + 100*(t_c_v_tail)^4)*(1.34*M_cr^(.18)*cos(sweep_v_tail)^(.28)); 

    FF_wing_land = (1 + (.6/x_c_wing)*(t_c_wing) + 100*(t_c_wing)^4)*(1.34*M_land^(.18)*cos(sweep_wing)^(.28)); %equation from slide 13 of Cinar slides, x/c, t/c values from NLF-0115 airfoil
    FF_fus_land = (.9 + (5/f_fus^(1.5)) + (f_fus/400)); %equation from slide 13 of Cinar slides
    FF_h_tail_land = 1.1*(1 + (.6/x_c_h_tail)*(t_c_h_tail) + 100*(t_c_h_tail)^4)*(1.34*M_land^(.18)*cos(sweep_h_tail)^(.28)); %1.1* due to tail surface with hinged rudder/elevator having 10% higher form factor
    FF_v_tail_land = 1.1*(1 + (.6/x_c_v_tail)*(t_c_v_tail) + 100*(t_c_v_tail)^4)*(1.34*M_land^(.18)*cos(sweep_v_tail)^(.28)); 

    FF_wing_takeoff = (1 + (.6/x_c_wing)*(t_c_wing) + 100*(t_c_wing)^4)*(1.34*M_land^(.18)*cos(sweep_wing)^(.28)); %equation from slide 13 of Cinar slides, x/c, t/c values from NLF-0115 airfoil
    FF_fus_takeoff = (.9 + (5/f_fus^(1.5)) + (f_fus/400)); %equation from slide 13 of Cinar slides
    FF_h_tail_takeoff = 1.1*(1 + (.6/x_c_h_tail)*(t_c_h_tail) + 100*(t_c_h_tail)^4)*(1.34*M_land^(.18)*cos(sweep_h_tail)^(.28)); %1.1* due to tail surface with hinged rudder/elevator having 10% higher form factor
    FF_v_tail_takeoff = 1.1*(1 + (.6/x_c_v_tail)*(t_c_v_tail) + 100*(t_c_v_tail)^4)*(1.34*M_land^(.18)*cos(sweep_v_tail)^(.28)); 

    %Interference Factors

    Q_wing = 1;
    Q_fus = 1;
    Q_h_tail = 1.05; %Raymer does not have coefficient for T-tail, using conventional tail coefficient
    Q_v_tail = 1.05;

    %Miscellaneous Form Drag

    u_fus = deg2rad(aircraft.u_upsweep);
    D_q_fus = 3.83*u_fus^(2.5)*A_fus_max;

    A_gear_struts = 30/8; %from CAD as of 11/7, supposed to be the aft facing area of the struts, don't know how to actually get this so just dividing by 4 for now
    D_q_struts = (.139 + .419*(M_cr - .161)^2)*A_gear_struts;

    D_q_tires = (.25*(6.824319/2) + .15*(6.824319/2))*3; %area from CAD, divide by 2 to get frontal area, multiply by 3 to get all three wheel pairs
    D_q_landing_gear = 3*(1.17*(0.8180572/2)); %landing gear shocks estimated as round struts with Re < 3*10^5, flying slow so should be accurate, divide area by 2 to get frontal area and multiply by 3 for 3 landing gears
    
    D_q_air_scoop = 1.5*(.5);

    Ad = aircraft.num_propeller*(pi*aircraft.prop_diameter^2)/4;
    disk_area_ratio = Ad/Sref;

    D_q_stopped_prop = .8*disk_area_ratio*2*(pi*aircraft.prop_diameter^2)/4;
    D_q_air_brake = 0;   % no airbrake on the aircraft

    CD_mis_clean = (1/Sref)*(D_q_fus + D_q_struts + D_q_air_scoop);

    CD_mis_land = (1/Sref)*(D_q_fus + D_q_struts + D_q_air_scoop + D_q_tires + D_q_landing_gear + D_q_stopped_prop);
    CD_mis_land_brake = (1/Sref)*(D_q_fus + D_q_struts + D_q_air_scoop + D_q_tires + D_q_landing_gear + D_q_stopped_prop + D_q_air_brake);
    CD_mis_takeoff = (1/Sref)*(D_q_fus + D_q_struts + D_q_air_scoop + D_q_tires + D_q_landing_gear);

    %Flap Drag
    F_flap = .0074; %slotted flaps
    Cf = .3*lc_wing;
    C = lc_wing;
    S_flapped = 67.1668*2; %ft^2, from CAD, multiply by 2 to get both left and right flaps
    delta_flap = aircraft.delta_F;

    CD0_flap = F_flap*(Cf/C)*(S_flapped/Sref)*(delta_flap - 10);
    
    %Trim Drag
    CD_trim = .0026;

    Cf_total_clean = (Cf_tot_fus + Cf_tot_wing + Cf_tot_h_tail + Cf_tot_v_tail);

    disp("Cf_total_clean: " + Cf_total_clean)

    Leakage_factor = 1.075; %from Cinar, prop plane average
    CD0_clean = Leakage_factor*((1/Sref)*((Cf_tot_fus*FF_fus*Q_fus*S_wet_fus) + (Cf_tot_wing*FF_wing*Q_wing*S_wet_wing) + (Cf_tot_h_tail*FF_h_tail*Q_h_tail*S_wet_h_tail) + (Cf_tot_v_tail*FF_v_tail*Q_v_tail*S_wet_v_tail)) + CD_mis_clean) + CD_trim;
    CD0_land = Leakage_factor*((1/Sref)*((Cf_tot_fus_land*FF_fus_land*Q_fus*S_wet_fus) + (Cf_tot_wing_land*FF_wing_land*Q_wing*S_wet_wing) + (Cf_tot_h_tail_land*FF_h_tail_land*Q_h_tail*S_wet_h_tail) + (Cf_tot_v_tail_land*FF_v_tail_land*Q_v_tail*S_wet_v_tail)) + CD_mis_land) + CD0_flap;
    CD0_takeoff = Leakage_factor*((1/Sref)*((Cf_tot_fus_takeoff*FF_fus_takeoff*Q_fus*S_wet_fus) + (Cf_tot_wing_takeoff*FF_wing_takeoff*Q_wing*S_wet_wing) + (Cf_tot_h_tail_takeoff*FF_h_tail_takeoff*Q_h_tail*S_wet_h_tail) + (Cf_tot_v_tail_takeoff*FF_v_tail_takeoff*Q_v_tail*S_wet_v_tail)) + CD_mis_takeoff) + CD0_flap;
    CD0_land_brake = Leakage_factor*((1/Sref)*((Cf_tot_fus_land*FF_fus_land*Q_fus*S_wet_fus) + (Cf_tot_wing_land*FF_wing_land*Q_wing*S_wet_wing) + (Cf_tot_h_tail_land*FF_h_tail_land*Q_h_tail*S_wet_h_tail) + (Cf_tot_v_tail_land*FF_v_tail_land*Q_v_tail*S_wet_v_tail)) + CD_mis_land_brake) + CD0_flap;

    %find operating point conditions
    
    W0 = aircraft.W0;
    CL_cr = W0/(.5*rho_cr*V_cr^2*Sref);

    %1500 ft/min climb

    RC = 25; %ft/s
    climb_angle = asin(RC/V_cr);
    CL_climb = W0/(.5*rho_cr*V_cr^2*Sref*cos(climb_angle));

    %Create Drag Polars
    e_clean = .93; %from AVL analysis
    e_land = .78; %from AVL analysis
    e_takeoff = .78; %from AVL analysis

    AR = aircraft.AR;

    k_clean = 1/(pi*AR*e_clean);
    k_land = 1/(pi*AR*e_land);
    k_takeoff = 1/(pi*AR*e_takeoff);

    CL_vec = linspace(-10, 10, 1000000);

    Cr_index = find(CL_vec >= CL_cr, 1, 'first');
    Climb_index = find(CL_vec >= CL_climb, 1, 'first');

    CD_clean_polar = CD0_clean + k_clean.*CL_vec.^2;
    CD_land_polar = CD0_land + k_land.*CL_vec.^2;
    CD_takeoff_polar = CD0_takeoff + k_takeoff.*CL_vec.^2;
    CD_land_brake_polar = CD0_land_brake + k_land.*CL_vec.^2;

    CD_cr = CD_clean_polar(Cr_index);
    CD_climb = CD_clean_polar(Climb_index);

    L_D_cr = CL_cr/CD_cr;
    L_D_climb = CL_climb/CD_climb;

    figure()
    hold on
    plot(CD_clean_polar, CL_vec, 'LineWidth', 1)
    plot(CD_cr, CL_cr, '-o', 'LineWidth', 3)
    plot(CD_climb, CL_climb, '-o', 'LineWidth', 3)
    plot(CD_land_polar, CL_vec, 'LineWidth', 1)
    plot(CD_takeoff_polar, CL_vec, 'LineWidth', 1)
    plot(CD_land_brake_polar, CL_vec, 'LineWidth', 1)
    legend('Clean', 'Cruise Operating Point L/D = 11.1816', 'Climb Operating Point L/D = 11.1988', 'Landing', 'Takeoff', 'Landing with Air Brake')
    xlabel('CD')
    ylabel('CL')
    title('Component Build-Up Drag Polar')

    disp("L/D Cruise: " + L_D_cr)
    disp("L/D Climb: " + L_D_climb)
end
