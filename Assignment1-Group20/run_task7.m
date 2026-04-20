%% =========================================================
%  TASK 7 – Effect of Sampling Time
%  Confronto 3 modelli x 4 valori di Ts
%  Modelli: task3.slx (ZOH), task4.slx (Euler), task6.slx (Lin+Disc)
%% =========================================================

%% --- 1. Carica parametri base (init.m ha clear/clc al suo interno) ---
run('task5_6.m');   % ATTENZIONE: init.m chiama clear, quindi va eseguito PRIMA
                 % di definire le variabili dello script.

close all;

%% --- 2. Configurazione (DOPO init.m perché init ha clear al suo interno) ---
model_files  = {'task3', 'task4', 'task6'};
model_labels = {'ZOH + Nonlin', 'Euler Nonlin', 'Lin + Disc'};
Ts_vec       = [0.05, 0.1, 0.25, 0.5];   % [h]
colors       = lines(4);
linestyles   = {'-', '--', ':', '-.'};

nM = length(model_files);
nT = length(Ts_vec);

%% --- 3. Pre-alloca struttura risultati ---
R = struct();

%% --- 4. Carica i modelli (evita reload ripetuto) ---
for m = 1:nM
    load_system(model_files{m});
end

%% --- 5. Loop simulazioni ---
fprintf('%-20s | %-6s | RMSE_Ta | Tp_fin | Egrid[kWh] | EPV[kWh] | SbOK\n', ...
        'Modello', 'Ts[h]');
fprintf('%s\n', repmat('-',1,75));

for m = 1:nM
    for k = 1:nT

        %% 5a. Aggiorna Ts nel workspace (init.m l'ha già creata)
        Ts = Ts_vec(k);  %#ok<NASGU>
        assignin('base', 'Ts', Ts_vec(k));

        %% 5b. Esegui simulazione
        simOut = sim(model_files{m}, ...
                     'StopTime',        num2str(T_sim), ...
                     'FixedStep',       num2str(Ts_vec(k)), ...
                     'SaveTime',        'on',  ...
                     'SaveOutput',      'on');

        %% 5c. Estrai e sincronizza i segnali su un'unica griglia temporale (t)
        % Simulink può esportare i controlli discreti e gli stati continui con 
        % lunghezze diverse. Interpoliamo tutto sul vettore del tempo di Ta.
        
        % 1) Prendi il tempo master (rimuovendo eventuali duplicati di zero-crossing)
        t_raw = simOut.Ta.Time(:);
        idx_t = [true; diff(t_raw) > 0]; 
        t     = t_raw(idx_t);
        
        d_Ta = simOut.Ta.Data(:); 
        Ta   = d_Ta(idx_t);

        % 2) Allinea Tp
        t_Tp = simOut.Tp.Time(:); idx_Tp = [true; diff(t_Tp) > 0];
        d_Tp = simOut.Tp.Data(:); Tp = interp1(t_Tp(idx_Tp), d_Tp(idx_Tp), t, 'previous', 'extrap');
        
        % 3) Allinea Sb
        t_Sb = simOut.Sb.Time(:); idx_Sb = [true; diff(t_Sb) > 0];
        d_Sb = simOut.Sb.Data(:); Sb = interp1(t_Sb(idx_Sb), d_Sb(idx_Sb), t, 'previous', 'extrap');
        
        % 4) Allinea ur
        t_ur = simOut.ur.Time(:); idx_ur = [true; diff(t_ur) > 0];
        d_ur = simOut.ur.Data(:); ur = interp1(t_ur(idx_ur), d_ur(idx_ur), t, 'previous', 'extrap');
        
        % 5) Allinea uf
        t_uf = simOut.uf.Time(:); idx_uf = [true; diff(t_uf) > 0];
        d_uf = simOut.uf.Data(:); uf = interp1(t_uf(idx_uf), d_uf(idx_uf), t, 'previous', 'extrap');
        
        % 6) Allinea ub
        t_ub = simOut.ub.Time(:); idx_ub = [true; diff(t_ub) > 0];
        d_ub = simOut.ub.Data(:); ub = interp1(t_ub(idx_ub), d_ub(idx_ub), t, 'previous', 'extrap');

        %% 5d. Calcola disturbances sulla stessa griglia temporale "t"
        Te   = 24 + 8 * sin(2*pi/24 * (t - 8));                      % [°C]
        Rs   = Rmax * max(sin(pi*(t - tsr)/(tss - tsr)), 0) ...
                    .* (t >= tsr & t <= tss);
        PPV  = Pmax * Rs / Rmax;                                     % [kW]
        Qp   = 1.2*(t < 4) + 0.6*(t >= 4 & t < 10) + 0.25*(t >= 10); % [kW]

        %% 5e. Bilancio elettrico (ora tutte le variabili sono Nx1!)
        Pload = Pr .* ur + Pf .* uf;                 % [kW]
        Pgrid = Pload - PPV - ub;                    % [kW]
        Pgrid_pos = max(Pgrid, 0);

        %% 5f. Indicatori di sostenibilità
        Egrid   = trapz(t, Pgrid_pos);               % [kWh]
        EPV_use = trapz(t, min(Pload, PPV));         % [kWh]
        PV_frac = EPV_use / max(trapz(t, Pload), 1e-9) * 100; % [%]

        %% 5g. Indicatori di performance
        Ta_ref  = 6*(t < 6) + 5*(t >= 6 & t < 18) + 4*(t >= 18);
        RMSE_Ta = sqrt(mean((Ta - Ta_ref).^2));
        Tp_fin  = Tp(end);
        Sb_ok   = all(Sb >= 0.15 & Sb <= 0.95);

        %% 5h. Salva in struttura
        R(m,k).t        = t;
        R(m,k).Ta       = Ta;
        R(m,k).Tp       = Tp;
        R(m,k).Sb       = Sb;
        R(m,k).ur       = ur;
        R(m,k).uf       = uf;
        R(m,k).ub       = ub;
        R(m,k).Te       = Te;
        R(m,k).PPV      = PPV;
        R(m,k).Pload    = Pload;
        R(m,k).Pgrid    = Pgrid;
        R(m,k).Egrid    = Egrid;
        R(m,k).EPV_use  = EPV_use;
        R(m,k).PV_frac  = PV_frac;
        R(m,k).RMSE_Ta  = RMSE_Ta;
        R(m,k).Tp_fin   = Tp_fin;
        R(m,k).Sb_ok    = Sb_ok;
        R(m,k).Ta_ref   = Ta_ref;
        R(m,k).Ts       = Ts_vec(k);
        R(m,k).label    = model_labels{m};

        %% 5i. Stampa tabella
        fprintf('%-20s | %-6.2f | %7.4f | %6.2f | %10.3f | %8.3f | %s\n', ...
            model_labels{m}, Ts_vec(k), RMSE_Ta, Tp_fin, ...
            Egrid, EPV_use, string(Sb_ok));
    end
