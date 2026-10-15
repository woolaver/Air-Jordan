% Higher fidelity analysis of blown wing takeoff and landing parameters
% Using geometric estimates when needed, will be commented when used

clear
clc
close all

%% Initial Wing and Propeller Layout

AR = 11; %From aircraftDesignDriver
num_props = 10; 
S = 1058; %ft^2 from updated P-S plot
prop_diameter = 7; %ft, just an initital guess, sized to get disk_area_ratio ~ .35
Ad = num_props*(pi*prop_diameter^2)/4;

disk_area_ratio = Ad/S;
fB = .9; %following Courtin's assumption, most likely we can actually get this higher as the width of our fuselage will be very small compared to big ass wings

%% Thrust and slipstream speed from shaft power

rho = .002297; %slug/ft^3, 1.184 kg/m^3, ISA + 18F density
P_sh = 550*1765; %slug*ft^2/s^3, from updated P-S plot 1765 hp
eta_a = .84; %Taken from Cinar slides from X-57
V = 55*1.688; %ft/s, from 55 kts landing speed
delta_F = 60; %deg, 60 degree flap deflection
eta_F = .81; %estimated from graph in Cinar slides

function [delta_C_j, delta_j, T_c_prime] = calc_Tc(V, eta_a, rho, P_sh, Ad, disk_area_ratio, delta_F, eta_F)   
    syms Vj

    func = eta_a*P_sh == (rho*Ad/4)*(Vj - V)*((Vj + V)^2);
    sol = (vpasolve(func, Vj));
    Vj = double(vpa(sol(1), 3));

    T_c_prime = disk_area_ratio*((Vj^2/V^2) - 1);
    delta_C_j = T_c_prime*(1 + (V/Vj));

    delta_j = eta_F*delta_F;
end

[delta_C_j, delta_j, T_c_prime] = calc_Tc(V, eta_a, rho, P_sh, Ad, disk_area_ratio, delta_F, eta_F);


%% Estimate the powered lift curve

alpha = linspace(-5, 20, 1000);

CL_u = .1856 + .0334*delta_F + .0667.*alpha;

A0 = .1856 + .0334*delta_F + .0667.*alpha;
A1 = .0121*delta_j - .0085.*alpha + .0426;
A2 = .0140*delta_j + .0226.*alpha + .1407;

F_Cj = A0 + A1*sqrt(delta_C_j) + A2*delta_C_j;

F_0 = CL_u;

CL = CL_u + F_Cj - F_0;

%% Set the angle-of-attack limit (instead of a fixed CL_max)

alpha_stall = min(16 + 1.5*T_c_prime, 22);

delta_alpha = 10; % 10 degree stall marign from Courtin

alpha_max = alpha_stall - delta_alpha;
CL_max = CL(find(alpha <= alpha_max, 1, "last"));
figure()
hold on
plot(alpha, CL, 'LineWidth', 1, 'Color', 'Blue')
plot(alpha_max, CL_max, '-o', 'LineWidth', 3)
xlabel('\alpha (deg)')
ylabel('C_L')
legend('Lift Curve Slope', 'Max CL')
title('Powered Lift Curve')

%% Landing Approach and Distance

CD0 = .015 + .065 + .02;

gamma = deg2rad(linspace(-40, 10, 100)); %rad, sweep of flight path angles
V_A = linspace(25, 65, 100); %kts, sweep of approach speeds

CL_g = 1; %Courtin's EL-2 ground value
CD0_g = .5; %Courtin's EL-2 ground value
G = .87; %Courtin's EL-2, calculated based on height of the wing, don't know what this is
e_g = .8; %Courtin's EL-2, oswald efficiency
mu_b = .4; %Courtin's EL-2, breaking coefficient
W_S = 16; %preliminary wing loading estimate
k1 = 0; %don't actually know what this is but Cinar used this

V_TD = V_A.*1.688; %touchdown speed in ft/s = approach speed with no flare
h_obs = 50; %50 foot obstacle
g = 32.1; %ft/s^2
t_d = 1; %sec, time before brakes applied in landing roll

V_TD_vec = linspace(20, 60, 100).*1.688; %ft/s sweep over landing speeds from 20-60 kts
P_sh_vec = linspace(0, 1, 100).*P_sh; %sweep over power settings from 0-100%

