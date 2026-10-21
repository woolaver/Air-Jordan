% Higher fidelity analysis of blown wing takeoff and landing parameters
% Using geometric estimates when needed, will be commented when used
%
% CORRECTED VERSION (Oct 21 2026) - changes marked "FIX":
%  FIX 1  One consistent design point: W, S, AR, P_sh at the top; W_S = W/S (was a separate
%         hard-coded 16 lb/ft^2 while W = 16,928 lb and S = 1,058 ft^2 came from two other
%         sizing runs; the P-S design point was W0 ~ 10,700 lb).
%  FIX 2  Tail area from volume coefficients (tailSizing.m) instead of Sh = 0.4*S, and the
%         tail arm from the same layout as the AVL model (l_h ~ 30.8 ft).
%  FIX 3  Landing search: only points that are certifiable are shaded as allowed -
%         approach speed >= 1.30 V_S (former 14 CFR 23.73(b)) and, because this model has
%         no flare (touchdown at the approach speed), touchdown sink <= 10 ft/s
%         (former 14 CFR 23.473(d)). Without this mask the search picks touchdown speeds
%         below the stall speed and sink rates of 20-40 ft/s.
%  FIX 5  contourf(x, y, Z) needs Z(row = y index, column = x index). landingDistance(i,j)
%         is stored with i = speed (x) and j = power (y), so the original plots were
%         transposed (axes swapped without an error because the grid is 100 x 100). Now Z'.
%  FIX 6  calc_Tc: syms/vpasolve replaced by fzero (same equation, no toolbox, faster).
%  FIX 4  z_cg = 10 ft (from a Baron) flagged: CG height above ground of a high-wing
%         commuter is ~5-6 ft; it scales the drag/inertia moments in the rotation model.

clear
clc
close all

%% Initial Wing and Propeller Layout

% FIX 1: single design point (edit to the current P-S result)
AR = 11; %From aircraftDesignDriver
num_props = 10; 
S = 1058; %ft^2 from updated P-S plot  <- replace with the corrected P-S wing area
W = 16928; %lbs, take-off weight of the SAME design point as S
W_S = W/S; %lb/ft^2, consistent wing loading (was hard-coded 16)
prop_diameter = 7; %ft, just an initital guess, sized to get disk_area_ratio ~ .35
Ad = num_props*(pi*prop_diameter^2)/4;

disk_area_ratio = Ad/S;
fB = .65; %following Courtin's assumption, most likely we can actually get this higher as the width of our fuselage will be very small compared to big ass wings

%% Thrust and slipstream speed from shaft power

rho = .002297; %slug/ft^3, 1.184 kg/m^3, ISA + 18F density
P_sh = 550*1765; %slug*ft^2/s^3, from updated P-S plot 1765 hp
eta_a = .84; %Taken from Cinar slides from X-57
V = 55*1.688; %ft/s, from 55 kts landing speed
delta_F = 60; %deg, 60 degree flap deflection
eta_F = .81; %estimated from graph in Cinar slides

function [delta_C_j, delta_j, T_c_prime] = calc_Tc(V, eta_a, rho, P_sh, Ad, disk_area_ratio, delta_F, eta_F)   
    % FIX 6: numeric root instead of syms/vpasolve (same equation; ~100x faster in the
    % 100 x 100 landing loop, no Symbolic Toolbox needed, and the old vpa(...,3)
    % rounded Vj to 3 significant digits)
    f = @(Vj) (rho*Ad/4)*(Vj - V)*((Vj + V)^2) - eta_a*P_sh;
    hi = V + 50;
    while f(hi) < 0, hi = 2*hi; end
    Vj = fzero(f, [V, hi]);

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
% W_S defined at the top (FIX 1)
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
CL_stall = zeros([100, 100]);
CL_req = zeros([100, 100]);
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
        CL_stall(i, j) = c0 + c1*alpha_stall(i, j);   % FIX 3: powered CL at stall, this V and power
        CL_req(i, j) = CL_k;

        J_A = (rho/(2*W_S))*(CD0_g + (k1 + (G/(pi*e_g*AR))*CL_k^2) - mu_b*CL_k);
        landingDistance(i, j) = h_obs/tan(abs(gamma)) + t_d*V_TD_vec(i) + 1/(2*g*J_A)*log(1 + ((J_A*V_TD_vec(i)^2)/mu_b));
    end
end

%shade region where alpha < alpha_stall - delta_alpha
is_possible_alpha = alpha <= (alpha_stall - delta_alpha);

% FIX 3: certification mask. V >= 1.30 V_S at the same power  <=>  CL_req <= CL_stall/1.30^2
% (stall speed with the approach thrust, 14 CFR 23.2110(b)); touchdown sink <= 10 ft/s
[PP, VV] = meshgrid(P_sh_vec, V_TD_vec);           % rows = speed (i), columns = power (j)
sink_TD = VV.*sin(abs(gamma_vec));                 % ft/s, no flare in this model
is_certifiable = is_possible_alpha & (CL_req <= CL_stall/1.30^2) & (sink_TD <= 10);
fprintf('Landing points <= 300 ft: %d with the alpha-margin rule only, %d also certifiable\n', ...
    nnz(is_possible_alpha & landingDistance <= 300), nnz(is_certifiable & landingDistance <= 300));

figure()
hold on
contourf(V_TD_vec./1.688, P_sh_vec./P_sh, landingDistance', [100, 200, 300, 400, 500, 600, 700])
contourf(V_TD_vec./1.688, P_sh_vec./P_sh, is_possible_alpha', [1, 1], 'g-', 'LineWidth', 2, 'FaceAlpha', .2)
contour(V_TD_vec./1.688, P_sh_vec./P_sh, is_certifiable', [1, 1], 'k-', 'LineWidth', 2)
contour(V_TD_vec./1.688, P_sh_vec./P_sh, landingDistance', [300, 300], 'r-', 'LineWidth', 2)
title('Steady approach and Landing Search')
xlabel('Touchdown Speed (kts)')
ylabel('Power Setting %')
legend('Landing Distance', 'Allowed Angle of Attack', 'Certifiable (1.3 V_S, sink <= 10 ft/s)', '300 ft landing')
colorbar
hold off

%% Integrate Takeoff 

T0 = (2*rho*Ad)^(1/3)*(eta_a*P_sh)^(2/3); %Zero-velocity thrust

% W defined at the top (FIX 1)
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
% FIX 2: tail from volume coefficients (same arms as the AVL model)
x_wing_c4 = 20.0; x_ht_c4 = 50.8; x_vt_c4 = 43.3;  %ft, STOL481.avl layout - update with the CAD
tail = tailSizing(S, AR, 1.0, x_wing_c4, x_ht_c4, x_vt_c4);
Sh = tail.S_ht; %ft^2 (was 0.4*S)
l_tail = tail.l_h; %ft
z_cg = 10; %ft, estimated from beechcraft baron  <- FIX 4: check, ~5-6 ft for a high-wing commuter
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
