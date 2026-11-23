%parametric inputs
ac.name         = 'Hybrid-Electric STOL Commuter';
ac.W_MTOW       = 15764;
ac.W_min        = 13051;
ac.S            = 505.2576;
ac.cbar         = 7.4926;
ac.h_cruise     = 35000;
ac.CL_max_clean = 1.3226;
ac.CL_min_clean = -1.00;
ac.CL_max_flap  = 8.6971;
ac.CL_alpha     = 5.15;
ac.VC_input     = [];
ac.VD_input     = [];
ac.VF_input     = 95;

%output saving
export_pdf      = true;
group_prefix    = '04';

%mtow and min weight cases
cases = {'MTOW', 'Minimum Weight'};
weights = [ac.W_MTOW, ac.W_min];
results = struct();

for i = 1:length(weights)
    results(i).label = cases{i};
    results(i).W     = weights(i);
    results(i).data  = compute_Vn_case(weights(i), ac);
    print_summary(results(i).label, results(i).data);
end

%plotting
fig = figure('Units', 'inches', 'Position', [1, 1, 13, 5.8], 'Color', 'w');
tiledlayout(1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

for i = 1:2
    nexttile;
    plot_Vn_envelope(results(i).data, sprintf('%s (W = %d lbs)', results(i).label, results(i).W));
end

if export_pdf
    filename = sprintf('%s-Vn-Diagrams.pdf', group_prefix);
    exportgraphics(fig, filename, 'ContentType', 'vector');
    fprintf('\nExported vector graphic: %s\n', filename);
end

%functions for computing and plotting
function d = compute_Vn_case(W, ac)
    rho_SL = 0.0023769;
    g = 32.174;
    kts2fps = 1.68781;
    T_ratio = 1 - 6.87535e-6 * ac.h_cruise;
    rho_cr  = rho_SL * (T_ratio^4.2561);
    
    d.W  = W;
    d.WS = W / ac.S;
    
    %FAR23 maneuver load factors
    n_pos_raw = 2.1 + 24000 / (W + 10000);
    d.n_pos = min(n_pos_raw, 3.8);
    d.n_neg = -0.4 * d.n_pos;
    d.n_flap = 2.0;
    
    %design airspeeds (KEAS)
    d.VS1 = sqrt((2 * d.WS) / (rho_SL * ac.CL_max_clean)) / kts2fps;
    d.VS0 = sqrt((2 * d.WS) / (rho_SL * ac.CL_max_flap))  / kts2fps;
    d.VS_neg = sqrt((2 * d.WS) / (rho_SL * abs(ac.CL_min_clean))) / kts2fps;
    
    %min cruise design speed
    if d.WS <= 20
        k_vc = 33.0;
    else
        k_vc = 33.0 - (33.0 - 28.6) * ((d.WS - 20) / (100 - 20));
    end
    d.VC_min = k_vc * sqrt(d.WS);
    
    if isempty(ac.VC_input)
        d.VC = d.VC_min;
    else
        d.VC = max(ac.VC_input, d.VC_min);
    end
    
    %design dive speed
    d.VD_min = 1.40 * d.VC_min;
    if isempty(ac.VD_input)
        d.VD = max(d.VD_min, 1.25 * d.VC);
    else
        d.VD = max(ac.VD_input, d.VD_min);
    end
    
    %manueviering speed
    d.VA = min(d.VS1 * sqrt(d.n_pos), d.VC);
    
    %flaps out speed
    d.VF = ac.VF_input;
    
    %Pratt Gust Formula
    mu_SL = (2 * d.WS) / (rho_SL * ac.cbar * ac.CL_alpha * g);
    Kg_SL = (0.88 * mu_SL) / (5.3 + mu_SL);
    mu_cr = (2 * d.WS) / (rho_cr * ac.cbar * ac.CL_alpha * g);
    Kg_cr = (0.88 * mu_cr) / (5.3 + mu_cr);
    if ac.h_cruise <= 20000
        d.Kg = Kg_cr;
        d.gust_alt_note = sprintf('Cruise Alt (%d ft)', ac.h_cruise);
    else
        d.Kg = Kg_SL;
        d.gust_alt_note = 'Sea Level';
    end
    
    %gust speeds
    Ue_VB = 66.0;
    Ue_VC = 50.0;
    Ue_VD = 25.0;
    Ue_VF = 25.0;
    
    %gust slope
    gust_slope = @(Ue) (d.Kg * ac.CL_alpha * Ue) / (498 * d.WS);
    d.slope_VB = gust_slope(Ue_VB);
    d.slope_VC = gust_slope(Ue_VC);
    d.slope_VD = gust_slope(Ue_VD);
    d.slope_VF = gust_slope(Ue_VF);
    a_quad = (rho_SL * (kts2fps^2) * ac.CL_max_clean) / (2 * d.WS);
    b_quad = -d.slope_VB;
    c_quad = -1.0;
    VB_intersect = (-b_quad + sqrt(b_quad^2 - 4*a_quad*c_quad)) / (2*a_quad);
    d.VB = min(VB_intersect, d.VC);
    
    %gust load factors
    d.n_gust_VB_pos = 1 + d.slope_VB * d.VB;
    d.n_gust_VB_neg = 1 - d.slope_VB * d.VB;
    d.n_gust_VC_pos = 1 + d.slope_VC * d.VC;
    d.n_gust_VC_neg = 1 - d.slope_VC * d.VC;
    d.n_gust_VD_pos = 1 + d.slope_VD * d.VD;
    d.n_gust_VD_neg = 1 - d.slope_VD * d.VD;
    d.n_limit_pos = max([d.n_pos, d.n_gust_VB_pos, d.n_gust_VC_pos, d.n_gust_VD_pos]);
    d.n_limit_neg = min([d.n_neg, d.n_gust_VB_neg, d.n_gust_VC_neg, d.n_gust_VD_neg]);    
    d.n_ult_pos = 1.5 * d.n_limit_pos;
    d.n_ult_neg = 1.5 * d.n_limit_neg;    
    V_grid = linspace(0, d.VD, 500);
    d.V_grid = V_grid;
    q_SL = 0.5 * rho_SL * (V_grid * kts2fps).^2;
    d.n_stall_pos  = (q_SL * ac.CL_max_clean) / d.WS;
    d.n_stall_neg  = (q_SL * ac.CL_min_clean) / d.WS;
    d.n_stall_flap = (q_SL * ac.CL_max_flap)  / d.WS;
    d.n_man_pos = min(d.n_stall_pos, d.n_pos);
    d.n_man_neg = max(d.n_stall_neg, d.n_neg);
    idx_ramp = V_grid >= d.VC;
    d.n_man_neg(idx_ramp) = d.n_neg * (1 - (V_grid(idx_ramp) - d.VC) / (d.VD - d.VC));
    n_gust_upper_raw = interp1([0, d.VB, d.VC, d.VD], ...
                               [1, d.n_gust_VB_pos, d.n_gust_VC_pos, d.n_gust_VD_pos], ...
                               V_grid, 'linear');
    n_gust_lower_raw = interp1([0, d.VB, d.VC, d.VD], ...
                               [1, d.n_gust_VB_neg, d.n_gust_VC_neg, d.n_gust_VD_neg], ...
                               V_grid, 'linear');                    
    d.n_gust_pos_env = min(d.n_stall_pos, n_gust_upper_raw);
    d.n_gust_neg_env = max(d.n_stall_neg, n_gust_lower_raw);
    d.n_comb_pos = max(d.n_man_pos, d.n_gust_pos_env);
    d.n_comb_neg = min(d.n_man_neg, d.n_gust_neg_env);
end

function plot_Vn_envelope(d, title_str)
    hold on; 
    grid on; 
    box on;
    idx_flight = d.V_grid >= d.VS1;
    V_fill = [d.V_grid(idx_flight), fliplr(d.V_grid(idx_flight))];
    n_fill = [d.n_comb_pos(idx_flight), fliplr(d.n_comb_neg(idx_flight))];
    fill(V_fill, n_fill, [0.85 0.93 0.98], 'EdgeColor', 'none', 'FaceAlpha', 0.65, ...
         'DisplayName', 'Combined Limit Envelope');
    yline(d.n_ult_pos, '--r', 'LineWidth', 1.2, 'DisplayName', sprintf('Ultimate Load (+%.2fg / %.2fg)', d.n_ult_pos, d.n_ult_neg));
    yline(d.n_ult_neg, '--r', 'LineWidth', 1.2, 'HandleVisibility', 'off');
    plot([0, d.VB], [1, d.n_gust_VB_pos], ':k', 'LineWidth', 1.0, 'DisplayName', 'Gust Lines (\pm66, \pm50, \pm25 ft/s)');
    plot([0, d.VB], [1, d.n_gust_VB_neg], ':k', 'LineWidth', 1.0, 'HandleVisibility', 'off');
    plot([0, d.VC], [1, d.n_gust_VC_pos], ':k', 'LineWidth', 1.0, 'HandleVisibility', 'off');
    plot([0, d.VC], [1, d.n_gust_VC_neg], ':k', 'LineWidth', 1.0, 'HandleVisibility', 'off');
    plot([0, d.VD], [1, d.n_gust_VD_pos], ':k', 'LineWidth', 1.0, 'HandleVisibility', 'off');
    plot([0, d.VD], [1, d.n_gust_VD_neg], ':k', 'LineWidth', 1.0, 'HandleVisibility', 'off');
    idx_flap = d.V_grid <= d.VF;
    V_f = d.V_grid(idx_flap);
    n_f_top = min(d.n_stall_flap(idx_flap), d.n_flap);
    plot(V_f, n_f_top, '-.', 'Color', [0.1 0.6 0.2], 'LineWidth', 1.4, 'DisplayName', 'Flaps Extended (§23.345)');
    plot([d.VF, d.VF], [0, n_f_top(end)], '-.', 'Color', [0.1 0.6 0.2], 'LineWidth', 1.4, 'HandleVisibility', 'off');
    plot(d.V_grid, d.n_man_pos, '--b', 'LineWidth', 1.4, 'DisplayName', 'Maneuver Limit');
    plot(d.V_grid, d.n_man_neg, '--b', 'LineWidth', 1.4, 'HandleVisibility', 'off');
    plot([d.VD, d.VD], [0, d.n_pos], '--b', 'LineWidth', 1.4, 'HandleVisibility', 'off');
    plot(d.V_grid, d.n_comb_pos, 'k-', 'LineWidth', 2.0, 'DisplayName', 'Combined Limit Boundary');
    plot(d.V_grid, d.n_comb_neg, 'k-', 'LineWidth', 2.0, 'HandleVisibility', 'off');
    plot([d.VD, d.VD], [d.n_comb_neg(end), d.n_comb_pos(end)], 'k-', 'LineWidth', 2.0, 'HandleVisibility', 'off');
    yline(0, 'k-', 'LineWidth', 0.6, 'HandleVisibility', 'off');
    plot(d.VS1, 1.0, 'ko', 'MarkerFaceColor', 'w', 'HandleVisibility', 'off');
    text(d.VS1 + 3, 1.0, sprintf('V_{S1}=%.1f', d.VS1), 'FontSize', 8, 'VerticalAlignment', 'top');
    plot(d.VA, d.n_pos, 'bo', 'MarkerFaceColor', 'b', 'HandleVisibility', 'off');
    text(d.VA - 4, d.n_pos + 0.22, sprintf('PHAA (V_A=%.1f, n=%.2f)', d.VA, d.n_pos), 'FontSize', 8, 'HorizontalAlignment', 'right');
    plot(d.VB, d.n_gust_VB_pos, 'rd', 'MarkerFaceColor', 'r', 'MarkerSize', 6, 'HandleVisibility', 'off');
    text(d.VB, d.n_gust_VB_pos + 0.28, sprintf('V_B Gust (V_B=%.1f, n=%.2f)', d.VB, d.n_gust_VB_pos), ...
         'FontSize', 8, 'FontWeight', 'bold', 'Color', [0.75 0 0], 'HorizontalAlignment', 'center');
    plot(d.VC, d.n_gust_VC_pos, 'ks', 'MarkerFaceColor', 'y', 'HandleVisibility', 'off');
    text(d.VC + 4, d.n_gust_VC_pos + 0.12, sprintf('V_C Gust (n=%.2f)', d.n_gust_VC_pos), 'FontSize', 8, 'HorizontalAlignment', 'left');
    plot(d.VC, d.n_gust_VC_pos, 'ks', 'MarkerFaceColor', 'y', 'HandleVisibility', 'off');
    plot(d.VD, d.n_comb_pos(end), 'bo', 'MarkerFaceColor', 'b', 'HandleVisibility', 'off');
    text(d.VD - 3, d.n_comb_pos(end) - 0.25, sprintf('PLAA (V_D=%.1f)', d.VD), 'FontSize', 8, 'HorizontalAlignment', 'right');
    plot(d.VC, d.n_comb_neg(find(d.V_grid >= d.VC, 1)), 'bo', 'MarkerFaceColor', 'b', 'HandleVisibility', 'off');
    text(d.VC, d.n_comb_neg(find(d.V_grid >= d.VC, 1)) - 0.3, sprintf('NLAA (n=%.2f)', d.n_comb_neg(find(d.V_grid >= d.VC, 1))), 'FontSize', 8, 'HorizontalAlignment', 'center');
    xlabel('Equivalent Airspeed, V_{EAS} [KEAS]', 'FontWeight', 'bold');
    ylabel('Load Factor, n [g]', 'FontWeight', 'bold');
    title(title_str, 'FontSize', 11, 'FontWeight', 'bold');
    xlim([0, d.VD * 1.12]);
    ylim([d.n_ult_neg * 1.2, d.n_ult_pos * 1.15]);
    legend('Location', 'northwest', 'FontSize', 7.5);
end

function print_summary(label, d)
    fprintf('============================================================\n');
    fprintf(' SUMMARY: %s (W = %.0f lbs, W/S = %.2f lb/ft^2)\n', label, d.W, d.WS);
    fprintf('============================================================\n');
    fprintf(' Design Speeds [KEAS]:\n');
    fprintf('   VS0 (Flaps) = %6.1f | VS1 (Clean) = %6.1f | VA = %6.1f\n', d.VS0, d.VS1, d.VA);
    fprintf('   VB (Gust)   = %6.1f | VC (Cruise) = %6.1f | VD = %6.1f | VF = %6.1f\n', d.VB, d.VC, d.VD, d.VF);
    fprintf(' Maneuver Load Factors (FAR 23.337):\n');
    fprintf('   n_pos = +%5.2f g   | n_neg = %5.2f g\n', d.n_pos, d.n_neg);
    fprintf(' Gust Load Factors (FAR 23.333c @ %s, Kg = %.3f):\n', d.gust_alt_note, d.Kg);
    fprintf('   @ VB (±66 fps): +%5.2f g / %5.2f g\n', d.n_gust_VB_pos, d.n_gust_VB_neg);
    fprintf('   @ VC (±50 fps): +%5.2f g / %5.2f g\n', d.n_gust_VC_pos, d.n_gust_VC_neg);
    fprintf('   @ VD (±25 fps): +%5.2f g / %5.2f g\n', d.n_gust_VD_pos, d.n_gust_VD_neg);
    fprintf(' Critical Design Load Factors (Governing Limit & Ultimate):\n');
    fprintf('   n_limit_pos = +%5.2f g  -->  n_ult_pos = +%5.2f g (Max Lift = %.0f lbs)\n', ...
            d.n_limit_pos, d.n_ult_pos, d.n_limit_pos * d.W);
    fprintf('   n_limit_neg =  %5.2f g  -->  n_ult_neg =  %5.2f g (Max Down = %.0f lbs)\n\n', ...
            d.n_limit_neg, d.n_ult_neg, abs(d.n_limit_neg) * d.W);
end