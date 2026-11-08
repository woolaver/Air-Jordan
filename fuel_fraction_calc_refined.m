
function [Wf, Wf_W0, L_D, fuelfrac] = fuel_fraction_calc_refined(P, W0, aircraft)
    % Inputs: P [hp], W0 [lb], aircraft struct
    
    % constants from struct
    c   = aircraft.specific_fuel_consumption_cruise;   % [lb/(hp*h)]
    eta = aircraft.prop_efficiency;
    S = aircraft.wing_area;
    g = 32.174; % [ft/s^2]
    V_cr = aircraft.V_cr;
    CD0_clean = aircraft.CD0_clean;
    CD0_climb = CD0_clean + .0325;
    CD0_climb_gear = CD0_clean + .0325 + .02;    
    e_clean = 0.825;
    e_climb = 0.8;
    k_clean = 1/(pi*e_clean*aircraft.AR);
    k_climb = 1/(pi*e_climb*aircraft.AR);
    % taxi
    W1_W0 = 1 - c*(15/60)*(0.05*P/W0);       % 15 min at 5% power
    W1    = W1_W0*W0;
    %takeoff
    W2_W1 = 1 - c*(1/60)*(P/W1);             % 1 min at full power
    W2 = W2_W1 * W1;
    % climb
    c_ft = c / (550 * 3600);
    Vclimb = linspace(50, 225, 100);
    h = linspace(0, 10000, 100);
    for i = 1:length(Vclimb) - 1
        d_he = h(i) + (Vclimb(i+1)^2 - Vclimb(i)^2) / 2*g;
        rhoi = density_isa_offset(h(i), 18);
        CL = 2*W2/(rhoi*Vclimb(i)^2*S);
        CD = CD0_climb + k_climb*CL^2;
        D = 0.5*rhoi*Vclimb(i)^2*S*CD;
        T = eta*P*550/Vclimb(i);
        W3_W2 = exp((-c_ft * d_he) / (eta * (1 - D / T)));
        W3 = W3_W2 * W2;
    end
    % cruise segment 
    R_ft  = aircraft.R_fuel*6076;            % fuel cruise distance [ft]
    n_segment = 200;
    R_seg = R_ft / n_segment;
    rho_cruise = density_isa_offset(10000, 18);
    Wcr = W3;
    for i = 1:n_segment
        CL = 2 * Wcr / (rho_cruise * V_cr^2 * S);
        CD = CD0_clean + k_clean * CL.^2;
        L_D = CL / CD;
        W4_W3(i) = exp(-R_seg * c_ft / (eta * L_D));
        Wcr = W4_W3(i) * Wcr;
    end
    W4_W3 = W4_W3(end) ^ 200;
    % descent
    W5_W4 = 0.992; % historical value
    % loiter
    W6_W5 = 0.992; % historical value 
    % total
    W6_W0 = W6_W5*W5_W4*W4_W3*W3_W2*W2_W1*W1_W0;
    Wf_W0 = 1 - W6_W0;
    Wf    = Wf_W0*W0;

    fuelfrac.taxi = W1_W0;
    fuelfrac.takeoff = W2_W1;
    fuelfrac.climb = W3_W2;
    fuelfrac.cruise = W4_W3;
    fuelfrac.descent = W5_W4;
    fuelfrac.loiter = W6_W5;

end