function max_W_S_possible = blown_wing_landing(aircraft, W_S_sweep)
%function to find maximum wing loading possible with given aircraft
%assumptions in blown wing analysis
    
    % Landing Approach and Distance
    
    CD0 = .015 + .065 + .02;
        
    CL_g = 1; %Courtin's EL-2 ground value
    CD0_g = aircraft.CD0_g; %Courtin's EL-2 ground value
    G = aircraft.G; %Courtin's EL-2, calculated based on height of the wing, don't know what this is
    e_g = aircraft.e_g; %Courtin's EL-2, oswald efficiency
    mu_b = aircraft.mu_b; %Courtin's EL-2, breaking coefficient
    k1 = 0; %don't actually know what this is but Cinar used this
    rho = aircraft.rho_takeoff;
    AR = aircraft.AR;
    e = aircraft.e_land;
    eta_a = aircraft.eta_a;
    Ad = aircraft.prop_diameter;
    delta_F = aircraft.delta_F;
    eta_F = aircraft.eta_F;
    
    h_obs = 50; %50 foot obstacle
    g = 32.1; %ft/s^2
    t_d = 1; %sec, time before brakes applied in landing roll
    
    V_TD_vec = linspace(20, 60, 10).*1.688; %ft/s sweep over landing speeds from 20-60 kts
    P_sh_vec = linspace(0, 1, 10).*aircraft.max_power; %sweep over power settings from 0-100%
    
    e = aircraft.e_land; %estimated oswald efficiency factor
    
    alpha = zeros([length(V_TD_vec), length(P_sh_vec)]);
    alpha_stall = zeros([length(V_TD_vec), length(P_sh_vec)]);
    landingDistance = zeros([length(V_TD_vec), length(P_sh_vec)]);
    gamma_vec = zeros([length(V_TD_vec), length(P_sh_vec)]);
    is_possible_alpha = zeros([length(V_TD_vec), length(P_sh_vec)]);

    delta_alpha = 10;

    feasibleLanding = zeros(size(W_S_sweep));

    for m = 1:length(W_S_sweep)
        disp(m)
        S = aircraft.W0/W_S_sweep(m);
        disk_area_ratio = Ad/S;
        for i = 1:length(V_TD_vec)
            for j = 1:length(P_sh_vec)
                [delta_C_j, delta_j, T_c_prime] = calc_Tc(V_TD_vec(i), eta_a, rho, P_sh_vec(j), Ad, disk_area_ratio, delta_F, eta_F);
                q_inf = .5*rho*V_TD_vec(i)^2;
        
                %iterate flight path angle
                gamma = deg2rad(0); %0 radian initial flight path angle
                for n = 1:8
                    CL_k = (W_S_sweep(m)*cos(gamma))/q_inf;
                    Cx = CD0 + (CL_k^2)/(pi*e*AR + 2*delta_C_j) - T_c_prime;
                    gamma = asin(-1*(q_inf*Cx)/W_S_sweep(m));
                end
        
                gamma_vec(i, j) = gamma;
        
                c0 = .1856 + .0334*delta_F + sqrt(delta_C_j)*(.0121*delta_j + .0426) + delta_C_j*(.014*delta_j + .1407);
                c1 = .0667 - .0085*sqrt(delta_C_j) + .0226*delta_C_j;
                alpha(i, j) = (CL_k - c0)/c1;
        
                alpha_stall(i, j) = min(16 + 1.5*T_c_prime, 22);
        
                J_A = (rho/(2*W_S_sweep(m)))*(CD0_g + (k1 + (G/(pi*e_g*AR))*CL_k^2) - mu_b*CL_k);
                landingDistance(i, j) = h_obs/tan(abs(gamma)) + t_d*V_TD_vec(i) + 1/(2*g*J_A)*log(1 + ((J_A*V_TD_vec(i)^2)/mu_b));

                is_possible_alpha(i, j) = alpha(i,j) <= (alpha_stall(i,j) - delta_alpha);
            end
        end
        feasibleLanding(m) = any(landingDistance(:) <= 300 & any(imag(landingDistance(:)) ~= 0) & is_possible_alpha(:));
    end

    disp(feasibleLanding)

    max_W_S_possible = max(W_S_sweep(feasibleLanding == 1));

    function [delta_C_j, delta_j, T_c_prime] = calc_Tc(V, eta_a, rho, P_sh, Ad, disk_area_ratio, delta_F, eta_F)   
        syms Vj
    
        func = eta_a*P_sh == (rho*Ad/4)*(Vj - V)*((Vj + V)^2);
        sol = (vpasolve(func, Vj));
        Vj = double(vpa(sol(1), 3));
    
        T_c_prime = disk_area_ratio*((Vj^2/V^2) - 1);
        delta_C_j = T_c_prime*(1 + (V/Vj));
    
        delta_j = eta_F*delta_F;
    end
end