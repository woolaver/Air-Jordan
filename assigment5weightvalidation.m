
%published specs
W0_actual = 3000;     
S_actual  = 66.7;         
P_takeoff_actual = 284;       
P_cruise_actual  = 161;     
b_span = 31.6;          
AR = 15.0;   
%environmental
eta = 0.82;  
Cf_clean = 0.0045;    
CLmax_clean = 1.7;      
CLmax_to    = 4.0;   
alt_cr = 8000; 

%standard atmos
rho_sl = 0.002377; 
T0 = 518.67;              
T_cr = T0 - 0.003566 * alt_cr; 
p_cr = 2116.22 * (T_cr / T0)^5.2559; 
rho_cr = p_cr / (1716.5 * T_cr); 
sigma_cr = rho_cr / rho_sl;

%speed+pressure
V_cr = 150 * 1.68781;
q_cr = 0.5 * rho_cr * V_cr^2;

%runway for x57
sTOG = 2500 / 1.66;
a = 0.009; b = 4.9;
TOP = (-b + sqrt(b^2 + 4 * a * sTOG)) / (2 * a);

%drag
Swet = 10^(-0.0866 + 0.8099 * log10(W0_actual)); 
k_clean = 1 / (pi * 0.825 * AR);
k_to    = 1 / (pi * 0.725 * AR);

%sweeping over wing
S_sweep = linspace(30, 150, 300);
nS = numel(S_sweep);
names = {'Takeoff', 'Cruise', 'Ceiling', 'Takeoff Climb', 'Maneuver'};
nC = numel(names);
P = zeros(nS, nC);

for i = 1:nS
    S = S_sweep(i);
    WS = W0_actual / S;
    CD0 = Cf_clean * Swet / S;
    
    %takeoff roll
    pw_to = WS / (TOP * sigma_cr * CLmax_to);
    P(i, 1) = pw_to * W0_actual;
    
    %v cruise
    pw_cr = (V_cr / (550 * eta)) * (q_cr / WS * CD0 + WS / q_cr * k_clean);
    P(i, 2) = pw_cr * W0_actual;
    
    %ceiling
    pw_ce = (350 / (550 * eta)) * (0.001 + 2 * sqrt(CD0 * k_clean));
    P(i, 3) = pw_ce * W0_actual;
    
    %takeoff climb
    CL_climb = CLmax_to / (1.2^2);
    LD_to = CLmax_to / ((CD0 + 0.065 + 0.02) + k_to * CLmax_to^2);
    pw_clm = (sqrt(WS) * (0.04 + 1 / LD_to)) / (18.97 * eta * sigma_cr * sqrt(CL_climb));
    P(i, 4) = pw_clm * W0_actual;
    
    %60 deg bank turn
    n_load = 2.0;
    pw_man = (V_cr / (550 * eta)) * (q_cr * CD0 / WS + WS * n_load^2 * k_clean / q_cr);
    P(i, 5) = pw_man * W0_actual;
end

%feasible range
P_env = max(P, [], 2);

%plotting
figure('Color', 'w', 'Position', [100, 100, 900, 600]);
hold on; grid on;

%plot constraint curves
plot(S_sweep, P(:, 1), 'b-', 'LineWidth', 1.8, 'DisplayName', 'Takeoff Field Length');
plot(S_sweep, P(:, 2), 'r-', 'LineWidth', 1.8, 'DisplayName', 'Cruise (150 kts)');
plot(S_sweep, P(:, 3), 'Color', [0.9 0.6 0], 'LineWidth', 1.8, 'DisplayName', 'Service Ceiling');
plot(S_sweep, P(:, 4), 'm-', 'LineWidth', 1.8, 'DisplayName', 'Takeoff Climb');
plot(S_sweep, P(:, 5), 'Color', [0.7 0.1 0.9], 'LineWidth', 1.8, 'DisplayName', 'Maneuver (60^\circ Turn)');

%feasible region shading
y_top = 400;
fill([S_sweep, fliplr(S_sweep)], [y_top * ones(size(S_sweep)), fliplr(P_env')], ...
    [0.6 0.85 0.6], 'FaceAlpha', 0.35, 'EdgeColor', 'none', 'DisplayName', 'Feasible Region');

%design point
plot(S_actual, P_takeoff_actual, 'kp', 'MarkerSize', 16, 'MarkerFaceColor', 'y', ...
    'LineWidth', 1.5, 'DisplayName', sprintf('NASA X-57 Actual Rating (%0.0f hp, S=%0.1f ft^2)', P_takeoff_actual, S_actual));

%annotation
text(S_actual + 3, P_takeoff_actual + 15, ...
    sprintf('NASA X-57 Operating Point\nInstalled: 284 hp, S = 66.7 ft^2\n(Inside Feasible Region)'), ...
    'FontSize', 9, 'FontWeight', 'bold', 'BackgroundColor', 'w', 'EdgeColor', 'k');

xlim([30, 150]);
ylim([0, y_top]);
xlabel('Wing Area, S (ft^2)', 'FontSize', 11, 'FontWeight', 'bold');
ylabel('Power, P (hp)', 'FontSize', 11, 'FontWeight', 'bold');
title('P vs S Constraint Space Validation: NASA X-57 Maxwell (Mod IV)', 'FontSize', 13, 'FontWeight', 'bold');
legend('Location', 'northeastoutside');
hold off;