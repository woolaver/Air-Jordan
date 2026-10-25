

function [Wf, Wf_W0, L_D] = fuel_fraction_calc(P, W0, aircraft)
         % Inputs: P [hp], W0 [lb], aircraft struct
         c   = aircraft.specific_fuel_consumption_cruise;   % [lb/(hp*h)]
         eta = aircraft.prop_efficiency;
         L_D = aircraft.L_D;

         W1_W0 = 1 - c*(15/60)*(0.05*P/W0);       % 15 min at 5% power
         W1    = W1_W0*W0;
         W2_W1 = 1 - c*(1/60)*(P/W1);             % 1 min at full power
         W3_W2 = 0.996;                           % historical value from Roskam

         R_ft  = aircraft.R_fuel*6076;            % fuel cruise distance [ft]
         c_ft  = c/(550*3600);                    % [1/ft]
         W4_W3 = exp(-R_ft*c_ft/(eta*L_D));       % cruise segment

         W5_W4 = 0.992;                           % historical value
         W6_W5 = 0.992;                           % historical value - assuming fully electric loiter
         W6_W0 = W6_W5*W5_W4*W4_W3*W3_W2*W2_W1*W1_W0;
         Wf_W0 = 1 - W6_W0;
         Wf    = Wf_W0*W0;
 end