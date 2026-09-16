clc; clear; close all;

% apply cost adjust formula
function [cost_thenyear] = inflation_adjustment (r, n, cost_baseyear)
   
    cost_thenyear = cost_baseyear(1 + r)^n;
end

% cost estimation factor
function [CEF] = cost_estimation_factor(b_year, t_year)

    bcef = 5.17053 + 0.104981*(b_year - 2006);
    tcef = 5.17053 + 0.104981 * (t_year - 2006);
    CEF = tcef / bcef;
end

% cash operating costs

function [crew_cost] = crew(AF, MTOW, tb, CEF)
%ben likes dick