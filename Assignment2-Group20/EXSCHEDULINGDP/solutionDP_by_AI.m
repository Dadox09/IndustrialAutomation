clear; clc;

%% 1. Problem Data
% Job IDs: 1, 2, 3, 4
n = 4;
% Alloys: Titanium (1), Aluminum (2), Titanium (3), Inconel (4)

% Precedence Matrix: Pred(p, j) = 1 means p must precede j
% Job 2 follows 1; Job 4 follows 2 and 3
Pred = zeros(n,n);
Pred(1, 2) = 1;
Pred(2, 4) = 1;
Pred(3, 4) = 1;

% Setup Energy Matrix e(i, j) 
% Rows 1-4: Jobs 1-4; Row 5: Initial Printer State
% Columns 1-4: To Jobs 1-4
e = [inf, 40,  5, 30;  % From Job 1
     35, inf, 35, 25;  % From Job 2
      5, 40, inf, 30;  % From Job 3
     20, 20, 20, inf;  % From Job 4
     10, 15, 10, 20]; % From Start (Index 5)

%% 2. Generate State Space (Subsets)
% X{k} contains subsets of size k
for k = 1:n
    X{k} = combnk(1:n, k);
end

% Go{k}(i, last_job) stores optimal cost-to-go from subset i ending in last_job
% We use a cell array for Go to handle the 'last_job' dimension easily
for k = 1:n
    Go{k} = inf(size(X{k},1), n);
end

%% 3. Backward Induction

% --- Base Case: Passo k = n (Final state) ---
% When all jobs are done, the cost-to-go is 0
for i = 1:size(X{n},1)
    for last_job = 1:n
        Go{n}(i, last_job) = 0; 
    end
end

% --- Recursion: Passo k = n-1 down to 1 ---
for k = (n-1):-1:1
    stati_curr = size(X{k}, 1);
    stati_next = size(X{k+1}, 1);
    
    for i = 1:stati_curr
        current_subset = X{k}(i,:);
        
        % Possible 'last jobs' that could have resulted in this subset
        for last_idx = 1:length(current_subset)
            last_job = current_subset(last_idx);
            
            % Try transitioning to a larger subset by adding one job
            best_cost = inf;
            for j = 1:stati_next
                next_subset = X{k+1}(j,:);
                
                % Check if next_subset is current_subset + 1 job
                if all(ismember(current_subset, next_subset))
                    job_added = setdiff(next_subset, current_subset);
                    
                    % --- PRECEDENCE CONTROL ---
                    % Check if all required predecessors of job_added are in current_subset
                    required_preds = find(Pred(:, job_added));
                    if all(ismember(required_preds, current_subset))
                        
                        % Cost = Setup(last_job -> job_added) + Cost-to-go from next state
                        cost = e(last_job, job_added) + Go{k+1}(j, job_added);
                        if cost < best_cost
                            best_cost = cost;
                        end
                    end
                end
            end
            Go{k}(i, last_job) = best_cost;
        end
    end
end

%% 4. Passo 0: Initial Job Selection
% From start state (index 5) to the first job
G0 = inf(n, 1);
for j = 1:n
    % Job j can be first only if it has no predecessors
    if isempty(find(Pred(:, j), 1))
        % Find index of subset {j} in X{1}
        idx_in_X1 = find(X{1} == j);
        G0(j) = e(5, j) + Go{1}(idx_in_X1, j);
    end
end

[min_energy, best_start_job] = min(G0);

%% 5. Display Results
fprintf('--- Optimization Results ---\n');
if min_energy < inf
    fprintf('Minimum Setup Energy: %.2f kWh\n', min_energy);
    fprintf('Optimal Start Job: Job %d\n', best_start_job);
else
    fprintf('No feasible sequence found (Constraints too tight).\n');
end