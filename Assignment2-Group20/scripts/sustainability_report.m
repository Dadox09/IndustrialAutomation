function sustainability_report(breakdown_exact, breakdown_nn, cost_exact, cost_nn)

fprintf('\n======= SUSTAINABILITY REPORT =======\n');

% Calculate total setup vs penalties for both
setup_exact    = breakdown_exact.setupFromPort + breakdown_exact.setupBetween;
penalty_exact  = breakdown_exact.tardiness + breakdown_exact.remobilization;

setup_nn       = breakdown_nn.setupFromPort + breakdown_nn.setupBetween;
penalty_nn     = breakdown_nn.tardiness + breakdown_nn.remobilization;

fuel_saved = setup_nn + penalty_nn - (setup_exact + penalty_exact);

fprintf('Metodo Ottimo (MILP/DP):\n');
fprintf('  Total Setup Cost  : %8.2f Fuel Units\n', setup_exact);
fprintf('  Total Penalty Cost: %8.2f Fuel Units\n', penalty_exact);
fprintf('  TOTAL             : %8.2f Fuel Units\n\n', cost_exact);

fprintf('Metodo Euristico (Nearest Neighbor):\n');
fprintf('  Total Setup Cost  : %8.2f Fuel Units\n', setup_nn);
fprintf('  Total Penalty Cost: %8.2f Fuel Units\n', penalty_nn);
fprintf('  TOTAL             : %8.2f Fuel Units\n\n', cost_nn);

fprintf('=> Risparmio netto ottenuto con algoritmi ottimi: %.2f Fuel Units (CO2 proxy)\n', fuel_saved);

% Bar Chart
% Mettiamo a confronto [Setup, Penalty] per i due approcci.
% Righe: [Setup; Penalty], Colonne: [Nearest Neighbor, Ottimo]
data = [setup_nn, setup_exact; 
        penalty_nn, penalty_exact];

f = figure('Name', 'Sustainability Trade-off: Moving Fast vs Waiting', 'Color', 'w');
b = bar(data', 'stacked');

b(1).FaceColor = [0.2 0.6 0.8]; % Setup Fuel 
b(2).FaceColor = [0.9 0.4 0.4]; % Penalty

ylabel('Fuel (Units / CO2 Equivalent)');
set(gca, 'XTickLabel', {'Nearest Neighbor', 'Optimal (MILP/DP)'});
title('Trade-off between "Moving Fast" and "Waiting"');
legend('Setup Consumption (Fast)', 'Idle DP-Mode Penalty (Waiting)', 'Location', 'northwest');
grid on;

ax = gca;
ax.Toolbar.Visible = 'off';

exportgraphics(f, '../results/sustainability_plot.png', 'Resolution', 300);
fprintf('\nGrafico generato: "sustainability_plot.png"\n');
fprintf('=====================================\n');

end
