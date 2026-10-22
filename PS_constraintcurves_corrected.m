function [P_point, S_point, out] = PS_constraintcurves_corrected(S_sweep, W0, W_S_point, p)
% P-S constraint diagram (corrected version of PS_constraintcurves.m)
%
% CHANGES vs PS_constraintcurves.m (search "FIX" in this file):
%  FIX 1  Landing W/S used a hard-coded local CLMax_to = 5 while every other
%         constraint used p.CLmax_to = 10 -> the landing line (which sets the
%         minimum wing area) was based on half the lift coefficient of the take-off.
%         Now one landing value p.CLmax_ld is used everywhere.
%  FIX 2  Landing model: Raymer's conventional landing estimate
%         s = 80 (W/S)/(sigma CLmax) + S_a was used with S_a = 0 and an extra
%         0.75 factor on the 300 ft RFP distance. The 0.75 (operational landing-field
%         factor) is not part of the RFP definition, and S_a = 0 ignores the 50 ft
%         air segment. Two options now:
%           p.landing_model = 'blown'  (default): W/S_max = 0.5 rho V_S,max^2 CLmax_ld,
%               V_S,max = max. stall speed that still lands in 300 ft (from the
%               time-marching landing model, incl. 1.30 V_S approach, flare, braking)
%           p.landing_model = 'raymer' : Raymer ground-roll form with S_a and without
%               the 0.75 factor (kept for comparison; not valid for powered lift)
%  FIX 3  Cruise density: atmoscoesa got (12500*0.3048)/3.281, i.e. the altitude
%         was converted to metres and then divided by 3.281 again -> 1,161 m
%         instead of 3,810 m (rho 25 % too high). Replaced by an ISA function
%         (no Aerospace Toolbox needed).
%  FIX 4  Field condition is now an input (p.h_field_ft, p.dT_field_K). The old code
%         used a Colorado hot day (6,800 ft, 90 F; sigma = 0.69). Use the official
%         RFP field condition of the team.
%  FIX 5  Critical loss of thrust used Neng/(Neng-3). With N independent propulsors
%         and one failure the factor is N/(N-1) (p.Neng = number of independent
%         propulsors, 10 for the blown wing).
%  FIX 6  Hard-coded local AR = 11, W_S = 10.1463, CLMax_to = 5 removed; values
%         come from p.
%  FIX 7  Design point = the lightest point on the feasible boundary (minimum W0 from
%         the weight iteration) instead of "landing line x 1.025 on the maneuver line".
%  FIX 8  Weight iteration: weightIterationEstimate_corrected (wing and tail area now
%         change the empty weight; see that file).
%  FIX 9  Wetted area: the Roskam regression depends on W0 only, so a bigger wing
%         had no extra parasite drag. Now wetted_area_corrected(W0,S,p) adds the wetted
%         area of the extra wing and tail area (use it in fuel_fraction_calc.m too).
%
% Units as in the original: lb, ft, hp, slug/ft^3.

    p = defaults(p);
    S_sweep = S_sweep(:);

    % ---------------- environment (FIX 3, FIX 4)
    env.rho_sl  = 0.0023769;                                   % slug/ft^3
    env.rho     = isa_rho_slug(p.h_field_ft, p.dT_field_K);    % field
    env.rho_cr  = isa_rho_slug(p.alt_cr, 0);                   % cruise (ISA)
    env.rho_ce  = isa_rho_slug(p.h_ceiling_ft, 0);             % ceiling
    env.rho_400 = isa_rho_slug(p.h_field_ft + 400, p.dT_field_K);
    env.V_cr    = p.V_cr_kt*1.68781;                           % ft/s
    env.q_cr    = 0.5*env.rho_cr*env.V_cr^2;

    env.sTOG = p.s_TO_ft/1.66;                                 % Raymer TOP form, as before
    a = 0.009; b = 4.9;
    env.TOP = (-b + sqrt(b^2 + 4*a*env.sTOG))/(2*a);

    % ---------------- landing limit on W/S (FIX 1, FIX 2)
    switch lower(p.landing_model)
        case 'blown'
            Vs = p.Vs_max_kt*1.68781;                           % ft/s
            WS_land_LW = 0.5*env.rho*Vs^2*p.CLmax_ld;           % W/S at landing weight
        case 'raymer'
            s_ground = p.s_LD_ft - p.Sa_ft;                     % Raymer: s = 80 W/S/(sigma CL) + S_a
            if s_ground <= 0
                warning('Raymer landing: S_a >= 300 ft, no conventional solution');
                s_ground = NaN;
            end
            WS_land_LW = (s_ground/80)*(env.rho/env.rho_sl)*p.CLmax_ld;
        otherwise
            error('p.landing_model must be ''blown'' or ''raymer''');
    end
    env.WS_land = WS_land_LW/p.Wland_W0;                       % referred to take-off weight

    names = {'Takeoff','Cruise','Ceiling','Takeoff Climb','Critical Loss of Thrust', ...
             'Balked Landing Climb','Maneuver'};
    nC = numel(names); nS = numel(S_sweep);
    P = nan(nS,nC); Wc = nan(nS,nC);

    P_prev = 1500*ones(1,nC);
    for i = 1:nS
        S = S_sweep(i);
        for k = 1:nC
            Pk = P_prev(k); ok = false; W = W0;
            for it = 1:100
                [W, ~] = weightIterationEstimate_corrected(Pk, W, S, W_S_point, p.prop_efficiency, p);
                if ~isfinite(W), break, end
                pw = pw_all(W, S, p, env);
                P_new = pw(k)*W;
                if abs(P_new - Pk)/abs(P_new) < 1e-4
                    Pk = P_new; ok = true; break
                end
                Pk = Pk + 0.5*(P_new - Pk);
            end
            if ok
                P(i,k) = Pk; Wc(i,k) = W; P_prev(k) = Pk;
            else
                P_prev(k) = 1500;
            end
        end
    end

    % ---------------- landing line as minimum wing area
    [Penv, kmax] = max(P,[],2);
    W0env = Wc(sub2ind(size(Wc),(1:nS)',kmax));
    WS_of_S = W0env./S_sweep;
    m = isfinite(WS_of_S);
    S_land = NaN;
    if nnz(m) >= 2 && isfinite(env.WS_land)
        S_land = interp1(WS_of_S(m), S_sweep(m), env.WS_land, 'linear', 'extrap');
    end

    % ---------------- design point: lightest feasible point (FIX 7)
    feas = isfinite(Penv) & S_sweep >= S_land;
    if any(feas)
        idx = find(feas);
        [~, j] = min(W0env(idx));
        S_design = S_sweep(idx(j)); P_design = Penv(idx(j));
        [~, k_drive] = max(P(idx(j),:));
    else
        S_design = NaN; P_design = NaN; k_drive = NaN;
    end
    S_point = S_design*p.design_margin;
    P_point = P_design*p.design_margin;

    out = struct('S',S_sweep,'P',P,'W0',Wc,'names',{names},'S_land',S_land, ...
        'WS_land',env.WS_land,'P_env',Penv,'P_point',P_point,'S_point',S_point, ...
        'W0_point',W0env(S_sweep==S_design),'driver',{names(k_drive(isfinite(k_drive)))}, ...
        'rho_field',env.rho,'rho_cr',env.rho_cr);

    fprintf('Landing limit: W/S <= %.1f lb/ft^2 (%.0f N/m^2) -> minimum S = %.0f ft^2\n', ...
        env.WS_land, env.WS_land*47.880, S_land);
    if isfinite(S_design)
        fprintf('Design point: S = %.0f ft^2 (%.1f m^2), P = %.0f hp, W0 = %.0f lb, set by %s\n', ...
            S_point, S_point*0.092903, P_point, out.W0_point, names{k_drive});
    end

    if p.make_plot, plot_ps(S_sweep, P, Penv, names, S_land, S_point, P_point, W0, W_S_point, p); end
end

% ======================================================================
function pw = pw_all(W0, S, p, env)
% Required P/W (hp/lb) for each constraint at a given W0 (lb) and S (ft^2)
eta = p.prop_efficiency;
WS  = W0/S;
Swet = wetted_area_corrected(W0, S, p);                                      % FIX 9
CD0  = p.Cf_clean*Swet/S;
k_clean = 1/(pi*0.825*p.AR);
k_to    = 1/(pi*0.725*p.AR);
k_land  = 1/(pi*0.725*p.AR);

LD_to   = p.CLmax_to/((CD0 + .065 + .02) + k_to*p.CLmax_to^2);
LD_land = p.CLmax_ld/((CD0 + .065 + .02) + k_land*p.CLmax_ld^2);

pw = zeros(1,7);
pw(1) = WS/(env.TOP*(env.rho/env.rho_sl)*p.CLmax_to);                      % takeoff

WS_cr = WS*p.Wcr_W0;                                                        % cruise
pw(2) = (env.V_cr/(550*eta))*(env.q_cr/WS_cr*CD0 + WS_cr/env.q_cr*k_clean)*(p.Wcr_W0/p.Pcr_P0);

Pce_P0 = (env.rho_ce/env.rho_sl)^0.8;                                       % ceiling
pw(3) = (350/(550*eta))*(0.001 + 2*sqrt(CD0*k_clean))*(p.Wce_W0/Pce_P0);

pw(4) = climb_pw(0.04, p.CLmax_to, 1.2, eta, p.Wclimb_W0, env.rho, env.rho_sl, LD_to, WS);
pw(5) = p.Neng/(p.Neng-1)* ...                                              % FIX 5
    climb_pw(0.01, p.CLmax_to, 1.2, eta, p.Wclimb_W0, env.rho_400, env.rho_sl, LD_to, WS);
pw(6) = climb_pw(0.03, p.CLmax_ld, 1.3, eta, p.Wland_W0, env.rho, env.rho_sl, LD_land, WS);

n = 1/cos(deg2rad(p.bank_deg));                                             % maneuver
pw(7) = (env.V_cr/(550*eta))*(env.q_cr*CD0/WS + WS*n^2*k_clean/env.q_cr)*(p.Wcr_W0/p.Pcr_P0);
end

function pw = climb_pw(G, CLmax, ks, eta, Wfrac, rho_c, rho_sl, LD, WS)
    CL = CLmax/ks^2;
    pw = (Wfrac^(2/3))*sqrt(WS)*(G + 1/LD)/(18.97*eta*(rho_c/rho_sl)*sqrt(CL));
end

% ======================================================================
function rho = isa_rho_slug(h_ft, dT_K)
% ISA density (troposphere) with temperature offset; returns slug/ft^3
    h = h_ft*0.3048;
    T = 288.15 - 0.0065*h;
    pr = 101325*(T/288.15)^5.25588;
    rho = pr/(287.053*(T + dT_K))/515.379;
end

function p = defaults(p)
    d = struct('AR',11,'Cf_clean',0.0045,'CLmax_to',10,'CLmax_ld',[], ...
        'prop_efficiency',0.8,'Pcr_P0',0.8,'Neng',10,'alt_cr',12500,'design_margin',1.025, ...
        'h_field_ft',1000,'dT_field_K',10,'h_ceiling_ft',14000,'V_cr_kt',225, ...
        's_TO_ft',300,'s_LD_ft',300,'landing_model','blown','Vs_max_kt',27.3,'Sa_ft',450, ...
        'bank_deg',60,'make_plot',true,'N_motors',10,'P_motor_kW',140);
    f = fieldnames(d);
    for i = 1:numel(f)
        if ~isfield(p,f{i}) || isempty(p.(f{i})), p.(f{i}) = d.(f{i}); end
    end
    if isempty(p.CLmax_ld), p.CLmax_ld = p.CLmax_to; end
end

% ======================================================================
function plot_ps(S_sweep, P, Penv, names, S_land, S_point, P_point, W0, W_S_point, p)
    figure(); hold on;
    nC = numel(names); h = gobjects(1,nC);
    for k = 1:nC
        h(k) = plot(S_sweep, P(:,k), 'LineWidth', 1.5, 'DisplayName', names{k});
    end
    ytop = 1.3*max(Penv,[],'omitnan');
    if isfinite(S_land)
        hl = xline(S_land,'LineWidth',1.5,'Color','k','DisplayName','Landing (min S)');
        f = isfinite(Penv) & S_sweep >= S_land;
        if nnz(f) >= 2
            xs = S_sweep(f); ys = Penv(f);
            fill([xs; flipud(xs)], [ytop*ones(size(xs)); flipud(ys)], [0.6 0.85 0.6], ...
                'FaceAlpha',0.35,'EdgeColor','none','HandleVisibility','off');
        end
    else
        hl = plot(nan,nan,'DisplayName','Landing (n/a)');
    end
    P_rated_hp = p.N_motors*p.P_motor_kW*1.34102;
    hr = yline(P_rated_hp,'k--','LineWidth',1.5,'DisplayName', ...
        sprintf('Installed rated (%d x %.0f kW = %.0f hp)', p.N_motors, p.P_motor_kW, P_rated_hp));
    hp_ = plot(S_point, P_point, 'kp','MarkerSize',14,'MarkerFaceColor','y', ...
        'DisplayName', sprintf('Design point, min W0 (S=%.0f ft^2, P=%.0f hp)', S_point, P_point));
    xlim([S_sweep(1) S_sweep(end)]); ylim([0 max(3000, ytop)]);
    xlabel('Wing Area, S (ft^2)'); ylabel('Power, P (hp)'); title('P vs S (corrected)');
    legend([h, hl, hr, hp_], 'Location','northeastoutside'); hold off;
end
