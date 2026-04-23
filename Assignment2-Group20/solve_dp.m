function [sequence, totalCost, breakdown] = solve_dp()
% SOLVE_DP  Dynamic Programming approach (Approach B) — same stage-based
%           style as the teacher's principale2.m, extended to cope with
%           sequence-dependent setups.
%
%   State at stage k : (X{k}(i,:) , j)   subset of k tasks ending with j
%   Go{k}{i,j}       : list of NON-DOMINATED (cost,time) tuples
%                      reaching that state.  Each row =
%                      [cost, time, prevLast, prevSubIdx, prevTupleRow]
%
%   Reason for the list:  with sequence-dependent setups a path with
%   higher cost may finish earlier, helping future tasks — so we keep
%   the whole Pareto frontier per state.

clear
clc

%% -------------------------------------------------------------
%  1) PROBLEM DATA (read from SQLite, same as the MILP)
%  -------------------------------------------------------------
dbFile = 'offshore_wind.db';
conn   = sqlite(dbFile,'connect');

Ttab = fetch(conn,['SELECT TaskID,StructureType,ProcTime,' ...
                   'WeatherWindowEnd,LogisticsWeight ' ...
                   'FROM Deployment_Schedule ORDER BY TaskID;']);
n     = size(Ttab,1);
types = string(Ttab.StructureType);
p     = double(Ttab.ProcTime);
d     = double(Ttab.WeatherWindowEnd);
w     = double(Ttab.LogisticsWeight);

F = fetch(conn,'SELECT FromType,ToType,FuelCost FROM Setup_Fuel_Matrix;');
close(conn);

getSetup = @(a,b) F.FuelCost(F.FromType==string(a) & F.ToType==string(b));

port_setup = zeros(n,1);
S_mat      = zeros(n,n);
for jj = 1:n
    port_setup(jj) = getSetup('P',types(jj));
    for ii = 1:n
        if ii ~= jj
            S_mat(ii,jj) = getSetup(types(ii),types(jj));
        end
    end
end

RemobCost = 500;
penalty = @(j,cj) (cj > d(j)) * ( w(j)*(cj - d(j)) + RemobCost );

%% -------------------------------------------------------------
%  2) STATES BY STAGE   (same structure as principale2.m)
%  -------------------------------------------------------------
J  = (1:n)';
X0 = 0;
for k = 1:n
    X{k}     = nchoosek(1:n, k);          % built-in, same format as combnk
    stati(k) = size(X{k}, 1);
end

% Each Go{k}{i,j} is a (possibly empty) matrix with columns
%   [ cost , time , prevLast , prevSubIdx , prevTupleRow ]
for k = 1:n
    Go{k} = cell(stati(k), n);
    for i = 1:stati(k)
        for j = 1:n
            Go{k}{i,j} = zeros(0, 5);    % no tuples yet
        end
    end
end

%% -------------------------------------------------------------
%  3) BASE CASE — stage 1 (each task, coming from Port)
%  -------------------------------------------------------------
for i = 1:stati(1)
    j     = X{1}(i,1);
    compT = port_setup(j) + p(j);
    cst   = port_setup(j) + penalty(j, compT);

    Go{1}{i, j} = [cst, compT, 0, 0, 0];   % prevLast=0 (Port)
end

%% -------------------------------------------------------------
%  4) FORWARD RECURSION  stage k = 1..n-1  ->  stage k+1
%  -------------------------------------------------------------
for k = 1:n-1
    for i = 1:stati(k)
        prevSet = X{k}(i,:);

        for j = 1:stati(k+1)
            if all(ismember(prevSet, X{k+1}(j,:)))
                added = setdiff(X{k+1}(j,:), prevSet);    % scalar

                for pl = prevSet                          % previous last task
                    tuples = Go{k}{i, pl};
                    if isempty(tuples), continue; end

                    for tr = 1:size(tuples, 1)            % each Pareto tuple
                        cstPrev = tuples(tr, 1);
                        tPrev   = tuples(tr, 2);

                        compT = tPrev + S_mat(pl, added) + p(added);
                        cst   = cstPrev + S_mat(pl, added) ...
                                + penalty(added, compT);

                        newTup = [cst, compT, pl, i, tr];
                        Go{k+1}{j, added} = [Go{k+1}{j, added}; newTup];
                    end
                end
            end
        end
    end
end

%% -------------------------------------------------------------
%  5) FINAL: pick best tuple at stage n across all last tasks
%  -------------------------------------------------------------
totalCost = inf; bestJ = 0; bestRow = 0;
for j = 1:n
    tuples = Go{n}{1, j};
    if isempty(tuples), continue; end
    [c, r] = min(tuples(:,1));
    if c < totalCost
        totalCost = c;
        bestJ   = j;
        bestRow = r;
    end
end
if isinf(totalCost)
    error('DP did not find any feasible schedule.');
end

%% -------------------------------------------------------------
%  6) BACKTRACK to rebuild the sequence
%  -------------------------------------------------------------
sequence = zeros(1,n);
curK   = n;
curI   = 1;
curJ   = bestJ;
curRow = bestRow;
for pos = n:-1:1
    sequence(pos) = curJ;
    if curK == 0, break; end
    tup = Go{curK}{curI, curJ}(curRow, :);
    prevLast = tup(3);
    prevSub  = tup(4);
    prevRow  = tup(5);
    curK   = curK - 1;
    curI   = prevSub;
    curJ   = prevLast;
    curRow = prevRow;
end

%% -------------------------------------------------------------
%  7) COST BREAKDOWN (simulate forward on the recovered sequence)
%  -------------------------------------------------------------
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
    setupBetweenVal = setupBetweenVal + S_mat(prev,cur);
    tNow = tNow + S_mat(prev,cur) + p(cur);
    completionTimes(cur) = tNow;
    if tNow > d(cur)
        tardinessPerTask(cur) = tNow - d(cur);
        lateFlags(cur)        = 1;
    end
end

tardinessVal = sum(w .* tardinessPerTask);
remobVal     = sum(RemobCost .* lateFlags);

breakdown.setupFromPort    = setupFromPortVal;
breakdown.setupBetween     = setupBetweenVal;
breakdown.tardiness        = tardinessVal;
breakdown.remobilization   = remobVal;
breakdown.completionTimes  = completionTimes;
breakdown.tardinessPerTask = tardinessPerTask;

%% -------------------------------------------------------------
%  8) REPORT
%  -------------------------------------------------------------
fprintf('\n=========== DP SOLUTION ===========\n');
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

% Diagnostic: how many Pareto tuples exist per state
nTot = 0;
for k = 1:n
    for i = 1:stati(k)
        for j = 1:n
            nTot = nTot + size(Go{k}{i,j},1);
        end
    end
end
fprintf('DP tuples stored overall : %d\n', nTot);
fprintf('====================================\n');

end
