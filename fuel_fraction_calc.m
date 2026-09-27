% Function calculates updated fuel fraction value
% based on some refinements and historical data.
% This function is then called in our new weight iteration
% code to further refine our estimates.

function [Wf, Wf_W0] = fuel_fraction_calc(P, W0, C_sl)

    
W1_W0 = 1 - C_sl * (15 / 60) * (0.05 * P / W0);

W1 = W1_W0 * W0;
W2_W1 = 1 - C_sl * (1 / 60) * (T / W1);
W3_W2 = 0.996; % historical value from Roskam

CD0 = Cf * (S_wet_rest + 2*sqrt) / S;

CL = sqrt(CD0 / k);
L_D = (0.94 * CL) / (CD0 + k*CL^2);

W4_W3 = exp(-Rc / V*(L_D));
W5_W4 = ;  % historical value
W6_W5 = 1; % historical value - assuming fully electric loiter
W6_W0 = W6_W5 * W5_W4 * W4_W3 * W3_W2 * W2_W1 * W1_W0;

Wf_W0 = 1 - W6_W0;
Wf = Wf_W0 * W0;
    

end