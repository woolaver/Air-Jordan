% profit graph (learning-curve version)
clear; clc;
 close all;
c_init     = 7.27e6;   % baseline
S          = 0.9;         % learning curve
margin     = 0.15;        % 15% margin on selling price
N_max      = 200;         % total production run
rates      = 4:1:10;      % units per month

b = log(S)/log(2);                 % learning exponent
n = 1:N_max;
unit_cost = c_init * n.^b;            % cost of the nth unit
cum_cost  = cumsum(unit_cost);     % total cost of first n units

price = mean(unit_cost) / (1 - margin);

figure(); hold on;
colors = parula(length(rates));

for i = 1:length(rates)
    rate   = rates(i);
    months = 1:ceil(N_max/rate);
    units  = min(rate*months, N_max);      % cumulative units by each month

    profit = (price*units - cum_cost(units) - c_init) / 10^6;

    plot(months, profit, 'LineWidth', 1.5, 'Color', colors(i,:), ...
        'DisplayName', sprintf('%d units/month', rate));
end

xlabel('Months of Production');
ylabel('Profit ($M, USD 2035)');
title('Profit Based on Monthly Unit Production');
legend('Location', 'northwest');
yline(0, 'k', 'LineWidth', 2, 'DisplayName', sprintf('Break Even'));
grid on;