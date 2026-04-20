%% TASK 5 - EQUILIBRIUM POINT AND LINEARIZATION
clear; clc;

init; 

% 1. Define Symbolic Variables
syms Ta Tp Sb ur uf ub Te Qp real

% 2. State Equations (Nonlinear) 
% f1: Derivative of Ta (Air temperature)
f1 = (sec2hour/Ca) * (ke*(Te - Ta) - kr*ur - kf*(1 + alpha_f*uf)*(Ta - Tp) + Qp);

% f2: Derivative of Tp (Product temperature)
f2 = (sec2hour/Cp) * (kf*(1 + alpha_f*uf)*(Ta - Tp));

% f3: Derivative of Sb (Battery state of charge)
% NOTE: The max() function is not differentiable at exactly zero. 
% To compute the Jacobian matrix, we approximate the battery dynamics 
% with a linear continuous function around ub = 0 (assuming eta_b ~= 1).
f3 = -(1/Eb) * ub;

f = [f1; f2; f3];
x = [Ta; Tp; Sb];
u = [ur; uf; ub];
d = [Te; Qp];

% Outputs
y = [Ta; Tp; Sb]; 

% 3. Symbolic Computation of Jacobians
disp('Calculating symbolic Jacobian matrices...');
A_sym = jacobian(f, x);
B_sym = jacobian(f, u);
E_sym = jacobian(f, d);
C_sym = jacobian(y, x);
D_sym = jacobian(y, u);

% 4. Definition of the Equilibrium Point 
% We use representative average values based on the assigned recipe
Ta_eq = 5;      % [°C] Average air temperature target 
Tp_eq = 5;      % [°C] Final product temperature target 
Sb_eq = 0.60;   % [p.u.] Nominal battery state of charge 
Te_eq = 24;     % [°C] Average external temperature 
Qp_eq = 500;    % [W] Representative average thermal load 
uf_eq = 0.5;    % [p.u.] Fan speed fixed at 50%
ub_eq = 0.0;    % [kW] Battery at rest (no charge/discharge)

% Automatic calculation of ur_eq to maintain thermal equilibrium (forcing f1 = 0)
ur_eq = (ke*(Te_eq - Ta_eq) + Qp_eq) / kr;

disp('--- EQUILIBRIUM POINT ---');
fprintf('x* = [%.2f; %.2f; %.2f]\n', Ta_eq, Tp_eq, Sb_eq);
fprintf('d* = [%.2f; %.2f]\n', Te_eq, Qp_eq);
fprintf('u* = [%.4f; %.2f; %.2f]\n\n', ur_eq, uf_eq, ub_eq);

% 5. Numerical Substitution to obtain the Linearized Matrices 
A = double(subs(A_sym, [Ta, Tp, uf], [Ta_eq, Tp_eq, uf_eq]));
B = double(subs(B_sym, [Ta, Tp, uf], [Ta_eq, Tp_eq, uf_eq]));
E = double(subs(E_sym, [Ta, Tp, uf], [Ta_eq, Tp_eq, uf_eq]));
C = double(C_sym); 
D = double(D_sym); 

disp('--- LINEARIZED SYSTEM MATRICES ---');
disp('Matrix A:'); disp(A);
disp('Matrix B:'); disp(B);
disp('Matrix C:'); disp(C);
disp('Matrix D:'); disp(D);
disp('Matrix E (Disturbances):'); disp(E);


%% TASK 6 - DISCRETIZATION OF THE LINEARIZED MODEL

% Per usare c2d, uniamo gli ingressi di controllo (u) e i disturbi (d) in un'unica 
% grande matrice degli ingressi estesa.
B_ext = [B, E]; 
D_ext = [D, zeros(3, 2)]; % Aggiungiamo zeri per le dimensioni dei disturbi

% Creiamo il modello di stato continuo
sys_c = ss(A, B_ext, C, D_ext);

% Discretizzazione esatta con mantenitore di ordine zero (ZOH) [cite: 202-204]
sys_d = c2d(sys_c, Ts, 'zoh');

% Estraiamo le matrici discrete
Ad = sys_d.A;
Bd_ext = sys_d.B;
Cd = sys_d.C;
Dd_ext = sys_d.D;

% Separiamo di nuovo i controlli (Bd) dai disturbi (Ed)
Bd = Bd_ext(:, 1:3);
Ed = Bd_ext(:, 4:5);
Dd = Dd_ext(:, 1:3);

disp('--- MATRICI DEL SISTEMA DISCRETO LINEARIZZATO (Task 6) ---');
disp('Matrice Ad:'); disp(Ad);
disp('Matrice Bd:'); disp(Bd);
disp('Matrice Cd:'); disp(Cd);
disp('Matrice Dd:'); disp(Dd);
disp('Matrice Ed (Disturbi):'); disp(Ed);