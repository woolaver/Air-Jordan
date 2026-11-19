
function [Wf, Wf_W0, L_D, fuelfrac] = fuel_fraction_calc_refined(P, W0, aircraft)
    % Inputs: P [hp], W0 [lb], aircraft struct
    
    % constants from struct
    c    = aircraft.specific_fuel_consumption_cruise;   % lb/(hp*h)
    c_ft = c/(550*3600);                                 % 1/ft  (lb/(ft*lbf/s * s))
    eta  = aircraft.prop_efficiency;
    S    = aircraft.wing_area;
    g    = 32.174;
    dT   = aircraft.dT_K;                                % ISA + 18 F = +10 K
    h_cr = aircraft.alt_cr;                              % ft
    V_cr = aircraft.V_cr*1.688;                          % kt -> ft/s (TAS)

    CD0_clean = aircraft.CD0_clean;
    CD0_climb = CD0_clean + .0325;                       % climb flaps (gear up)
    e_clean   = aircraft.e_cr;
    e_climb   = 0.8*e_clean/0.825;                       % keep original climb/clean ratio
    k_clean   = 1/(pi*e_clean*aircraft.AR);
    k_climb   = 1/(pi*e_climb*aircraft.AR);

    % taxi (15 min at 5% power) and takeoff (1 min at full power)
    W1_W0 = 1 - c*(15/60)*(0.05*P/W0);   W1 = W1_W0*W0;
    W2_W1 = 1 - c*(1/60)*(P/W1);         W2 = W2_W1*W1;

    % climb: energy method, clean config, ~160 kt climb, then accelerate to V_cr at h_cr
    n   = 100;
    hv  = linspace(0, h_cr, n);
    V_y = min(160*1.688, V_cr);                       % climb speed [ft/s]
    Vv  = linspace(min(80*1.688, V_y), V_y, n);       % accelerate to climb speed over the climb
    W   = W2;  climb_ok = true;
    for i = 1:n-1
        d_he = (hv(i+1) - hv(i)) + (Vv(i+1)^2 - Vv(i)^2)/(2*g);
        hm = 0.5*(hv(i) + hv(i+1));  Vm = 0.5*(Vv(i) + Vv(i+1));
        rho = density_isa_offset(hm, dT);
        CL  = 2*W/(rho*Vm^2*S);
        D   = 0.5*rho*Vm^2*S*(CD0_clean + k_clean*CL^2);
        T   = eta*P*550/Vm;
        xs  = 1 - D/T;                                % specific excess power fraction
        if xs < 0.1, xs = 0.1; climb_ok = false; end  % guard: weak climb -> flag
        W   = W*exp(-c_ft*d_he/(eta*xs));
    end
    % level acceleration at h_cr from V_y to V_cr
    rho = density_isa_offset(h_cr, dT);  Vm = 0.5*(V_y + V_cr);
    CL  = 2*W/(rho*Vm^2*S);
    D   = 0.5*rho*Vm^2*S*(CD0_clean + k_clean*CL^2);  T = eta*P*550/Vm;
    xs  = 1 - D/T;  if xs < 0.1, xs = 0.1; climb_ok = false; end
    W   = W*exp(-c_ft*((V_cr^2 - V_y^2)/(2*g))/(eta*xs));
    if ~climb_ok, warning('Climb/acceleration power marginal at %.0f ft (D/T > 0.9)', h_cr); end
    W3 = W;  W3_W2 = W3/W2;

    % fuel cruise segment (R_fuel at h_cr, V_cr)
    R_seg = aircraft.R_fuel*6076/200;
    rho_cr = density_isa_offset(h_cr, dT);
    W = W3;
    for i = 1:200
        CL  = 2*W/(rho_cr*V_cr^2*S);
        L_D = CL/(CD0_clean + k_clean*CL^2);
        W   = W*exp(-R_seg*c_ft/(eta*L_D));
    end
    W4 = W;  W4_W3 = W4/W3;

    % descent
    W5_W4 = 0.992;  % historical

    % emergency range - entirely battery
    W6_W5 = 1;

    % landing
    W7_W6 = 0.992;

    % total
    W7_W0 = W7_W6*W6_W5*W5_W4*W4_W3*W3_W2*W2_W1*W1_W0;
    Wf_W0 = 1 - W7_W0;
    Wf    = Wf_W0*W0;

    fuelfrac = struct('taxi',W1_W0,'takeoff',W2_W1,'climb',W3_W2,'cruise',W4_W3, ...
                      'descent',W5_W4,'loiter',W6_W5,'landing',W7_W6,'total',Wf_W0, ...
                      'L_D_cruise',L_D,'CL_cruise',2*W4/(rho_cr*V_cr^2*S));
end
