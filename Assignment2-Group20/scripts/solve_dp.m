function [sequence, totalCost, breakdown] = solve_dp()
%
% APPROACH B - Dynamic Programming
%
% State: (S, last, t)
%   S    = subset of jobs already scheduled  (size k)
%   last = last task in S (needed because setup is sequence-dependent)
%   t    = completion time of last on the path that produced this state
% Output:
%   sequence   : ordered list of task indices (1..n)
%   totalCost  : optimal objective value (fuel units)
%   breakdown  : struct with setup / tardiness / remobilization components

clc

%% -------------------------------------------------------------
%  1) PROBLEM DATA
%  -------------------------------------------------------------
dbFile = 'offshore_wind.db';
conn   = sqlite(dbFile,'connect');

T = fetch(conn,['SELECT TaskID,StructureType,ProcTime,' ...
                'WeatherWindowEnd,LogisticsWeight ' ...
                'FROM Deployment_Schedule ORDER BY TaskID;']);
n     = size(T,1);
types = string(T.StructureType);
p     = double(T.ProcTime);
d     = double(T.WeatherWindowEnd);
w     = double(T.LogisticsWeight);

F_fuel = fetch(conn,'SELECT FromType,ToType,FuelCost FROM Setup_Fuel_Matrix;');
close(conn);

getSetup = @(a,b) F_fuel.FuelCost(F_fuel.FromType==string(a) & F_fuel.ToType==string(b));

port_setup = zeros(n,1);
S          = zeros(n,n);
for j = 1:n
    port_setup(j) = getSetup('P',types(j));
    for i = 1:n
        if i ~= j
            S(i,j) = getSetup(types(i),types(j));
        end
    end
end

fixedCost = 100;

