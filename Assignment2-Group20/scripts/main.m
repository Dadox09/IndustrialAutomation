% MAIN  Entry point for the Sustainable Offshore Wind Installation Assignment.

clear; clc; close all;

fprintf('>>> FASE 1: Inizializzazione Database\n');
setup_database();

fprintf('\n>>> FASE 2: Risoluzione Esatta\n');
[seq_milp, cost_milp, brk_milp] = solve_milp();

[seq_dp, cost_dp, brk_dp] = solve_dp();

fprintf('\n>>> FASE 3: Risoluzione Greedy (Nearest Neighbor)\n');
[seq_nn, cost_nn, brk_nn] = nearest_neighbor();

fprintf('\n>>> FASE 4: Costruzione Report e Confronto CO2\n');
sustainability_report(brk_milp, brk_nn, cost_milp, cost_nn);

