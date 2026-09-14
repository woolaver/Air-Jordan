function plot_regression (csv_file)

        % function takes in a csv file with x-data in the first column
        % and y-data in the second column. The function then plots the 
        % data and fits an appropriate linear regression line to the data.

        % Read in CSV-File - files are in format of x-data column and
        % y-data column
        data = readtable(csv_file);
        
        % Extract data from csv file
        x = data{:,1};
        y = data{:, 2};

        % Plot the raw data from the csvfile
        figure();
        markers = {'o','s','^','v','d','p','h'};
        hold on;
        for i = 1:length(x)
            scatter(x(i), y(i), 60, markers{i}, 'filled');
            hold on;
        end

        % Label the Plot
        xlabel(data.Properties.VariableNames{1}, 'Interpreter', 'none');
        ylabel(data.Properties.VariableNames{2}, 'Interpreter', 'none');
       
        % get linear regression from data
        xmean = mean(x);
        ymean = mean(y);
        S_xx = (x - xmean)' * (x - xmean);
        S_xy = (x - xmean)' * (y - ymean);
        a = S_xy ./ S_xx;
        b = ymean - a .* xmean;
        N = length(x) * 100;
        xvals = linspace(min(x), max(x), N);
        yvals = a .* xvals + b;

        % Calculate R-squared
        yfit = a .* x + b;
        SS_res = sum((y - yfit).^2);
        SS_tot = sum((y - ymean).^2);
        R2 = 1 - SS_res / SS_tot;

        % Add linear fit to the plot
        hold on;
        grid on;
        plot(xvals, yvals, 'k', 'LineWidth', 2);

        % display equation fit-line and R-squared value
        hold on;
        eqn = sprintf('y = %.3fx + %.3f\nR^2 = %.4f', a, b, R2);
        text(0.05, 0.95, eqn, 'Units', 'normalized', 'VerticalAlignment', 'top', 'FontSize', 10);

end

