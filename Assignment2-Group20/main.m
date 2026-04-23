% MAIN  Entry point for the Sustainable Offshore Wind Installation Assignment.

clear; clc; close all;

%% 1) Creazione Database / Inizializzazione
fprintf('>>> FASE 1: Inizializzazione Database\n');
setup_database();

%% 2) Ricerca della Soluzione Ottima (MILP e DP)
fprintf('\n>>> FASE 2: Risoluzione Esatta\n');
[seq_milp, cost_milp, brk_milp] = solve_milp();

[seq_dp, cost_dp, brk_dp] = solve_dp();

%% 3) Euristica Greedy
fprintf('\n>>> FASE 3: Risoluzione Greedy (Nearest Neighbor)\n');
[seq_nn, cost_nn, brk_nn] = nearest_neighbor();

%% 4) Sustainability Report
fprintf('\n>>> FASE 4: Costruzione Report e Confronto CO2\n');
% Entrambi i metodi risolutori esatti danno la stessa soluzione
% Usiamo la soluzione MILP come baseline per il report comparativo
sustainability_report(brk_milp, brk_nn, cost_milp, cost_nn);

fprintf('\n*** Esecuzione completata con successo! ***\n');