e = .8; %estimated oswald efficiency factor

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
contourf(V_TD_vec./1.688, P_sh_vec./P_sh, landingDistance, [100, 200, 300, 400, 500, 600, 700])
contourf(V_TD_vec./1.688, P_sh_vec./P_sh, is_possible_alpha, [1, 1], 'g-', 'LineWidth', 2, 'FaceAlpha', .2)
contour(V_TD_vec./1.688, P_sh_vec./P_sh, landingDistance, [300, 300], 'r-', 'LineWidth', 2)
title('Steady approach and Landing Search')
xlabel('Touchdown Speed (kts)')
ylabel('Power Setting %')
legend('Landing Distance', 'Allowed Angle of Attack', '300 ft landing')
colorbar
hold off

%% Integrate Takeoff 

T0 = (2*rho*Ad)^(1/3)*(eta_a*P_sh)^(2/3); %Zero-velocity thrust

W = 16928; %lbs, conservative estimate from preliminary sizing code
m = W/32.1; %slugs
dt = .02; %s
V0 = 5*3.281; %ft/s, from 5m/s brake release speed from Cinar
mu = .0165; %rolling resistance, common value used for transport aircraft

a0 = g*(T0/W - mu);
s0 = V0^2/(2*a0);

%logic for controlling phase of takeoff
roll = 1; %1 = true, 0 = false
rotate = 0;
climb = 0;

%rotation quantity estimates
CL_tail = -.5; %initial CL_tail
CL_tail_dot = .5; %random estimate
c_bar = S/AR; %mean chord
Iyy = 20000; %slug*ft^2, estimate from light twin engine aircraft ~ 12500 lbs
Cm_wb_0 = .05; %estimate from google
x_mlg = .65*c_bar; %estimate from Cinar
x_cg = .35*c_bar; %estimate from Cinar
x_acw = .25*c_bar; %assuming ac is at quarter chord
Sh = .4*S; %estimated 40% sizing of tail
l_tail = 30; %ft, estimated from beechcraft baron
z_cg = 10; %ft, estimated from beechcraft baron
z_mlg = 0; %ft, main landing gear on the ground

%initialize arrays for storage
i = 1;
s = s0;
h = 0;
t = 0;
V = V0;
alpha = 3; %deg