end

%% --- 6. Salva workspace ---
save('task7_results.mat', 'R', 'model_labels', 'Ts_vec', 'colors', 'linestyles');
fprintf('\nRisultati salvati in task7_results.mat\n');

%% =========================================================
%  SEZIONE PLOT
%% =========================================================

%% FIGURA 1-3: Per ogni modello, confronto tra Ts diversi
for m = 1:nM
    fig = figure('Name', sprintf('Modello: %s – Effetto Ts', model_labels{m}), ...
                 'Position', [100 100 1200 800]);

    % -- Ta --
    subplot(2,2,1); hold on; grid on;
    for k = 1:nT
        plot(R(m,k).t, R(m,k).Ta, ...
             'Color', colors(k,:), 'LineStyle', linestyles{k}, 'LineWidth', 1.4, ...
             'DisplayName', sprintf('Ts=%.2fh', Ts_vec(k)));
    end
    t_ref = [0 6 6 18 18 24];
    Ta_r  = [6 6  5  5  4  4];
    plot(t_ref, Ta_r, 'k--', 'LineWidth', 2, 'DisplayName', 'T_{a,ref}');
    xlabel('Tempo [h]'); ylabel('T_a [°C]');
    title('Camera: Temperatura aria');
    legend('Location','best'); ylim([0 14]);

    % -- Tp --
    subplot(2,2,2); hold on; grid on;
    for k = 1:nT
        plot(R(m,k).t, R(m,k).Tp, ...
             'Color', colors(k,:), 'LineStyle', linestyles{k}, 'LineWidth', 1.4, ...
             'DisplayName', sprintf('Ts=%.2fh', Ts_vec(k)));
    end
    yline(5, 'k--', 'LineWidth', 2, 'DisplayName', 'T_{p,ref}(24)=5°C');
    xlabel('Tempo [h]'); ylabel('T_p [°C]');
    title('Prodotto: Temperatura');
    legend('Location','best'); ylim([0 14]);

    % -- Sb --
    subplot(2,2,3); hold on; grid on;
    for k = 1:nT
        plot(R(m,k).t, R(m,k).Sb, ...
             'Color', colors(k,:), 'LineStyle', linestyles{k}, 'LineWidth', 1.4, ...
             'DisplayName', sprintf('Ts=%.2fh', Ts_vec(k)));
    end
    yline(0.60, 'k--', 'LineWidth', 2, 'DisplayName', 'S_{b,nom}=0.60');
    yline(0.15, 'r:', 'LineWidth', 1.5, 'DisplayName', 'S_{b,min}');
    yline(0.95, 'r:', 'LineWidth', 1.5, 'DisplayName', 'S_{b,max}');
    xlabel('Tempo [h]'); ylabel('S_b [p.u.]');
    title('Batteria: Stato di carica');
    legend('Location','best'); ylim([0 1.05]);

    % -- Controlli ur e uf --
    subplot(2,2,4); hold on; grid on;
    for k = 1:nT
        plot(R(m,k).t, R(m,k).ur, ...
             'Color', colors(k,:), 'LineStyle', linestyles{k}, 'LineWidth', 1.4, ...
             'DisplayName', sprintf('u_r Ts=%.2fh', Ts_vec(k)));
    end
    xlabel('Tempo [h]'); ylabel('u_r [0-1]');
    title('Controllo: u_r (refrigerazione)');
    legend('Location','best'); ylim([-0.1 1.1]);

    sgtitle(sprintf('Task 7 – %s', model_labels{m}), 'FontSize', 14, 'FontWeight', 'bold');
    saveas(fig, sprintf('task7_model%d_%s.png', m, strrep(model_labels{m},' ','_')));
