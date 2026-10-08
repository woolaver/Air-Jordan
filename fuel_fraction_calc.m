

% Function calculates updated fuel fraction value
% based on some refinements and historical data.
% This function is then called in our new weight iteration
% code to further refine our estimates.

% Inputs - P - power of engines (hp)
         % W0 - TOGW 0 lb
         % S - wing area ft^2
         % c_sl - power specific fuel consumption lb / hp *hr
         % eta - propeller efficiency


function [Wf, Wf_W0, L_D] = fuel_fraction_calc(P, W0, S, c_sl, eta)

    AR = 11;
    e = 0.825;
    k = 1 / (pi * e * AR);
    
    W1_W0 = 1 - c_sl * (15 / 60) * (0.05 * P / W0);    
    W1 = W1_W0 * W0;
    W2_W1 = 1 - c_sl * (1 / 60) * (P / W1);
    W3_W2 = 0.996; % historical value from Roskam
    
    % Cruise Aerodynamics
    S_wet_rest = 2500; % ft^2, will update with fuselage / empenage design
    Cf = 0.0045; % historical guess value - will update with airfoil design
    CD0 = Cf * (S_wet_rest + 2*S) / S;
    CL = sqrt(CD0 / k);
    L_D = (0.94 * CL) / (CD0 + k*CL^2);

    
    % Parameters for cruise segment
    R = 200 * 6076; % cruise distance in feet
    c_sl_ft = c_sl / (550 * 3600); % units 1 / ft

    W4_W3 = exp(-R * c_sl_ft / (eta * L_D)); % cruise segment

    % Descent and Landing
    W5_W4 = 0.992;  % historical value
    W6_W5 = 0.992; % historical value - assuming fully electric loiter
    W6_W0 = W6_W5 * W5_W4 * W4_W3 * W3_W2 * W2_W1 * W1_W0;
    Wf_W0 = 1 - W6_W0;
    Wf = Wf_W0 * W0;
        
end