%explicit euler method to time march
%assuming no mass loss during takeoff, fuel loss is pretty negligible
%anyway
while h < 50
    %assuming full throttle constantly, assuming constant rho, changes in
    %density are negligble from 0 - 50 ft
    [delta_C_j, delta_j, T_c_prime] = calc_Tc(V(i), eta_a, rho, P_sh, Ad, disk_area_ratio, delta_F, eta_F);

    if(climb == 1)
        disp(h(i))
        %estimate CL
        CL_u = .1856 + .0334*delta_F + .0667*alpha(i);
        A0 = .1856 + .0334*delta_F + .0667*alpha(i);
        A1 = .0121*delta_j - .0085*alpha(i) + .0426;
        A2 = .0140*delta_j + .0226*alpha(i) + .1407;
        F_Cj = A0 + A1*sqrt(delta_C_j) + A2*delta_C_j;
        F_0 = CL_u;
        
        CL = CL_u + F_Cj - F_0;
        CX = CD0 + CL^2/(pi*e*AR + 2*delta_C_j) - T_c_prime;

        L = .5*rho*V(i)^2*S*CL; %lbs
        X = .5*rho*V(i)^2*S*CX; %lbs

        V_dot = (-X - W*sin(gamma(i)))/m;
        V(i+1) = V(i) + V_dot*dt;

        gamma_dot = (L - W*cos(gamma(i)))/(m*V(i+1));

        gamma(i+1) = gamma(i) + gamma_dot*dt;
        s(i+1) = s(i) + V(i+1)*dt*cos(gamma(i+1));
        h(i+1) = h(i) + V(i+1)*dt*sin(gamma(i+1));
        alpha(i+1) = alpha(i); %hold angle of attack constant
    end

    if(rotate == 1)
        %estimate CL
        CL_u = .1856 + .0334*delta_F + .0667*alpha(i);
        A0 = .1856 + .0334*delta_F + .0667*alpha(i);
        A1 = .0121*delta_j - .0085*alpha(i) + .0426;
        A2 = .0140*delta_j + .0226*alpha(i) + .1407;
        F_Cj = A0 + A1*sqrt(delta_C_j) + A2*delta_C_j;
        F_0 = CL_u;
        
        CL = CL_u + F_Cj - F_0;
        CX = CD0 + CL^2/(pi*e*AR + 2*delta_C_j) - T_c_prime;

        L = .5*rho*V(i)^2*S*CL; %lbs
        X = .5*rho*V(i)^2*S*CX; %lbs

        V_dot = (-X - mu*(W - L))/m;
        gamma_dot = 0;

        if (alpha(i) < alpha_target)
            Cm_wb = Cm_wb_0 - .015*alpha(i); %estimated from google

            if(CL_tail > -2)
                CL_tail = CL_tail - CL_tail_dot*dt;
            end

            Cm_mlg = Cm_wb + CL*((x_mlg - x_acw)/c_bar) - CL_tail*(Sh/S)*((l_tail - x_mlg + x_cg)/c_bar) - (W/(.5*rho*V(i)^2*S))*((x_mlg - x_cg)/c_bar) + CX*((z_cg - z_mlg)/c_bar) + m*V_dot*((z_cg - z_mlg)/c_bar);
            M_mlg = Cm_mlg*.5*rho*V(i)^2*S*c_bar;
            Iyy_mlg = Iyy + m*((z_cg - z_mlg) + (x_mlg - x_cg))^2;

            q_dot = M_mlg/Iyy_mlg;
            alpha(i+1) = alpha(i) + q_dot*dt;

        else
            alpha(i+1) = alpha(i); %keep alpha constant once it reaches target
        end

            V(i+1) = V(i) + V_dot*dt;
            s(i+1) = s(i) + V(i+1)*dt;
            gamma(i+1) = gamma(i) + gamma_dot*dt;
            %no change in height during rotation
            h(i+1) = h(i);

            if (L >= W)
                alpha(i+1) = alpha_target;
                rotate = 0;
                climb = 1;
            end
    end

    if (roll == 1)
        %estimate CL
        CL_u = .1856 + .0334*delta_F + .0667*alpha(i);
        A0 = .1856 + .0334*delta_F + .0667*alpha(i);
        A1 = .0121*delta_j - .0085*alpha(i) + .0426;
        A2 = .0140*delta_j + .0226*alpha(i) + .1407;
        F_Cj = A0 + A1*sqrt(delta_C_j) + A2*delta_C_j;
        F_0 = CL_u;
        
        CL = CL_u + F_Cj - F_0;
        L = .5*rho*V(i)^2*S*CL; %lbs

        %estimate CX
        CX = CD0 + CL^2/(pi*e*AR + 2*delta_C_j) - T_c_prime;
    
        X = .5*rho*V(i)^2*S*CX; %lbs
    
        V_dot = (-X - mu*(W-L))/m;
    
        %no change in height during roll
        V(i+1) = V(i) + V_dot*dt;
        s(i+1) = s(i) + V(i+1)*dt;
        alpha(i+1) = alpha(i);
        gamma(i+1) = gamma(i);
        h(i+1) = h(i);

        alpha_stall = min(16 + 1.5*T_c_prime, 22); %deg
        alpha_allowed = alpha_stall - 8; %deg

        CL_u = .1856 + .0334*delta_F + .0667*alpha_allowed;
        A0 = .1856 + .0334*delta_F + .0667*alpha_allowed;
        A1 = .0121*delta_j - .0085*alpha_allowed + .0426;
        A2 = .0140*delta_j + .0226*alpha_allowed + .1407;
        F_Cj = A0 + A1*sqrt(delta_C_j) + A2*delta_C_j;
        F_0 = CL_u;
        
        CL_potential = CL_u + F_Cj - F_0;

        L_potential = .5*rho*V(i+1)^2*S*CL_potential;
        if (L_potential >= W)
            roll = 0;
            rotate = 1;
            alpha_target = alpha_stall - 8 - 4; %deg
        end
    end

    t(i+1) = t(i) + dt;
    i = i+1;
end

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
plot(t, alpha, 'LineWidth', 1, 'Color', 'Blue')
title('Takeoff Roll Angle of Attack vs. Time')
ylabel('Angle of Attack (deg)')
xlabel('Time (s)')
