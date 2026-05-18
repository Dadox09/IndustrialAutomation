%% build_submission_Group20.m
% Sustainable MRP 90-min Challenge - Group 20
%
% FORECAST:  multiplicative seasonal decomposition (Lez3-7 slides 27-32)
%            + fitlm on deseasonalised demand (Lez3-8 slide 6)
%            + jackknife/LOO validation, MAPD metric (Lez3-7 slides 14, 16-17)
%
% PRODUCTION: fixed at weekly capacity limit (dominant strategy when
%             demand >> capacity and stockout penalty 430 EUR/unit >> cProd)
%
% PROCUREMENT: LP via linprog - minimises purchase + material-holding cost
%              subject to: material balance, supplier caps, no-waste orders,
%              carbon cap (hard), low-carbon share >= 35% (hard).
%              Hard constraints chosen because penalty cost >> constraint cost.

clear; clc;
DATA_DIR = fullfile(fileparts(mfilename('fullpath')), 'text and data-20260518');
load(fullfile(DATA_DIR, 'sustainable_mrp_90min_student_data.mat'));

%% 0. Unpack
T  = nTarget;    % 12 target weeks (1-based: t=1..12)
M  = 3;          % materials: 1=Al, 2=Cu, 3=Pkg
S  = 2;          % suppliers: 1=Standard, 2=LowCarbon

% Costs
cProd   = productionCost_EUR_per_unit;
cHoldF  = finishedHoldingCost_EUR_per_unit_week;
cHoldM  = materialHoldingCost_EUR_per_kg_week;
pStk    = stockoutPenalty_EUR_per_unit;
pEmerg  = emergencyMaterialPenalty_EUR_per_kg;
pCapEx  = capacityExcessPenalty_EUR_per_unit;
pCarbon = carbonPenalty_EUR_per_kg;
pLCSh   = lowCarbonSharePenalty_EUR_per_kg;
pSvcLvl = serviceLevelPenalty_EUR_per_unit;
cCap    = carbonCap_kgCO2;
minLC   = minimumLowCarbonMassShare;
minSL   = minimumServiceLevel;

% Supplier parameters (M x S)
LT   = supplierLeadTime_weeks;         % lead time in weeks
cSup = supplierCost_EUR_per_kg;
cCO2 = supplierCO2_kg_per_kg;
capS = supplierMaxWeeklyQty_kg;

a   = BOM_kg_per_unit(:);              % 3x1 kg/unit
IF0 = initialFinishedInventory_units;  % 420 units
IM0 = initialMaterialInventory_kg(:);  % 3x1 kg
cap = productionCapacity_units_per_week(:); % 12x1

fprintf('=== GROUP 20 | Sustainable MRP Challenge ===\n\n');

%% 1. DEMAND FORECAST
% 1a. Monthly seasonal index  (multiplicative model, Lez3-7 slides 27-32)
histMonths = histX(:, 2);   % column 2 = Month
histDem    = histDemand(:);
globalMean = mean(histDem);
sIdx = ones(12, 1);
for m = 1:12
    sel = histMonths == m;
    if any(sel)
        sIdx(m) = mean(histDem(sel)) / globalMean;
    end
