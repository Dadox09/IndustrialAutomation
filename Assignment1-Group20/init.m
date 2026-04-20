%% PARAMETERS INITIALIZATION 
clear; clc;

%% 1. Thermal Parameters
Ca = 1.5e5;        % [J/°C] Effective thermal capacity of chamber air 
Cp = 8.0e5;        % [J/°C] Effective thermal capacity of the stored product 
Uw = 3.8;          % [W/(m^2 °C)] Wall heat-transmission coefficient 
Aw = 70;           % [m^2] Equivalent wall exchange area 
kr = 1.6e4;        % [W] Nominal refrigeration gain 
kf = 450;          % [W/°C] Fan-enhanced air-product heat-transfer coefficient 
ke = Uw * Aw;      % [W/°C] Ambient thermal disturbance coefficient 

alpha_f = 1.0;

%% 2. Electrical Parameters
Eb = 18;           % [kWh] Battery energy capacity 
eta_b = 0.94;      % Battery charge/discharge efficiency 
Pf = 1.5;          % [kW] Nominal fan electrical power 
Pr = 7.0;          % [kW] Nominal refrigeration electrical power

%% 3. Disturbance Parameters (Solar & PV)
Rmax = 850;        % [W/m^2] Max solar radiation
tsr = 6;           % [h] Time of sunrise 
tss = 18;          % [h] Time of sunset
Pmax = 9.0;        % [kW] Max PV electrical power 

%% 4. Initial Conditions and References
Ta_0 = 10.0;       % [°C] Initial chamber air temperature 
Tp_0 = 11.5;       % [°C] Initial product temperature 
Sb_0 = 0.55;       % [p.u.] Initial battery state of charge 

Sb_nom = 0.60;     % [p.u.] Nominal battery state of charge 

%% 5. Simulation Parameters
T_sim = 24;        % [h] Simulation time horizon 
Ts = 0.1;          % [h] Initial sampling time TASK 3

%% 6. TIME CONVERSION FACTOR (CRITICAL FOR SIMULINK)
sec2hour = 3600;   % [s/h] Conversion factor from seconds to hours