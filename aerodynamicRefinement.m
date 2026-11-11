function [CD0_clean] = aerodynamicRefinement(aircraft)
%Using Cinar slides 15-Aerodynamic Refinement, update aerodynamic values,
%Computes updated drag polar
%Inputs:
%   aircraft: struct containing all aircraft values
%Outputs:
%   CD0_clean: Clean aircraft CD0 estimate
%   CD0_takeoff: Takeoff configuration CD0 estimate
%   CD0_landing: Takeoff configuration CD0 estimate
    
    %Component Build-up Method to get Parasite Drag
    %Components: fuselage, wing, empennage, horizontal stabilizer, vertical
    %stabilizer
    Sref = aircraft.S;
    S_wet_wing = aircraft.S*2;
    S_wet_fus = aircraft.S_fuselage;
    S_wet_emp = aircraft.S_wet_empennage;
    S_wet_h_tail = aircraft.S_wet_horizontalStabilizer;
    S_wet_v_tail = aircraft.S_wet_verticalStabilizer;

    %Calculate flat-plate skin friction coefficient
    %assuming cruise condition
    alt_cr = aircraft.alt_cr; %ft converted to meters
    [~, a_cr, ~, rho_cr] = atmoscoesa(alt_cr/3.281);
    rho_cr = rho_cr/515.4; %slug/ft^3
    a_cr = a_cr*3.281; %ft/s
    
    lc_wing = aircraft.wing_MAC;
    V_cr = aircraft.V_cr*1.688; %225 kts to ft/s
    mu = 3.582*10^(-7); %lbf*s/ft^2, assuming constant mu at STP
    Rec_wing = (rho_cr*lc_wing*V_cr)/mu;

    lc_fus = aircraft.fuselage_length;
    Rec_fus = (rho_cr*lc_fus*V_cr)/mu;

    lc_emp = aircraft.empennage_length;
    Rec_emp = (rho_cr*lc_emp*V_cr)/mu;

    lc_h_tail = aircraft.h_tail_MAC;
    Rec_h_tail = (rho_cr*lc_h_tail*V_cr)/mu;

    lc_v_tail = aircraft.v_tail_MAC;
    Rec_v_tail = (rho_cr*lc_v_tail*V_cr)/mu;
   
    %using Raymer's estimations for laminar and turbulent flow
    lam_percent_wing = .5;
    lam_percent_fus = .25;
    lam_percent_emp = .25;
    lam_percent_h_tail = .5;
    lam_percent_v_tail = .5;

    Cf_lam_wing = 1.328/sqrt(Rec_wing);
    Cf_lam_fus = 1.328/sqrt(Rec_fus);
    Cf_lam_emp = 1.328/sqrt(Rec_emp);
    Cf_lam_h_tail = 1.328/sqrt(Rec_h_tail);
    Cf_lam_v_tail = 1.328/sqrt(Rec_v_tail);

    M_cr = V_cr/a_cr;

    Cf_turb_wing = .455/(log10(Rec_wing)^(2.58) * (1 + .144*M_cr^2)^(.65));
    Cf_turb_fus = .455/(log10(Rec_fus)^(2.58) * (1 + .144*M_cr^2)^(.65));
    Cf_turb_emp = .455/(log10(Rec_emp)^(2.58) * (1 + .144*M_cr^2)^(.65));
    Cf_turb_h_tail = .455/(log10(Rec_h_tail)^(2.58) * (1 + .144*M_cr^2)^(.65));
    Cf_turb_v_tail = .455/(log10(Rec_v_tail)^(2.58) * (1 + .144*M_cr^2)^(.65));
    
    Cf_tot_wing = Cf_lam_wing*lam_percent_wing + Cf_turb_wing*(1-lam_percent_wing);
    Cf_tot_fus = Cf_lam_fus*lam_percent_fus + Cf_turb_fus*(1-lam_percent_fus);
    Cf_tot_emp = Cf_lam_emp*lam_percent_emp + Cf_turb_emp*(1-lam_percent_emp);
    Cf_tot_h_tail = Cf_lam_h_tail*lam_percent_h_tail + Cf_turb_h_tail*(1-lam_percent_h_tail);
    Cf_tot_v_tail = Cf_lam_v_tail*lam_percent_v_tail + Cf_turb_v_tail*(1-lam_percent_v_tail);

    %Pressure drag estimation

    fus_height = 6.9985; %from PDR drawings
    fus_width = 5.67; %from PDR drawings
    A_fus_max = pi*(fus_height/2)*(fus_width/2);
    f_fus = lc_fus/sqrt((4/pi)*A_fus_max);
    f_emp = lc_emp/sqrt((4/pi)*A_fus_max); %max area of empennage is same of fuselage

    x_c_wing = .441;
    t_c_wing = .15;
    sweep_wing = deg2rad(0);

    x_c_h_tail = x_c_wing; %horizontal tail uses same airfoil as wing
    t_c_h_tail = t_c_wing;
    sweep_h_tail = deg2rad(4.76);

    x_c_v_tail = .3; %from NACA 0012 airfoil
    t_c_v_tail = .12;
    sweep_v_tail = deg2rad(40);

    FF_wing = (1 + (.06/x_c_wing)*(t_c_wing) + 100*(t_c_wing)^4)*(1.34*M_cr^(.18)*cos(sweep_wing)^(.28)); %equation from slide 13 of Cinar slides, x/c, t/c values from NLF-0115 airfoil
    FF_fus = (.9 + (5/f_fus^(1.5)) + (f_fus/400)); %equation from slide 13 of Cinar slides
    FF_emp = (.9 + (5/f_emp^(1.5)) + (f_emp/400));
    FF_h_tail = 1.1*(1 + (.06/x_c_h_tail)*(t_c_h_tail) + 100*(t_c_h_tail)^4)*(1.34*M_cr^(.18)*cos(sweep_h_tail)^(.28)); %1.1* due to tail surface with hinged rudder/elevator having 10% higher form factor
    FF_v_tail = 1.1*(1 + (.06/x_c_v_tail)*(t_c_v_tail) + 100*(t_c_v_tail)^4)*(1.34*M_cr^(.18)*cos(sweep_v_tail)^(.28)); 

    %Interference Factors

    Q_wing = 1;
    Q_emp = 1.05; %Raymer does not have values for T-Tail, assuming conventional tail factor
    Q_fus = 1;
    Q_h_tail = 1;
    Q_v_tail = 1;

    %Miscellaneous Form Drag

    u_fus = deg2rad(19.9); %from CAD as of 11/7
    D_q_fus = 3.83*u_fus^(2.5)*A_fus_max;

    A_gear_struts = 31.043/4; %from CAD as of 11/7, supposed to be the aft facing area of the struts, don't know how to actually get this so just dividing by 4 for now
    D_q_struts = (.139 + .419*(M_cr - .161)^2)*A_gear_struts;

    CD_mis_clean = (1/Sref)*(D_q_fus + D_q_struts);

    CD0_clean = 1.075*((1/Sref)*((Cf_tot_fus*FF_fus*Q_fus*S_wet_fus) + (Cf_tot_emp*FF_emp*Q_emp*S_wet_emp) + (Cf_tot_wing*FF_wing*Q_wing*S_wet_wing) + (Cf_tot_h_tail*FF_h_tail*Q_h_tail*S_wet_h_tail) + (Cf_tot_v_tail*FF_v_tail*Q_v_tail*S_wet_v_tail)) + CD_mis_clean);
end