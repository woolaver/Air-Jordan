function [W0, p] = weightIterationEstimate_new(P, W0, S, WdivSDesign, eta)
    
    % Inputs
    % P - power
    % W0 - initial weight guess
    % S - wing area
    % WdivSDesign - previous W/S design point
    % eta - propeller efficiency
    % hp - proposed engine horsepower

    % call in hybrid configuration data
    elec = hybrid_data();

    tol = 10e-5;
    maxit = 200;
   
    A = 1.4; % Raymer Constant
    C = -.10; % Raymer Constant
    
    W_crew = 190*8; % assumed 190 lbs per passenger, 7 passengers, 1 pilot
    W_payload = 30*8;% baggage per person

    rhoWing = 2.5; % from Raymer table 15.2

    n_engine = 10;
    
    S_design = W0 / WdivSDesign;
    

    P_electric = P * elec.Hp;
 %  disp('-----------------')
  %  disp(P_electric)
    % Motor sizing based on specific power
    W_elec_motor = (P_electric / elec.motor_power_each) * elec.w_motor_each;
   % disp('-----------------')
   % disp(W_elec_motor)
    R_ft = elec.R * 6076; % electric cruise range in feet
    e_battery = elec.eb_Whkg * 3600; % Joules

    

    for i = 1:maxit
        [Wf, Wf_W0, L_D] = fuel_fraction_calc(P, W0, S, elec.c_sl, eta);

        W_ec = W0 * (1 - Wf_W0);
        work_J = (W_ec * R_ft / L_D) * 1.35582; % J
        W_batt = work_J / (eta * elec.eta_batt * e_battery * elec.degradation) * 2.20462; % lbs
        
        
        WE = A * W0^(1+C) + W_elec_motor + W_batt;
        WE_W0 = WE / W0;

        denom = (1 - Wf_W0 - WE_W0);

        if denom <= 0
            W0 = Nan;
            break;
        end

        W0_new = (W_crew + W_payload) / denom; 
        
        % check for convergence
        
        W0 = W0 + 0.2*(W0_new - W0);
        delta = abs(W0_new - W0) / abs(W0_new);
        
        if delta < tol
            break;
        end

    end
    
    %save other weights in struct
    p.WE = WE;
    p.W0 = W0;
    p.Wf = Wf;
    p.W_batt = W_batt;
    p.W_ec = W_ec;
    p.W_elec_motor = W_elec_motor;
    p.W_crew = W_crew;
    p.W_payload = W_payload;

end

function elec = hybrid_data()
    elec.Hp          = 0.8;          % Hybrid Power Split
    elec.motor_power_each = 188;         % initial system selection hp per engine
    elec.w_motor_each   = 33; % lbs
    elec.R              = 225;          % nmi electric cruise incl. 25 nmi takeoff/climb
    elec.eb_Whkg     = 420;          % Wh/kg, researched battery specific energy
    elec.degradation = 0.9;
    elec.eta_batt    = 0.90;
    elec.c_sl        = 0.3;   
    elec.P_ref       = 1500; % guess power in hp
   
end
%[text] 

%[appendix]{"version":"1.0"}
%---