end

%% FIGURA 4-7: Per ogni Ts, confronto tra i 3 modelli
for k = 1:nT
    fig = figure('Name', sprintf('Ts = %.2f h – Confronto modelli', Ts_vec(k)), ...
                 'Position', [100 100 1200 800]);
    model_colors = lines(nM);

    % -- Ta --
    subplot(2,2,1); hold on; grid on;
    for m = 1:nM
        plot(R(m,k).t, R(m,k).Ta, ...
             'Color', model_colors(m,:), 'LineWidth', 1.4, ...
             'DisplayName', model_labels{m});
    end
    t_ref = [0 6 6 18 18 24];
    Ta_r  = [6 6  5  5  4  4];
    plot(t_ref, Ta_r, 'k--', 'LineWidth', 2, 'DisplayName', 'T_{a,ref}');
    xlabel('Tempo [h]'); ylabel('T_a [°C]');
    title('Camera: Temperatura aria');
    legend('Location','best'); ylim([0 14]);

    % -- Tp --
    subplot(2,2,2); hold on; grid on;
    for m = 1:nM
        plot(R(m,k).t, R(m,k).Tp, ...
             'Color', model_colors(m,:), 'LineWidth', 1.4, ...
             'DisplayName', model_labels{m});
    end
    yline(5, 'k--', 'LineWidth', 2, 'DisplayName', 'T_{p,ref}(24)');
    xlabel('Tempo [h]'); ylabel('T_p [°C]');
    title('Prodotto: Temperatura');
    legend('Location','best'); ylim([0 14]);

    % -- Sb --
    subplot(2,2,3); hold on; grid on;
    for m = 1:nM
        plot(R(m,k).t, R(m,k).Sb, ...
             'Color', model_colors(m,:), 'LineWidth', 1.4, ...
             'DisplayName', model_labels{m});
    end
    yline(0.60, 'k--', 'LineWidth', 2, 'DisplayName', 'S_{b,nom}');
    yline(0.15, 'r:', 'LineWidth', 1.5); yline(0.95, 'r:', 'LineWidth', 1.5);
    xlabel('Tempo [h]'); ylabel('S_b [p.u.]');
    title('Batteria: Stato di carica');
    legend('Location','best'); ylim([0 1.05]);

    % -- Egrid cumulativa --
    subplot(2,2,4); hold on; grid on;
    for m = 1:nM
        Egrid_cum = cumtrapz(R(m,k).t, max(R(m,k).Pgrid, 0));
        plot(R(m,k).t, Egrid_cum, ...
             'Color', model_colors(m,:), 'LineWidth', 1.4, ...
             'DisplayName', model_labels{m});
    end
    xlabel('Tempo [h]'); ylabel('E_{grid} [kWh]');
    title('Energia cumulativa da rete');
    legend('Location','best');

    sgtitle(sprintf('Task 7 – Ts = %.2f h', Ts_vec(k)), 'FontSize', 14, 'FontWeight', 'bold');
    saveas(fig, sprintf('task7_Ts%.2fh_confronto_modelli.png', Ts_vec(k)));
end

