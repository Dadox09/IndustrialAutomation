function [sequence, totalCost, breakdown] = solve_milp()
%
% Output:
%   sequence   : ordered list of task indices (1..n)
%   totalCost  : optimal objective value (fuel units)
%   breakdown  : struct with setup / tardiness / remobilization components

clear
clc

%% -------------------------------------------------------------
%  1) PROBLEM DATA (read from SQLite, same values as Table 1-2)
%  -------------------------------------------------------------
dbFile = 'offshore_wind.db';
conn   = sqlite(dbFile,'connect');

% Tasks
T = fetch(conn,['SELECT TaskID,StructureType,ProcTime,' ...
                'WeatherWindowEnd,LogisticsWeight ' ...
                'FROM Deployment_Schedule ORDER BY TaskID;']);
n = size(T,1);                       % number of tasks (= 4)
types = string(T.StructureType);     % 'M','J','N','M'
p  = double(T.ProcTime);             % processing time  (h)
d  = double(T.WeatherWindowEnd);     % weather-window end d_j (h)
w  = double(T.LogisticsWeight);      % logistic weight  w_j

% Setup fuel matrix (including Port 'P')
F = fetch(conn,'SELECT FromType,ToType,FuelCost FROM Setup_Fuel_Matrix;');
close(conn);

% Build a lookup for setup cost by (fromType,toType)
getSetup = @(a,b) F.FuelCost(F.FromType==string(a) & F.ToType==string(b));

% Pre-build port_setup(j) and inter-task matrix S(i,j)
port_setup = zeros(n,1);
S          = zeros(n,n);             % S(i,i) unused
for j = 1:n
    port_setup(j) = getSetup('P',types(j));
    for i = 1:n
        if i ~= j
            S(i,j) = getSetup(types(i),types(j));
        end
    end
end

% Re-mobilization fixed cost (fuel units) if a task misses its window
fixedCost = 100;

M = 10000;

