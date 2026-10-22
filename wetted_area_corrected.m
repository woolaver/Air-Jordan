function Swet = wetted_area_corrected(W0, S, p)
% Total wetted area [ft^2] that grows with wing (and tail) area.
% FIX D: the Roskam regression Swet = 10^(-0.0866 + 0.8099 log10 W0) depends on W0 only,
% so CD0 = Cf*Swet/S made the parasite drag FORCE independent of wing area: a 3x bigger
% wing cost no drag. Here the regression value is kept for a reference wing at
% p.WS_ref and corrected for the actual wing and tail areas.
% Use the same function inside fuel_fraction_calc.m (cruise L/D) and in pw_all.
%   Wing:  Swet = (1.977 + 0.52 t/c) * S_exposed   (t/c 0.15 -> 2.055; Raymer Ch. 12, VERIFY)
%   Tails: same with t/c 0.12 -> 2.04
    if nargin < 3, p = struct(); end
    d = struct('AR',11,'WS_ref',26,'f_exposed',0.90,'cHT',0.90,'cVT',0.06,'l_ht',30.8,'l_vt',23.3);
    f = fieldnames(d);
    for i = 1:numel(f), if ~isfield(p,f{i}), p.(f{i}) = d.(f{i}); end, end
    S_ref = W0/p.WS_ref;
    Swet  = 10^(-0.0866 + 0.8099*log10(W0)) ...
          + 2.055*p.f_exposed*(S - S_ref) + 2.04*(tails(S,p) - tails(S_ref,p));
end

function St = tails(S, p)
    b = sqrt(p.AR*S); c = S/b;
    St = p.cHT*c*S/p.l_ht + p.cVT*b*S/p.l_vt;
end