%% FIGURA 8: Disturbances (comune a tutti, basta un calcolo)
t_d = R(1,1).t;
fig8 = figure('Name','Disturbances', 'Position',[100 100 900 400]);
subplot(1,2,1);
Te_d = 24 + 8*sin(2*pi/24*(t_d - 8));
plot(t_d, Te_d, 'b-', 'LineWidth', 1.8);
xlabel('Tempo [h]'); ylabel('T_e [°C]');
title('Temperatura esterna'); grid on; ylim([14 34]);

subplot(1,2,2);
Rs_d = Rmax * max(sin(pi*(t_d - tsr)/(tss - tsr)), 0) .* (t_d >= tsr & t_d <= tss);
PPV_d = Pmax * Rs_d / Rmax;
plot(t_d, PPV_d, 'r-', 'LineWidth', 1.8);
xlabel('Tempo [h]'); ylabel('P_{PV} [kW]');
title('Potenza PV disponibile'); grid on; ylim([0 10]);
sgtitle('Disturbances esterne', 'FontSize', 13);
saveas(fig8, 'task7_disturbances.png');

%% FIGURA 9: Tabella sostenibilità (bar chart)
fig9 = figure('Name','Sostenibilità – Confronto completo', 'Position', [100 100 1200 500]);

% Egrid
subplot(1,3,1);
Egrid_mat = reshape([R.Egrid], nM, nT);
bar(Egrid_mat', 'grouped');
set(gca, 'XTickLabel', arrayfun(@(x) sprintf('%.2fh',x), Ts_vec, 'UniformOutput',false));
xlabel('Ts [h]'); ylabel('E_{grid} [kWh]');
title('Energia da rete'); legend(model_labels, 'Location','best'); grid on;

% EPV_use
subplot(1,3,2);
EPV_mat = reshape([R.EPV_use], nM, nT);
bar(EPV_mat', 'grouped');
set(gca, 'XTickLabel', arrayfun(@(x) sprintf('%.2fh',x), Ts_vec, 'UniformOutput',false));
xlabel('Ts [h]'); ylabel('E_{PV,use} [kWh]');
title('PV effettivamente usata'); legend(model_labels, 'Location','best'); grid on;

% RMSE Ta
subplot(1,3,3);
RMSE_mat = reshape([R.RMSE_Ta], nM, nT);
bar(RMSE_mat', 'grouped');
set(gca, 'XTickLabel', arrayfun(@(x) sprintf('%.2fh',x), Ts_vec, 'UniformOutput',false));
xlabel('Ts [h]'); ylabel('RMSE [°C]');
title('RMSE tracking T_a'); legend(model_labels, 'Location','best'); grid on;

sgtitle('Task 7 – Indicatori globali di performance e sostenibilità', ...
        'FontSize', 13, 'FontWeight', 'bold');
saveas(fig9, 'task7_sostenibilita_summary.png');

%% FIGURA 10: Segnali di controllo ub per tutti i modelli (Ts = 0.1h, default)
k_ref = 2;  % Ts = 0.1 h
fig10 = figure('Name','Controllo batteria ub – confronto modelli', 'Position',[100 100 900 350]);
hold on; grid on;
mc = lines(nM);
for m = 1:nM
    stairs(R(m,k_ref).t, R(m,k_ref).ub, ...
           'Color', mc(m,:), 'LineWidth', 1.4, ...
           'DisplayName', model_labels{m});
end
yline(0,'k--','LineWidth',1);
yline(4,'r:','LineWidth',1,'DisplayName','u_{b,max}');
yline(-4,'r:','LineWidth',1,'DisplayName','u_{b,min}');
xlabel('Tempo [h]'); ylabel('u_b [kW]');
title(sprintf('Comando batteria u_b – Ts = %.2f h', Ts_vec(k_ref)));
legend('Location','best');
saveas(fig10, 'task7_ub_confronto.png');

%% --- 6. Stampa tabella finale riassuntiva ---
fprintf('\n\n=== TABELLA RIASSUNTIVA TASK 7 ===\n');
fprintf('%-20s | %-6s | RMSE_Ta | Tp(24) | Egrid[kWh] | EPV[kWh] | PV%%  | SbOK\n', ...
        'Modello', 'Ts[h]');
fprintf('%s\n', repmat('-',1,82));
for m = 1:nM
    for k = 1:nT
        r = R(m,k);
        fprintf('%-20s | %-6.2f | %7.4f | %6.2f | %10.3f | %8.3f | %4.1f%% | %s\n', ...
            r.label, r.Ts, r.RMSE_Ta, r.Tp_fin, ...
            r.Egrid, r.EPV_use, r.PV_frac, string(r.Sb_ok));
    end
    fprintf('%s\n', repmat('-',1,82));
end

fprintf('\nTutti i plot salvati come .png nella cartella corrente.\n');