fprintf('Number of tasks n = %d\n',n);
fprintf('Processing times p = [%s]\n',num2str(p'));
fprintf('Weather windows d = [%s]\n',num2str(d'));
fprintf('Weights         w = [%s]\n',num2str(w'));
fprintf('Port setup      = [%s]\n',num2str(port_setup'));
fprintf('\nSetup matrix S (n x n):\n');
disp(S);  
fprintf('\nFuel matrix F (raw table):\n');
disp(F);



%% -------------------------------------------------------------
%  2) OPTIMIZATION PROBLEM (problem-based MILP)
%  -------------------------------------------------------------
prob = optimproblem('ObjectiveSense','min');

% ---- decisional variables (optimvar) ----
% start time for each task
s    = optimvar('s',n,1,'LowerBound',0);
% completion time for each task
c    = optimvar('c',n,1,'LowerBound',0);
% tardiness (>=0)
Tardiness = optimvar('T',n,1,'LowerBound',0);
% x(i,j) = 1 if task i is immediately before task j
x    = optimvar('x',n,n,'Type','integer','LowerBound',0,'UpperBound',1);
% y(j) = 1 if task j is the FIRST scheduled after Port
y    = optimvar('y',n,1,'Type','integer','LowerBound',0,'UpperBound',1);
% late(j) = 1 if task j violates its weather window
penalty = optimvar('penalty',n,1,'Type','integer','LowerBound',0,'UpperBound',1);

%% -------------------------------------------------------------
%  3) OBJECTIVE (fuel: setup + tardiness penalty + remobilization)
%  -------------------------------------------------------------
setupFromPort = sum(port_setup .* y);

setupBetweenTasks  = optimexpr(1,1);   
for i = 1:n
    for j = 1:n
        if i ~= j
            setupBetweenTasks = setupBetweenTasks + S(i,j)*x(i,j);
        end
    end
end

tardinessCost = sum(w .* Tardiness);
penaltyCost     = sum(fixedCost .* penalty);

prob.Objective = setupFromPort + setupBetweenTasks + tardinessCost + penaltyCost;

%% -------------------------------------------------------------
%  4) CONSTRAINTS
%  -------------------------------------------------------------

% C1: every task has exactly ONE predecessor (Port or another task)
cons1 = optimconstr(n);
for j = 1:n
    cons1(j) = y(j) + sum(x(:,j)) - x(j,j) == 1;   % exclude x(j,j)
end
prob.Constraints.cons1 = cons1;

% C2: every task has AT MOST ONE successor
cons2 = optimconstr(n);
for i = 1:n
    cons2(i) = sum(x(i,:)) - x(i,i) <= 1;
end
prob.Constraints.cons2 = cons2;

% C3: exactly ONE task is scheduled first
cons3 = sum(y) == 1;
prob.Constraints.cons3 = cons3;

% C4: completion time definition  c(j) = s(j) + p(j)
cons4 = optimconstr(n);
for j = 1:n
    cons4(j) = c(j) == s(j) + p(j);
end
prob.Constraints.cons4 = cons4;

% C5: if j is first, start >= port setup
cons5 = optimconstr(n);
for j = 1:n
    cons5(j) = s(j) >= port_setup(j) - M*(1 - y(j));
end
prob.Constraints.cons5 = cons5;

% C6: Big-M sequencing: if x(i,j)=1 then s(j) >= c(i) + S(i,j)
cons6 = optimconstr(n*n - n);
count = 0;
for i = 1:n
    for j = 1:n
        count = count + 1;
        if i ~= j
            cons6(count) = s(j) >= c(i) + S(i,j) - M*(1 - x(i,j));
        end
    end
end
prob.Constraints.cons6 = cons6;

% C7: tardiness definition
cons7 = optimconstr(n);
for j = 1:n
    cons7(j) = Tardiness(j) >= c(j) - d(j);
end
prob.Constraints.cons7 = cons7;

% C8: penalty with tardiness
cons8 = optimconstr(n);
for j = 1:n
    cons8(j) = c(j) - d(j) <= M * penalty(j);
end
prob.Constraints.cons8 = cons8;

%% -------------------------------------------------------------
%  5) SOLVE
%  -------------------------------------------------------------
[xopt, totalCost] = solve(prob);

disp(xopt)
disp(xopt.T)
disp(xopt.c)

[~, sequence] = sort(xopt.c);
fprintf('\nSequence: %s\n', strjoin(string(sequence'),' -> '));

%% -------------------------------------------------------------
%  6) GANTT CHART
%  -------------------------------------------------------------
sVal = xopt.s;          % start times
cVal = xopt.c;          % completion times

% Colors
colSetup   = [0.85 0.55 0.20];   % orange  -> setup (port + inter-task)
colProcess = [0.20 0.55 0.85];   % blue    -> processing
colLate    = [0.85 0.20 0.20];   % red     -> tardiness portion

figure('Name','MILP Gantt Chart','Color','w');
hold on;

nSeq = numel(sequence);
yHeight = 0.6;          % bar thickness

for k = 1:nSeq
    j = sequence(k);    % task index in scheduled order
    yPos = nSeq - k + 1;   % top-down layout (first task on top)

    % --- (a) setup bar BEFORE task j ---
    if k == 1
        setupStart = 0;
        setupDur   = port_setup(j);
        setupLabel = sprintf('Port->%s', types(j));
    else
        iPrev      = sequence(k-1);
        setupStart = cVal(iPrev);
        setupDur   = S(iPrev, j);
        setupLabel = sprintf('%s->%s', types(iPrev), types(j));
    end
    if setupDur > 0
        rectangle('Position',[setupStart, yPos-yHeight/2, setupDur, yHeight], ...
                  'FaceColor', colSetup, 'EdgeColor','k');
        text(setupStart + setupDur/2, yPos, setupLabel, ...
             'HorizontalAlignment','center','VerticalAlignment','middle', ...
             'FontSize',8,'Color','k');
    end

    % --- (b) processing bar (s(j) -> c(j)) ---
    procStart = sVal(j);
    procDur   = p(j);

    % split processing into on-time and tardy portion (visual)
    if cVal(j) <= d(j)
        rectangle('Position',[procStart, yPos-yHeight/2, procDur, yHeight], ...
                  'FaceColor', colProcess, 'EdgeColor','k');
    else
        onTimeDur = max(0, d(j) - procStart);
        lateDur   = procDur - onTimeDur;
        if onTimeDur > 0
            rectangle('Position',[procStart, yPos-yHeight/2, onTimeDur, yHeight], ...
                      'FaceColor', colProcess, 'EdgeColor','k');
        end
        rectangle('Position',[procStart + onTimeDur, yPos-yHeight/2, lateDur, yHeight], ...
                  'FaceColor', colLate, 'EdgeColor','k');
    end
    text(procStart + procDur/2, yPos, sprintf('T%d (%s)', j, types(j)), ...
         'HorizontalAlignment','center','VerticalAlignment','middle', ...
         'FontSize',9,'FontWeight','bold','Color','w');

    % --- (c) deadline marker d(j) ---
    plot([d(j) d(j)], [yPos-yHeight/2, yPos+yHeight/2], ...
         'k--','LineWidth',1.2);
    text(d(j), yPos+yHeight/2 + 0.05, sprintf('d=%g', d(j)), ...
         'HorizontalAlignment','center','VerticalAlignment','bottom', ...
         'FontSize',7,'Color','k');
end

% Axes / labels
yticks(1:nSeq);
yticklabels(arrayfun(@(k) sprintf('Slot %d (T%d)', k, sequence(k)), ...
            nSeq:-1:1, 'UniformOutput', false));
xlabel('Time (h)');
ylabel('Schedule order');
title(sprintf('Optimal Schedule  |  Total fuel cost = %.2f', totalCost));
grid on; box on;
xlim([0, max(cVal) * 1.10]);
ylim([0.3, nSeq + 0.7]);

% Legend (dummy patches)
hSetup   = patch(NaN,NaN,colSetup);
hProc    = patch(NaN,NaN,colProcess);
hLate    = patch(NaN,NaN,colLate);
hDead    = plot(NaN,NaN,'k--','LineWidth',1.2);
legend([hSetup hProc hLate hDead], ...
       {'Setup (port / inter-task)','Processing','Tardy portion','Deadline d_j'}, ...
       'Location','southoutside','Orientation','horizontal');

hold off;
