function [sequence, totalCost, breakdown] = solve_milp()
% SOLVE_MILP  Mathematical-programming approach (Approach A) for the
%             Offshore Wind Installation problem with sequence-dependent
%             fuel consumption and tardiness penalties.
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
RemobCost = 500;

% Big-M constant (same style the professor uses)
M = 10000;

fprintf('Number of tasks n = %d\n',n);
fprintf('Processing times p = [%s]\n',num2str(p'));
fprintf('Weather windows d = [%s]\n',num2str(d'));
fprintf('Weights         w = [%s]\n',num2str(w'));
fprintf('Port setup      = [%s]\n',num2str(port_setup'));

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
Tvar = optimvar('T',n,1,'LowerBound',0);
% x(i,j) = 1 if task i is immediately before task j
x    = optimvar('x',n,n,'Type','integer','LowerBound',0,'UpperBound',1);
% y(j) = 1 if task j is the FIRST scheduled after Port
y    = optimvar('y',n,1,'Type','integer','LowerBound',0,'UpperBound',1);
% late(j) = 1 if task j violates its weather window
late = optimvar('late',n,1,'Type','integer','LowerBound',0,'UpperBound',1);

%% -------------------------------------------------------------
%  3) OBJECTIVE (fuel: setup + tardiness penalty + remobilization)
%  -------------------------------------------------------------
setupFromPort = sum(port_setup .* y);

setupBetween  = optimexpr(1,1);   % scalar expression we will accumulate
for i = 1:n
    for j = 1:n
        if i ~= j
            setupBetween = setupBetween + S(i,j)*x(i,j);
        end
    end
end

tardinessCost = sum(w .* Tvar);
remobCost     = sum(RemobCost .* late);

prob.Objective = setupFromPort + setupBetween + tardinessCost + remobCost;

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
    cons7(j) = Tvar(j) >= c(j) - d(j);
end
prob.Constraints.cons7 = cons7;

% C8: linking "late" binary to tardiness (fixed remobilization cost)
cons8 = optimconstr(n);
for j = 1:n
    cons8(j) = c(j) - d(j) <= M * late(j);
end
prob.Constraints.cons8 = cons8;

%% -------------------------------------------------------------
%  5) SOLVE
%  -------------------------------------------------------------
opts = optimoptions('intlinprog','Display','off');
[xopt, totalCost, exitflag] = solve(prob,'Options',opts);

if exitflag <= 0
    error('MILP did not find a feasible/optimal solution (exitflag=%d).',exitflag);
end

%% -------------------------------------------------------------
%  6) DECODE SEQUENCE FROM x, y
%  -------------------------------------------------------------
xSol    = round(xopt.x);
ySol    = round(xopt.y);
cSol    = xopt.c;
TSol    = xopt.T;
lateSol = round(xopt.late);

sequence = zeros(1,n);
sequence(1) = find(ySol == 1, 1);        % first task
for k = 2:n
    prev = sequence(k-1);
    nxt  = find(xSol(prev,:) == 1, 1);
    if isempty(nxt)
        error('Broken chain: no successor found after task %d',prev);
    end
    sequence(k) = nxt;
end

%% -------------------------------------------------------------
%  7) COST BREAKDOWN
%  -------------------------------------------------------------
setupFromPortVal = port_setup(sequence(1));
setupBetweenVal  = 0;
for k = 1:n-1
    setupBetweenVal = setupBetweenVal + S(sequence(k),sequence(k+1));
end
tardinessVal = sum(w .* TSol);
remobVal     = sum(RemobCost .* lateSol);

breakdown.setupFromPort = setupFromPortVal;
breakdown.setupBetween  = setupBetweenVal;
breakdown.tardiness     = tardinessVal;
breakdown.remobilization= remobVal;
breakdown.completionTimes = cSol;
breakdown.tardinessPerTask= TSol;

%% -------------------------------------------------------------
%  8) REPORT
%  -------------------------------------------------------------
fprintf('\n========== MILP SOLUTION ==========\n');
fprintf('Optimal sequence : ');
for k = 1:n
    fprintf('Task_%02d(%s)',sequence(k),types(sequence(k)));
    if k<n, fprintf(' -> '); end
end
fprintf('\n');
fprintf('Completion times : [%s]\n', num2str(cSol'));
fprintf('Weather windows  : [%s]\n', num2str(d'));
fprintf('Tardiness (h)    : [%s]\n', num2str(TSol'));
fprintf('Late indicators  : [%s]\n', num2str(lateSol'));
fprintf('--- Cost breakdown (fuel units) ---\n');
fprintf('  Setup from Port      = %8.2f\n', setupFromPortVal);
fprintf('  Setup between tasks  = %8.2f\n', setupBetweenVal);
fprintf('  Tardiness penalty    = %8.2f\n', tardinessVal);
fprintf('  Remobilization fixed = %8.2f\n', remobVal);
fprintf('  TOTAL (objective)    = %8.2f\n', totalCost);
fprintf('====================================\n');

end
