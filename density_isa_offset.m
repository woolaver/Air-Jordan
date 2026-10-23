function rho = density_isa_offset(h_ft, dT_K)
% Air density [slug/ft^3] at altitude h_ft [ft] on an ISA+dT_K day.
[T, ~, P] = atmoscoesa(h_ft*0.3048);        % [K], [Pa]
rho = P./(287.053*(T + dT_K))/515.4;        % kg/m^3 -> slug/ft^3
end