function t = tailSizing(S, AR, taper, x_wing_c4, x_ht_c4, x_vt_c4, opt)
% Tail sizing by volume coefficients (replaces "Sh = 0.4*S" in BlownWingAnalysis.m and
% the hand-sized tails in STOL481.avl). Units: ft, ft^2.
%
%   S, AR, taper   wing reference area, aspect ratio, taper ratio
%   x_wing_c4      x of the wing MAC quarter chord
%   x_ht_c4        x of the horizontal-tail MAC quarter chord
%   x_vt_c4        x of the vertical-tail MAC quarter chord
%   opt (optional) .cHT (0.90), .cVT (0.06), .T_tail (true -> 5 % reduction of both,
%                  end-plate effect), .AR_h (4.5), .taper_h (0.5), .AR_v (1.2), .taper_v (0.8)
%
% Why the old tails were large (STOL481.avl, Oct 15):
%   HT 320 ft^2 and VT 325 ft^2 (both ~30 % of S). Their volume coefficients are normal
%   (V_H = 0.95, V_V = 0.066); the tails are large because the WING is 1,058 ft^2.
%   Tail area scales with S*c (HT) and S*b (VT): fix the wing area first.
% Volume-coefficient guidance (VERIFY against Raymer Table 6.4): twin turboprop
%   c_HT ~ 0.9, c_VT ~ 0.08; with DEP (yaw by differential thrust, 2 motors per prop) the
%   one-engine-out case no longer sizes the fin, c_VT ~ 0.045-0.06 is sufficient if
%   C_n_beta >= 0.057 /rad is shown (our sizing tool: 0.0585 /rad at c_VT = 0.045).
% The final HT size must be checked for trim on the BLOWN approach (nose-down moment of the
% blown flap) with the REAL CG range, not with the CG at 25 % MAC (AVL Xref placeholder).

    if nargin < 7, opt = struct(); end
    d = struct('cHT',0.90,'cVT',0.06,'T_tail',true,'AR_h',4.5,'taper_h',0.5,'AR_v',1.2,'taper_v',0.8);
    f = fieldnames(d);
    for i = 1:numel(f), if ~isfield(opt,f{i}), opt.(f{i}) = d.(f{i}); end, end
    k = 1; if opt.T_tail, k = 0.95; end

    b = sqrt(AR*S);
    cr = 2*S/(b*(1 + taper));
    mac = 2/3*cr*(1 + taper + taper^2)/(1 + taper);
    l_h = x_ht_c4 - x_wing_c4;
    l_v = x_vt_c4 - x_wing_c4;

    t.S_ht = k*opt.cHT*mac*S/l_h;
    t.S_vt = k*opt.cVT*b*S/l_v;
    t.b_ht = sqrt(opt.AR_h*t.S_ht);
    t.cr_ht = 2*t.S_ht/(t.b_ht*(1 + opt.taper_h));  t.ct_ht = opt.taper_h*t.cr_ht;
    t.h_vt = sqrt(opt.AR_v*t.S_vt);
    t.cr_vt = 2*t.S_vt/(t.h_vt*(1 + opt.taper_v));  t.ct_vt = opt.taper_v*t.cr_vt;
    t.l_h = l_h; t.l_v = l_v; t.mac = mac; t.b = b;
    t.Sh_S = t.S_ht/S; t.Sv_S = t.S_vt/S;

    fprintf('Wing S %.0f ft^2, b %.1f ft, MAC %.2f ft | arms l_h %.1f ft, l_v %.1f ft\n', S, b, mac, l_h, l_v);
    fprintf('HT %.0f ft^2 (%.1f m^2, %.0f %% of S): span %.1f ft, root/tip %.2f/%.2f ft\n', ...
        t.S_ht, t.S_ht*0.092903, 100*t.Sh_S, t.b_ht, t.cr_ht, t.ct_ht);
    fprintf('VT %.0f ft^2 (%.1f m^2, %.0f %% of S): height %.1f ft, root/tip %.2f/%.2f ft\n', ...
        t.S_vt, t.S_vt*0.092903, 100*t.Sv_S, t.h_vt, t.cr_vt, t.ct_vt);
end
