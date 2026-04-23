function [sequence, totalCost, breakdown] = nearest_neighbor()
% NEAREST_NEIGHBOR  Greedy heuristic for the Offshore Wind Installation problem.
%                   At each step, chooses the next task that minimizes the 
%                   setup fuel cost from the current state.
%                   In case of a tie, chooses the one with smallest TaskID.

clear
clc

dbFile = 'offshore_wind.db';
conn   = sqlite(dbFile,'connect');

Ttab = fetch(conn,['SELECT TaskID,StructureType,ProcTime,' ...
                   'WeatherWindowEnd,LogisticsWeight ' ...
                   'FROM Deployment_Schedule ORDER BY TaskID;']);
n = size(Ttab,1);
types = string(Ttab.StructureType);
p  = double(Ttab.ProcTime);
d  = double(Ttab.WeatherWindowEnd);
w  = double(Ttab.LogisticsWeight);

F = fetch(conn,'SELECT FromType,ToType,FuelCost FROM Setup_Fuel_Matrix;');
close(conn);

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

RemobCost = 500;

% ALGORITHM: Nearest Neighbor
unvisited = 1:n;
sequence = zeros(1,n);

% Step 1: Find first task from Port with minimum setup
[~, firstIdx_temp] = min(port_setup(unvisited));
% In caso ci fossero doppi minimi, min restituisce il primo indice (ID più basso tra i min)
firstTask = unvisited(firstIdx_temp);

sequence(1) = firstTask;
unvisited(unvisited == firstTask) = [];

% Step 2: Greedily pick the next task with lowest setup
for k = 2:n
    lastTask = sequence(k-1);
    
    bestNext = -1;
    bestCost = inf;
    for u = unvisited
        costS = S(lastTask, u);
        if costS < bestCost
            bestCost = costS;
            bestNext = u;
        elseif costS == bestCost && u < bestNext
            % Tie breaker: fallback su ID più piccolo
            bestNext = u;
        end
    end
    
    sequence(k) = bestNext;
    unvisited(unvisited == bestNext) = [];
end

% EVALUATE THE SEQUENCE
completionTimes  = zeros(n,1);
tardinessPerTask = zeros(n,1);
lateFlags        = zeros(n,1);

setupFromPortVal = port_setup(sequence(1));
setupBetweenVal  = 0;

tNow = port_setup(sequence(1)) + p(sequence(1));
completionTimes(sequence(1)) = tNow;
if tNow > d(sequence(1))
    tardinessPerTask(sequence(1)) = tNow - d(sequence(1));
    lateFlags(sequence(1))        = 1;
end

for k = 2:n
    prev = sequence(k-1);
    cur  = sequence(k);
    setupBetweenVal = setupBetweenVal + S(prev,cur);
    tNow = tNow + S(prev,cur) + p(cur);
    completionTimes(cur) = tNow;
    if tNow > d(cur)
        tardinessPerTask(cur) = tNow - d(cur);
        lateFlags(cur)        = 1;
    end
end

tardinessVal = sum(w .* tardinessPerTask);
remobVal     = sum(RemobCost .* lateFlags);

totalCost = setupFromPortVal + setupBetweenVal + tardinessVal + remobVal;

breakdown.setupFromPort    = setupFromPortVal;
breakdown.setupBetween     = setupBetweenVal;
breakdown.tardiness        = tardinessVal;
breakdown.remobilization   = remobVal;
breakdown.completionTimes  = completionTimes;
breakdown.tardinessPerTask = tardinessPerTask;

fprintf('\n======= NEAREST NEIGHBOR =======\n');
fprintf('Optimal sequence : ');
for k = 1:n
    fprintf('Task_%02d(%s)',sequence(k),types(sequence(k)));
    if k<n, fprintf(' -> '); end
end
fprintf('\n');
fprintf('Completion times : [%s]\n', num2str(completionTimes'));
fprintf('Weather windows  : [%s]\n', num2str(d'));
fprintf('Tardiness (h)    : [%s]\n', num2str(tardinessPerTask'));
fprintf('Late indicators  : [%s]\n', num2str(lateFlags'));
fprintf('--- Cost breakdown (fuel units) ---\n');
fprintf('  Setup from Port      = %8.2f\n', setupFromPortVal);
fprintf('  Setup between tasks  = %8.2f\n', setupBetweenVal);
fprintf('  Tardiness penalty    = %8.2f\n', tardinessVal);
fprintf('  Remobilization fixed = %8.2f\n', remobVal);
fprintf('  TOTAL                = %8.2f\n', totalCost);
fprintf('====================================\n');

end
