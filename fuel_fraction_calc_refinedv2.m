function [Wf, Wf_W0, L_D, fuelfrac] = fuel_fraction_calc_refined(P, W0, aircraft)
% FUEL_FRACTION_CALC_REFINED  (korrigierte Version, 08.11.2026)
% Inputs: P [hp], W0 [lb], aircraft struct. Gleiche Ausgaben wie die Team-Version.
% Korrekturen (siehe REVIEW):
%  F1 Geschwindigkeiten in ft/s (Team: kt in Formeln mit ft und slug)
%  F2 ISA+18 F = +10 K (Team: density_isa_offset(h, 18) = ISA+18 K)
%  F3 Steigflug: Energiehoehe pro Segment dh + d(V^2)/(2g) (Team: h(i) + .../2*g) und
%     Produkt ueber alle Segmente (Team: nur das letzte Segment)
%  F4 Reiseflug: Produkt der Segmentbrueche einmal verwendet (Team: W4_W3(end)^200 UND Wcr)
%  F5 Reiseflughoehe aus aircraft.alt_cr (Team: fest 10,000 ft)
%  F7 Steigflug ab 120 kt in Reiseflugkonfiguration (Team: Klappen-C_D0 bis 225 kt -> D > T, Bruch > 1)
%  F6 Warteschleife: Breguet-Endurance fuer Propeller mit L/D bei der geflogenen Geschwindigkeit
%     (Team: CL^1.5/CD statt L/D)
c    = aircraft.specific_fuel_consumption_cruise;   % [lb/(hp*h)]
eta  = aircraft.prop_efficiency;
S    = aircraft.wing_area;
g    = 32.174;
kt   = 1.68781;                                     % F1
dT   = 10;                                          % F2 [K]
V_cr = aircraft.V_cr*kt;
CD0_clean = aircraft.CD0_clean;
CD0_climb = CD0_clean + .0325;
k_clean = 1/(pi*0.825*aircraft.AR);
k_climb = 1/(pi*0.8*aircraft.AR);
c_ft = c/(550*3600);                                % [1/ft]
% taxi + take-off (Team)
W1_W0 = 1 - c*(15/60)*(0.05*P/W0);   W1 = W1_W0*W0;
W2_W1 = 1 - c*(1/60)*(P/W1);         W2 = W2_W1*W1;
% climb: 0 -> alt_cr, 50 kt -> V_cr                 F3, F5
n  = 100;
Vc = linspace(50*kt, V_cr, n);
h  = linspace(0, aircraft.alt_cr, n);
W  = W2;
for i = 1:n-1
    dhe  = (h(i+1) - h(i)) + (Vc(i+1)^2 - Vc(i)^2)/(2*g);
    rhoi = density_isa_offset(h(i), dT);
    CL = 2*W/(rhoi*Vc(i)^2*S);
    if Vc(i) < 120*kt                                % F7 flaps/gear only in the first part of the climb
        D = 0.5*rhoi*Vc(i)^2*S*(CD0_climb + k_climb*CL^2);
    else
        D = 0.5*rhoi*Vc(i)^2*S*(CD0_clean + k_clean*CL^2);
    end
    T  = eta*P*550/Vc(i);
    if D >= T, error('fuel_fraction_calc_refined: D >= T im Steigflug bei %.0f kt', Vc(i)/kt); end
    W  = W*exp(-c_ft*dhe/(eta*(1 - D/T)));
end
W3 = W;  W3_W2 = W3/W2;
% cruise                                             F4, F5
R_seg = aircraft.R_fuel*6076/200;
rho_cr = density_isa_offset(aircraft.alt_cr, dT);
Wcr = W3;
for i = 1:200
    CL  = 2*Wcr/(rho_cr*V_cr^2*S);
    L_D = CL/(CD0_clean + k_clean*CL^2);
    Wcr = Wcr*exp(-R_seg*c_ft/(eta*L_D));
end
W4_W3 = Wcr/W3;
W5_W4 = 0.992;  W5 = W5_W4*Wcr;                     % descent (Team)
% loiter at minimum power (props), 5,000 ft             F6
rho_l = density_isa_offset(5000, dT);
CL_l  = sqrt(3*CD0_clean/k_clean);
LD_l  = CL_l/(CD0_clean + k_clean*CL_l^2);
V_l   = sqrt(2*W5/(rho_l*S*CL_l));
W6_W5 = exp(-(aircraft.divert_time*60)*V_l*c_ft/(eta*LD_l));
W7_W6 = 0.992;                                      % landing (Team)
W7_W0 = W7_W6*W6_W5*W5_W4*W4_W3*W3_W2*W2_W1*W1_W0;
Wf_W0 = 1 - W7_W0;  Wf = Wf_W0*W0;
fuelfrac = struct('taxi',W1_W0,'takeoff',W2_W1,'climb',W3_W2,'cruise',W4_W3,'descent',W5_W4, ...
                  'loiter',W6_W5,'landing',W7_W6,'total',Wf_W0,'LD_cruise',L_D,'LD_loiter',LD_l,'V_loiter_kt',V_l/kt);
end
