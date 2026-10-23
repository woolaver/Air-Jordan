function [W0, out] = weightIterationEstimate_corrected(P, W0, S, WdivSDesign, eta, aircraft)
% Corrected version of weightIterationEstimate_new.m
%
% CHANGES (search "FIX"):
%  FIX A  Wing and tail area now change the empty weight. The original code took the
%         empty weight only from Raymer's statistical fraction A*W0^C, which assumes a
%         "typical" wing for a twin of that weight. rhoWing = 2.5 lb/ft^2 was defined
%         but never used, so the P-S search saw a 3x larger wing as weight-free.
%         Now: WE = A*W0^(1+C) + dW_wing + dW_tail + motors + battery, where
%         dW_wing = rhoWing*(S_exp - S_exp,ref) and dW_tail = rhoTail*(S_tails - S_tails,ref)
%         are the extra (or saved) structure relative to a reference wing at
%         aircraft.WS_ref (typical twin wing loading). Tails follow from volume coefficients,
%         so a bigger wing also brings bigger tails.
%  FIX B  "W0 = Nan" -> NaN (MATLAB is case sensitive; the old line threw an error
%         instead of flagging a non-converged design).
%  FIX C  Battery inputs (energy density, electric range) can be passed in p so the
%         driver and this function use the same values (driver: 500 Wh/kg, 200 nmi;
%         this file previously: 420 Wh/kg, 225 nmi).
%
% Inputs: P [hp], W0 guess [lb], S [ft^2], WdivSDesign [lb/ft^2], eta [-], p (optional struct)
% ASSUMPTIONS (to verify against Raymer, Aircraft Design 6th ed.):
%   rhoWing 2.5 lb/ft^2 exposed planform, rhoTail 2.0 lb/ft^2 (Table 15.2, GA column)
%   WS_ref 26 lb/ft^2 = typical twin-engine GA wing loading (Table 5.5)

    if nargin < 6, aircraft = struct(); end
    aircraft = defaults(aircraft);
    elec = hybrid_data(aircraft);

    tol = 1e-5; maxit = 200;
    A = 1.4; C = -0.10;                       % Raymer GA twin
    W_crew    = 190*8;
    W_payload = 30*8;

    P_electric   = P*elec.Hp;
    W_elec_motor = (P_electric/elec.motor_power_each)*elec.w_motor_each;
    R_ft      = elec.R*6076;
    e_battery = elec.eb_Whkg*3600;

    for i = 1:maxit
        [Wf, Wf_W0, L_D] = fuel_fraction_calc(aircraft);

        W_ec   = W0*(1 - Wf_W0);
        work_J = (W_ec*R_ft/L_D)*1.35582;
        W_batt = work_J/(eta*elec.eta_batt*e_battery*elec.degradation)*2.20462;

        % FIX A: area-dependent structure relative to the statistical reference wing
        S_ref   = W0/aircraft.WS_ref;
        dW_wing = aircraft.rhoWing*aircraft.f_exposed*(S - S_ref);
        dW_tail = aircraft.rhoTail*(tail_area(S, aircraft) - tail_area(S_ref, aircraft));

        WE    = A*W0^(1+C) + dW_wing + dW_tail + W_elec_motor + W_batt;
        WE_W0 = WE/W0;
        denom = 1 - Wf_W0 - WE_W0;
        if denom <= 0
            W0 = NaN;                                     % FIX B
            break
        end
        W0_new = (W_crew + W_payload)/denom;
        W0 = W0 + 0.2*(W0_new - W0);
        if abs(W0_new - W0)/abs(W0_new) < tol, break, end
    end

    [Sh, Sv] = tail_area(S, p);
    out = struct('W0',W0,'WE',WE,'Wf',Wf,'W_batt',W_batt,'W_ec',W_ec, ...
        'W_elec_motor',W_elec_motor,'W_crew',W_crew,'W_payload',W_payload, ...
        'dW_wing',dW_wing,'dW_tail',dW_tail,'S_ht',Sh,'S_vt',Sv,'L_D',L_D);
end

function [St, Sh, Sv] = tail_area(S, p)
% tail areas from volume coefficients at fixed tail arms (ft^2)
    b = sqrt(aircraft.AR*S); c = S/b;
    Sh = aircraft.cHT*c*S/aircraft.l_ht;
    Sv = aircraft.cVT*b*S/aircraft.l_vt;
    St = Sh + Sv;
    if nargout == 2, St = Sh; Sh = Sv; end      % [Sh, Sv] = tail_area(S,p)
end

function aircraft = defaults(aircraft)
    d = struct('AR',11,'rhoWing',2.5,'rhoTail',2.0,'f_exposed',0.90,'WS_ref',26, ...
    'cHT',0.90,'cVT',0.06,'l_ht',30.8,'l_vt',23.3, ...
    'eb_star',[],'e_range',[]);  
    f = fieldnames(d);
    for i = 1:numel(f)
        if ~isfield(aircraft,f{i}), aircraft.(f{i}) = d.(f{i}); end
    end
end

function elec = hybrid_data(aircraft)
    elec.Hp               = 0.8;     % hybrid power split
    elec.motor_power_each = 188;     % hp per motor
    elec.w_motor_each     = 33;      % lb
    elec.R                = 225;     % nmi electric cruise incl. 25 nmi takeoff/climb
    elec.eb_Whkg          = 420;     % Wh/kg
    elec.degradation      = 0.9;
    elec.eta_batt         = 0.90;
    elec.c_sl             = 0.3;
    if ~isempty(aircraft.eb_star),  elec.eb_Whkg = aircraft.eb_star/3600; end      % FIX C
    if ~isempty(aircraft.e_range),  elec.R = aircraft.e_range; end
end
