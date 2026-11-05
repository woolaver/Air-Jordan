% profit graph
clear; clc;

c_init     = 7.27e6;      % baseline unit cost ($)
fixed_cost = c_init;      % up-front cost subtracted from profit (as in your original)
margin     = 0.15;        % 15% margin on selling price
tau        = 10;          % cost-reduction constant (units/month) -- tune this

num_prod_month = 4:1:10;  % production rate (units/month)
num_production = 1:1:200; % cumulative units sold

price = c_init / (1 - margin);   % selling price fixed from baseline cost

figure(); hold on; grid on;
colors = parula(length(num_prod_month));

for i = 1:length(num_prod_month)
    rate = num_prod_month(i);

    % higher monthly rate -> lower unit cost
    reduction_factor = exp(-(rate - num_prod_month(1)) / tau);
    c_unit = c_init * reduction_factor;

    % vectorized profit over all production quantities
    profit = (price - c_unit) * num_production - fixed_cost;

    plot(num_production, profit, 'LineWidth', 1.5, 'Color', colors(i,:), ...
        'DisplayName', sprintf('%d units/month', rate));
end

xlabel('Number of Production Units');
ylabel('Profit ($, USD 2035)');
title('Profit Based on Monthly Unit Production');
legend('Location', 'northwest');