end
fprintf('Monthly seasonal indices:\n');
fprintf('  M%02d: %.4f  ', [1:12; sIdx(:)']);
fprintf('\n\n');

% 1b. Deseasonalise historical demand
sIdxHist = sIdx(histMonths);
yDes     = histDem ./ sIdxHist;

% 1c. Fit linear model on deseasonalised demand  (Lez3-8 slide 6)
% Features: WorkingDays(3) ConfirmedOrders(4) IndustrialIndex(5)
%           EcoTenderWeek(6) SupplierRiskIndex(7)
% Dropped: WeekOfYear (collinear with Month/seasonal index)
%          PlannedMaintenance (constant 0 in training -> no info)
useF  = [3, 4, 5, 6, 7];
fLbls = {'WorkingDays','ConfirmedOrders','IndustrialIndex','EcoTenderWeek','SupplierRiskIndex'};
Xact  = histX(:, useF);
tbl   = array2table([yDes, Xact], 'VariableNames', ['yDes', fLbls]);
mdl   = fitlm(tbl, 'yDes ~ WorkingDays + ConfirmedOrders + IndustrialIndex + EcoTenderWeek + SupplierRiskIndex');

% Backward selection: drop features with p-value > 0.10 one at a time
% (Lez3-7 slide 13: avoid overfitting - von Neumann elephant principle)
changed = true;
while changed
    changed = false;
    ct = mdl.Coefficients;
    pv = ct.pValue(2:end);   % skip intercept
    vn = ct.Row(2:end);
    [maxP, idx] = max(pv);
    if maxP > 0.10
        fprintf('  Dropping "%s" (p=%.3f)\n', vn{idx}, maxP);
        remaining = setdiff(vn, vn(idx), 'stable');
        formula = ['yDes ~ ' strjoin(remaining, ' + ')];
        mdl = fitlm(tbl, formula);
        changed = true;
    end
end
fprintf('\nFinal model:\n');
disp(mdl.Coefficients);
fprintf('R-squared: %.4f\n\n', mdl.Rsquared.Ordinary);

% Extract coefficients for manual LOO and forecast
activeVars = mdl.CoefficientNames(2:end);   % exclude intercept
colIdx = zeros(1, length(activeVars));
for k = 1:length(activeVars)
    colIdx(k) = useF(strcmp(fLbls, activeVars{k}));
end
Xdes = [ones(nHist,1), histX(:, colIdx)];   % design matrix

% 1d. LOO jackknife via hat-matrix shortcut  (Lez3-7 slide 14)
% LOO error: e_loo = e / (1 - h_ii)  with H = X(X'X)^-1 X'
bOLS  = Xdes \ yDes;
H     = Xdes * ((Xdes'*Xdes) \ Xdes');
hdiag = diag(H);
yHat  = Xdes * bOLS;
eLOO  = (yDes - yHat) ./ (1 - hdiag);
yLOO  = (yHat + eLOO) .* sIdxHist;    % reseasonalised LOO predictions

% Accuracy metrics  (Lez3-7 slides 16-17)
MAD     = mean(abs(histDem - yLOO));
MAPD    = mean(abs(histDem - yLOO) ./ histDem) * 100;
MSE     = mean((histDem - yLOO).^2);
sigmaFc = std(histDem - yLOO);
SS      = ceil(1.65 * sigmaFc);        % one-sided 95% safety stock

fprintf('LOO Accuracy:  MAD=%.1f  MAPD=%.2f%%  MSE=%.0f  sigma=%.2f\n', ...
    MAD, MAPD, MSE, sigmaFc);
if MAPD <= 10
    fprintf('Quality: VERY GOOD (MAPD <= 10%%)\n');
elseif MAPD <= 20
    fprintf('Quality: GOOD\n');
else
    fprintf('Quality: REASONABLE\n');
end
fprintf('Safety stock SS = %d units\n\n', SS);

% 1e. Forecast 12 target weeks
tMon   = targetX(:, 2);
tSIdx  = sIdx(tMon);
Xtgt   = [ones(T,1), targetX(:, colIdx)];
fcDes  = Xtgt * bOLS;
demandForecast = max(0, fcDes .* tSIdx);   % 12x1 column vector

fprintf('demandForecast:\n');
fprintf('  Wk%2d: %6.1f\n', [1:T; demandForecast(:)']);
fprintf('  Sum forecast=%.0f  Sum capacity=%.0f  Gap=%.0f\n\n', ...
    sum(demandForecast), sum(cap), sum(demandForecast)-sum(cap)-IF0);

%% 2. PRODUCTION PLAN
% Produce at max capacity every week.
% Rationale: stockout penalty (180) + service-level penalty (250) = 430 EUR/unit
%            >> production cost (42) + material cost (~16 EUR/unit).
%            Capacity-constrained: total capacity + initial inventory < total forecast
%            -> produce at cap and accept minimal late-horizon stockout.
productionPlan = cap;   % 12x1

% Material requirements  R(m,t) = a(m) * p(t)
R = a * productionPlan';   % 3x12 matrix, R(m,t) kg per material per week

%% 3. PROCUREMENT LP
% Variables: q(m,s,t) [72] + IM(m,t) [36] = 108 total
% q layout: index = (t-1)*M*S + (s-1)*M + m  (1-based, m/s/t all 1-based)
% IM layout: index = nQ + (t-1)*M + m
nQ  = M * S * T;   % 72
nIM = M * T;       % 36
nV  = nQ + nIM;    % 108

% Index functions (1-based inputs, 1-based output vector index)
iQ  = @(m,s,t)  (t-1)*M*S + (s-1)*M + m;
iIM = @(m,t)    nQ + (t-1)*M + m;

% Objective: minimise purchase cost + material holding cost
f = zeros(nV, 1);
for t = 1:T
    for m = 1:M
        f(iIM(m,t)) = cHoldM;
        for s = 1:S
            f(iQ(m,s,t)) = cSup(m,s);
        end
    end
end

% Bounds
lb = zeros(nV, 1);
ub = inf(nV, 1);
for t = 1:T
    for m = 1:M
        for s = 1:S
            if t + LT(m,s) > T
                ub(iQ(m,s,t)) = 0;          % arrives past horizon: waste
            else
                ub(iQ(m,s,t)) = capS(m,s);  % supplier weekly cap
            end
        end
    end
end

% Equality: material balance
% IM(m,t) = IM(m,t-1) + incoming(t) - R(m,t)
% -> IM(m,t) - IM(m,t-1) - sum_s q(m,s, t-LT(m,s)) = -R(m,t)  [t>1]
% -> IM(m,1)              - sum_s q(m,s, 1-LT(m,s)) = IM0(m) - R(m,1)  [t=1]
nEq = M * T;
Aeq = zeros(nEq, nV);
beq = zeros(nEq, 1);
row = 0;
for t = 1:T
    for m = 1:M
        row = row + 1;
        Aeq(row, iIM(m,t)) = 1;
        if t > 1
            Aeq(row, iIM(m,t-1)) = -1;
        end
        for s = 1:S
            tau = t - LT(m,s);
            if tau >= 1
                Aeq(row, iQ(m,s,tau)) = -1;   % incoming from order at week tau
            end
        end
        % RHS: IM0 only at t=1, then -R(m,t) each week
        if t == 1
            beq(row) = IM0(m) - R(m,t);
        else
            beq(row) = -R(m,t);
        end
    end
end

% Inequalities: carbon cap + LC share
nIneq = 2;
Aineq = zeros(nIneq, nV);
bineq = zeros(nIneq, 1);

% Carbon cap: sum q(m,s,t)*cCO2(m,s) <= carbonCap
for t = 1:T
    for m = 1:M
        for s = 1:S
            Aineq(1, iQ(m,s,t)) = cCO2(m,s);
        end
    end
end
bineq(1) = cCap;

% LC share: sum_LC >= minLC * sum_all
% -> minLC * sum_all - sum_LC <= 0
for t = 1:T
    for m = 1:M
        for s = 1:S
            Aineq(2, iQ(m,s,t)) = minLC;        % +minLC for all
        end
        Aineq(2, iQ(m,2,t)) = Aineq(2, iQ(m,2,t)) - 1;  % -1 for LC (s=2)
    end
end
bineq(2) = 0;

% Solve
opts = optimoptions('linprog', 'Algorithm', 'dual-simplex', 'Display', 'off');
[xsol, fval, exitflag, output] = linprog(f, Aineq, bineq, Aeq, beq, lb, ub, opts);

fprintf('linprog: exitflag=%d  (%s)\n', exitflag, output.message);
if exitflag ~= 1
    error('LP failed. Check constraints.');
end

% Extract solution
purchaseOrderQty = zeros(T, M, S);  % T x M x S  (as required by submission)
IMsol = zeros(M, T);
for t = 1:T
    for m = 1:M
        IMsol(m,t) = xsol(iIM(m,t));
        for s = 1:S
            purchaseOrderQty(t,m,s) = xsol(iQ(m,s,t));
        end
    end
end

%% 4. RESULTS SUMMARY
fprintf('\n--- Procurement Plan ---\n');
fprintf('%-5s  %-9s  %-9s  %-9s  %-9s  %-9s  %-9s\n', ...
    'Wk','Al-Std','Al-LC','Cu-Std','Cu-LC','Pkg-Std','Pkg-LC');
for t = 1:T
    fprintf('%-5d  %-9.1f  %-9.1f  %-9.1f  %-9.1f  %-9.1f  %-9.1f\n', t, ...
        purchaseOrderQty(t,1,1), purchaseOrderQty(t,1,2), ...
        purchaseOrderQty(t,2,1), purchaseOrderQty(t,2,2), ...
        purchaseOrderQty(t,3,1), purchaseOrderQty(t,3,2));
end

totalCarbon = 0;
totalQty    = 0;
totalLCQty  = 0;
for t = 1:T
    for m = 1:M
        for s = 1:S
            totalCarbon = totalCarbon + purchaseOrderQty(t,m,s) * cCO2(m,s);
            totalQty    = totalQty    + purchaseOrderQty(t,m,s);
            if s == 2
                totalLCQty = totalLCQty + purchaseOrderQty(t,m,s);
            end
        end
    end
end
lcShare = totalLCQty / totalQty;

fprintf('\nCarbon: %.0f / %.0f kgCO2  (%.1f%% of cap)   PASS: %s\n', ...
    totalCarbon, cCap, 100*totalCarbon/cCap, yesno(totalCarbon <= cCap));
fprintf('LC share: %.3f  (min %.2f)   PASS: %s\n', ...
    lcShare, minLC, yesno(lcShare >= minLC));
fprintf('LP obj (purchase+matHold): %.2f EUR\n', fval);
fprintf('Production cost: %.2f EUR\n', sum(productionPlan)*cProd);

%% 5. FINISHED GOODS SIMULATION (vs forecast demand)
fprintf('\n--- Finished Goods Simulation (d = demandForecast) ---\n');
fprintf('%-4s  %-7s  %-7s  %-7s  %-7s  %-7s\n', 'Wk','Fc','Prod','IF','Served','Stk');
IFt = IF0;
totalServed = 0;
for t = 1:T
    IFt  = IFt + productionPlan(t);
    srv  = min(IFt, demandForecast(t));
    stk  = demandForecast(t) - srv;
    IFt  = IFt - srv;
    totalServed = totalServed + srv;
    fprintf('%-4d  %-7.0f  %-7.0f  %-7.1f  %-7.0f  %-7.0f\n', ...
        t, demandForecast(t), productionPlan(t), IFt, srv, stk);
end
sl = totalServed / sum(demandForecast);
fprintf('Service level (vs fc): %.3f  (min %.2f)   PASS: %s\n', sl, minSL, yesno(sl >= minSL));

%% 6. ESTIMATED TOTAL SCORE  (proxy: d_true = demandForecast)
[score_fc, breakdown] = simulate_score(demandForecast, productionPlan, IF0, IM0, ...
    purchaseOrderQty, a, cap, cSup, cCO2, cProd, cHoldF, cHoldM, ...
    pStk, pEmerg, pCapEx, pCarbon, pLCSh, pSvcLvl, cCap, minLC, minSL, LT);
fprintf('\n--- Estimated Score (d=forecast) ---\n');
fprintf('Purchase:       %10.2f EUR\n', breakdown.purchase);
fprintf('Production:     %10.2f EUR\n', breakdown.prod);
fprintf('Holding FG:     %10.2f EUR\n', breakdown.holdF);
fprintf('Holding Mat:    %10.2f EUR\n', breakdown.holdM);
fprintf('Stockout:       %10.2f EUR\n', breakdown.stk);
fprintf('Emergency mat:  %10.2f EUR\n', breakdown.emerg);
fprintf('Carbon penalty: %10.2f EUR\n', breakdown.carbon);
fprintf('LC share pen:   %10.2f EUR\n', breakdown.lcs);
fprintf('Service pen:    %10.2f EUR\n', breakdown.svc);
fprintf('TOTAL:          %10.2f EUR\n', score_fc);

%% 7. STRESS TEST  (d = forecast +/- sigma)
sc_hi = simulate_score(demandForecast + sigmaFc, productionPlan, IF0, IM0, ...
    purchaseOrderQty, a, cap, cSup, cCO2, cProd, cHoldF, cHoldM, ...
    pStk, pEmerg, pCapEx, pCarbon, pLCSh, pSvcLvl, cCap, minLC, minSL, LT);
sc_lo = simulate_score(demandForecast - sigmaFc, productionPlan, IF0, IM0, ...
    purchaseOrderQty, a, cap, cSup, cCO2, cProd, cHoldF, cHoldM, ...
    pStk, pEmerg, pCapEx, pCarbon, pLCSh, pSvcLvl, cCap, minLC, minSL, LT);
fprintf('\nStress test: score at d+sigma=%.2f, d-sigma=%.2f\n', sc_hi, sc_lo);

%% 8. SAVE SUBMISSION
outFile = fullfile(fileparts(mfilename('fullpath')), 'submission_Group20.mat');
save(outFile, 'demandForecast', 'productionPlan', 'purchaseOrderQty');
fprintf('\nSaved: %s\n', outFile);
info = whos('-file', outFile);
for k = 1:length(info)
    fprintf('  %-25s [%s]  %s\n', info(k).name, num2str(info(k).size), info(k).class);
end
fprintf('\nDone.\n');

% =========================================================================
%% LOCAL FUNCTIONS
% =========================================================================

function s = yesno(cond)
    if cond; s = 'YES'; else; s = 'NO'; end
end

function [score, bd] = simulate_score(d_true, p, IF0_, IM0_, q, a_, cap_, ...
        cSup_, cCO2_, cProd_, cHoldF_, cHoldM_, ...
        pStk_, pEmerg_, pCapEx_, pCarbon_, pLCSh_, pSvcLvl_, ...
        cCap_, minLC_, minSL_, LT_)
    T_  = length(p);
    M_  = length(a_);
    IFt = IF0_;
    IMt = IM0_(:);
    totalServed = 0;
    bd.purchase=0; bd.prod=0; bd.holdF=0; bd.holdM=0;
    bd.stk=0; bd.emerg=0; bd.carbon=0; bd.lcs=0; bd.svc=0;
    score = 0;
    totalCarbon=0; totalQ=0; totalLC=0;

    for t = 1:T_
        % Incoming materials
        for m = 1:M_
            for s = 1:2
                tau = t - LT_(m,s);
                if tau >= 1
                    IMt(m) = IMt(m) + q(tau,m,s);
                end
            end
        end
        % Purchase cost
        for m = 1:M_
            for s = 1:2
                v = q(t,m,s);
                bd.purchase = bd.purchase + v*cSup_(m,s);
                totalCarbon = totalCarbon + v*cCO2_(m,s);
                totalQ = totalQ + v;
                if s==2; totalLC = totalLC + v; end
            end
        end
        % Production: emergency if material short
        matNeeded = a_ * p(t);
        emg = max(0, matNeeded - IMt);
        bd.emerg = bd.emerg + sum(emg)*pEmerg_;
        IMt = max(0, IMt - matNeeded + emg);
        % Capacity excess
        if p(t) > cap_(t)
            bd.prod = bd.prod + (p(t)-cap_(t))*pCapEx_;
        end
        bd.prod = bd.prod + p(t)*cProd_;
        % Finished goods
        IFt = IFt + p(t);
        srv = min(IFt, d_true(t));
        stk = d_true(t) - srv;
        IFt = IFt - srv;
        totalServed = totalServed + srv;
        bd.stk   = bd.stk   + stk*pStk_;
        bd.holdF = bd.holdF + IFt*cHoldF_;
        bd.holdM = bd.holdM + sum(IMt)*cHoldM_;
    end
    % Service level
    sl = totalServed / sum(d_true);
    if sl < minSL_
        bd.svc = (minSL_-sl)*sum(d_true)*pSvcLvl_;
    end
    % Carbon
    if totalCarbon > cCap_
        bd.carbon = (totalCarbon-cCap_)*pCarbon_;
    end
    % LC share
    if totalQ > 0 && totalLC/totalQ < minLC_
        bd.lcs = (minLC_-totalLC/totalQ)*totalQ*pLCSh_;
    end
    score = bd.purchase+bd.prod+bd.holdF+bd.holdM+bd.stk+bd.emerg+bd.carbon+bd.lcs+bd.svc;
end