fprintf('Number of tasks n = %d\n',n);
fprintf('Processing times p = [%s]\n',num2str(p'));
fprintf('Weather windows d = [%s]\n',num2str(d'));
fprintf('Weights         w = [%s]\n',num2str(w'));
fprintf('Port setup      = [%s]\n',num2str(port_setup'));
fprintf('\nSetup matrix S (n x n):\n'); disp(S);
fprintf('\nFuel matrix F (raw table):\n'); disp(F_fuel);

%% -------------------------------------------------------------
%  2) SUBSETS PER STAGE
%  -------------------------------------------------------------
X = cell(n,1);
for k = 1:n
    X{k} = nchoosek(1:n,k);
end

%% -------------------------------------------------------------
%  3) FORWARD PASS: enumerate reachable completion times per (S,last)
%  -------------------------------------------------------------
% Reach{k}{r,j} = tempo per arrivare e concludere task j
Reach = cell(n,1);
for k = 1:n
    Reach{k} = cell(size(X{k},1), n);
end

% passo 1 (Port -> j)
for r = 1:size(X{1},1)
    j = X{1}(r,1);
    Reach{1}{r,j} = port_setup(j) + p(j);
end

% passi 2..n
for k = 2:n
    for r = 1:size(X{k},1)
        Sset = X{k}(r,:);
        for j = Sset
            prevSet = setdiff(Sset, j);
            [~, rPrev] = ismember(prevSet, X{k-1}, 'rows');
            ts = [];
            for i = prevSet
                Tprev = Reach{k-1}{rPrev, i};
                if isempty(Tprev), continue; end
                ts = [ts, Tprev + S(i,j) + p(j)]; 
            end
            Reach{k}{r,j} = unique(ts);
        end
    end
end

%% -------------------------------------------------------------
%  4) BACKWARD DP : passo n  ->  passo 1
%  -------------------------------------------------------------
% V{k}{r,j}(ti)   = optimal cost-to-go from state (X{k}(r,:), last=j,
%                   t=Reach{k}{r,j}(ti)) to complete the remaining jobs.
% NXT{k}{r,j}(ti,:) = (rNext, jNext, tiNext) for forward reconstruction.
V   = cell(n,1);
NXT = cell(n,1);
for k = 1:n
    V{k}   = cell(size(X{k},1), n);
    NXT{k} = cell(size(X{k},1), n);
end

% --- passo n : base case, V = 0 (all jobs already scheduled) -----------
for j = 1:n
    Tn = Reach{n}{1,j};
    if isempty(Tn), continue; end
    V{n}{1,j} = zeros(size(Tn));
end

% --- passo k = n-1 .. 1 : backward recursion ---------------------------
for k = (n-1):-1:1
    for r = 1:size(X{k},1)
        Sset = X{k}(r,:);
        Rset = setdiff(1:n, Sset);          % remaining (not yet done)
        for j = Sset
            Tj = Reach{k}{r,j};
            if isempty(Tj), continue; end
            V{k}{r,j}   = inf(size(Tj));
            NXT{k}{r,j} = zeros(numel(Tj),3);
            for ti = 1:numel(Tj)
                t = Tj(ti);
                bestC = inf; bestNext = [0 0 0];
                for h = Rset                 % candidate next job
                    nextSet = sort([Sset h]);
                    [~, rNext] = ismember(nextSet, X{k+1}, 'rows');
                    tnew = t + S(j,h) + p(h);
                    tard = max(0, tnew - d(h));
                    cIm  = S(j,h) + w(h)*tard + fixedCost*(tard>0);
                    Tnext   = Reach{k+1}{rNext, h};
                    tnextI  = find(Tnext == tnew, 1);
                    if isempty(tnextI), continue; end
                    if isinf(V{k+1}{rNext,h}(tnextI)), continue; end
                    cTotal = cIm + V{k+1}{rNext,h}(tnextI);
                    if cTotal < bestC
                        bestC = cTotal; bestNext = [rNext, h, tnextI];
                    end
                end
                V{k}{r,j}(ti)     = bestC;
                NXT{k}{r,j}(ti,:) = bestNext;
            end
        end
    end
end

%% -------------------------------------------------------------
%  5) PASSO 0 : Port -> first job
%  -------------------------------------------------------------
bestCost  = inf;
bestFirst = 0;
bestR     = 0;
bestTi    = 0;
for j = 1:n
    rFirst = find(X{1} == j);
    t      = port_setup(j) + p(j);
    tard   = max(0, t - d(j));
    cIm    = port_setup(j) + w(j)*tard + fixedCost*(tard>0);
    Tj     = Reach{1}{rFirst, j};
    ti     = find(Tj == t, 1);
    if isempty(ti) || isinf(V{1}{rFirst,j}(ti)), continue; end
    cTotal = cIm + V{1}{rFirst,j}(ti);
    if cTotal < bestCost
        bestCost  = cTotal;
        bestFirst = j;
        bestR     = rFirst;
        bestTi    = ti;
    end
end
totalCost = bestCost;

fprintf('\n[DP] Optimal cost = %.4f, first task = %d\n', totalCost, bestFirst);

%% -------------------------------------------------------------
%  6) FORWARD RECONSTRUCTION OF SEQUENCE
%  -------------------------------------------------------------
sequence = zeros(1,n);
curR = bestR; curJ = bestFirst; curTi = bestTi;
for k = 1:n
    sequence(k) = curJ;
    if k < n
        nxt   = NXT{k}{curR, curJ}(curTi,:);
        curR  = nxt(1);
        curJ  = nxt(2);
        curTi = nxt(3);
    end
end
fprintf('Sequence: %s\n', strjoin(string(sequence),' -> '));

%% -------------------------------------------------------------
%  7) COST BREAKDOWN
%  -------------------------------------------------------------
sVal = zeros(n,1); cVal = zeros(n,1);
setupTot = 0; tardTot = 0; remobTot = 0;
tcur = 0;
for k = 1:n
    j = sequence(k);
    if k == 1
        st = port_setup(j);
    else
        st = S(sequence(k-1),j);
    end
    sVal(j) = tcur + st;
    cVal(j) = sVal(j) + p(j);
    tcur    = cVal(j);
    setupTot = setupTot + st;
    if cVal(j) > d(j)
        tardTot  = tardTot  + w(j)*(cVal(j)-d(j));
        remobTot = remobTot + fixedCost;
    end
end
breakdown.setup          = setupTot;
breakdown.tardiness      = tardTot;
breakdown.remobilization = remobTot;
breakdown.total          = setupTot + tardTot + remobTot;

fprintf('\nBreakdown:\n');
fprintf('  setup     = %.2f\n', setupTot);
fprintf('  tardiness = %.2f\n', tardTot);
fprintf('  remob.    = %.2f\n', remobTot);
fprintf('  total     = %.2f\n', breakdown.total);

%% -------------------------------------------------------------
%  8) GANTT CHART
%  -------------------------------------------------------------
colSetup   = [0.85 0.55 0.20];
colProcess = [0.20 0.55 0.85];
colLate    = [0.85 0.20 0.20];

f = figure('Name','DP Gantt Chart','Color','w');
hold on;

nSeq    = numel(sequence);
yHeight = 0.6;

for k = 1:nSeq
    j    = sequence(k);
    yPos = nSeq - k + 1;

    if k == 1
        setupStart = 0;
        setupDur   = port_setup(j);
        setupLabel = sprintf('Port->%s', types(j));
    else
        iPrev      = sequence(k-1);
        setupStart = cVal(iPrev);
        setupDur   = S(iPrev,j);
        setupLabel = sprintf('%s->%s', types(iPrev), types(j));
    end
    if setupDur > 0
        rectangle('Position',[setupStart, yPos-yHeight/2, setupDur, yHeight], ...
                  'FaceColor', colSetup, 'EdgeColor','k');
        text(setupStart + setupDur/2, yPos, setupLabel, ...
             'HorizontalAlignment','center','VerticalAlignment','middle', ...
             'FontSize',8,'Color','k');
    end

    procStart = sVal(j);
    procDur   = p(j);
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

    plot([d(j) d(j)], [yPos-yHeight/2, yPos+yHeight/2], ...
         'k--','LineWidth',1.2);
    text(d(j), yPos+yHeight/2 + 0.05, sprintf('d=%g', d(j)), ...
         'HorizontalAlignment','center','VerticalAlignment','bottom', ...
         'FontSize',7,'Color','k');
end

yticks(1:nSeq);
yticklabels(arrayfun(@(k) sprintf('Slot %d (T%d)', k, sequence(k)), ...
            nSeq:-1:1, 'UniformOutput', false));
xlabel('Time (h)');
ylabel('Schedule order');
title(sprintf('DP Optimal Schedule  |  Total fuel cost = %.2f', totalCost));
grid on; box on;
xlim([0, max(cVal) * 1.10]);
ylim([0.3, nSeq + 0.7]);

hSetup = patch(NaN,NaN,colSetup);
hProc  = patch(NaN,NaN,colProcess);
hLate  = patch(NaN,NaN,colLate);
hDead  = plot(NaN,NaN,'k--','LineWidth',1.2);
legend([hSetup hProc hLate hDead], ...
       {'Setup (port / inter-task)','Processing','Tardy portion','Deadline d_j'}, ...
       'Location','southoutside','Orientation','horizontal');

exportgraphics(f, '../results/dpGantt.png', 'Resolution', 300);


hold off;