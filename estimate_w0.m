function out = estimate_w0(p)
% using Raymer and Roskam

% Input p
% Output: W0, WE, WF, mass_battery, mass_total_kg, etc.

g = p.g;
 
% payload 
baggage_weight = g * p.baggage_mass * p.num_passengers;
passenger_weight = g * p.num_passengers * p.passenger_mass;
W_payload = baggage_weight + passenger_weight;       

% electric motors:
electric_motor_weight = g * p.num_motors * p.motor_mass_each;

% fuel fraction forfuel-burning cruise (Breguet range):
if p.R_fuel > 0
    W5_W4 = 1 / exp(p.R_fuel / (325.9 * (p.prop_efficiency / p.cp) * p.L_D));
else
    W5_W4 = 1; % no fuel-burning leg (e.g. fully electric aircraft)
end
 
if isfield(p, 'R_reserve') && p.R_reserve > 0
    W7_W6 = 1 / exp(p.R_reserve / (325.9 * (p.prop_efficiency / p.cp) * p.L_D));
else
    W7_W6 = 1;
end
 
w0 = p.W0_guess;
delta = 1;
mass_battery = 0; % init in case R_electric = 0

while delta > p.tol
    WE_W0 = p.A * w0^p.C + electric_motor_weight / w0;
 
    WF_W0 = 1 - (p.W9_W8 * p.W8_W7 * W7_W6 * p.W6_W5 * W5_W4 * ...
                 p.W4_W3 * p.W3_W2 * p.W2_W1 * p.W1_W0);
 
    m_cruise = W5_W4 * p.W4_W3 * p.W3_W2 * p.W2_W1 * p.W1_W0 * w0 / g; % kg
 
    if p.R_electric > 0
        mass_battery = (p.R_electric * g * m_cruise) / ...
                        (p.batt_efficiency * p.eb_star * p.L_D); % kg
    else
        mass_battery = 0;
    end
 
    W0_new = (W_payload + mass_battery * g) / (1 - WF_W0 - WE_W0);
    delta = abs(W0_new - w0) / W0_new;
    w0 = W0_new;
end

out.W0_N            = w0;
out.W0_kg           = w0 / g;
out.WE_W0           = WE_W0;
out.WE_kg           = WE_W0 * w0 / g;
out.WF_W0           = WF_W0;
out.WF_kg           = WF_W0 * w0 / g;
out.mass_battery_kg = mass_battery;
out.electric_prop_system_kg = mass_battery + electric_motor_weight / g;
out.W_payload_kg    = W_payload / g;
 
end