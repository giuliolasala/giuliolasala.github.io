%% ========== COURSE EXERCISE 1 - MODEL VALIDATION ========================
clear
clc 

%% ========== Operating conditions ========================================
P = 1e5;            % Pressure [Pa] (≈ 1 atm)
R = 8.314;          % Universal gas constant [J/mol-K]


%% ========== Inlet species ===============================================
x_O2 = 4/100;               % O2 mole fraction
x_NO = 507*10^-6;           % NO mole fraction

%% ========== Arrhenius parameters ========================================
% k = A * T^n * exp(-Ea / (R*T))
A1 = 4.2e02; n1 = 5.30; Ea1 = 350000;   % Arrhenius parameters for reaction 1
A2 = 3.5e-01; n2 = 7.65; Ea2 = 525000;  % Arrhenius parameters for reaction 2

%% ========== ODE solver ==================================================

% --- ODE solver options --------------------------------------------------
options = odeset('MaxStep',0.01,'AbsTol',1e-16,'RelTol',1e-4);

% --- Parameter grids -----------------------------------------------------
Tgrid = 1000:25:1500;       % Temperature grid [K] for the sweep
Betas = [0.5, 1.0, 2.06];   % β = NH3/NO molar ratios to compare 
NO_ppm = zeros(numel(Betas), numel(Tgrid));   

% Residence time for validation: 80 ms
t_end = 0.08;                       
tspan = 0:0.0001:t_end;             

% --- Sweep over beta and T -----------------------------------------------
for ib = 1:numel(Betas)
    beta = Betas(ib);
    x_NH3 = beta * x_NO;            % Injected NH3 mole fraction
    
    for iT = 1:numel(Tgrid)
        T = Tgrid(iT);              % Current temperature [K]
        
        % --- Temperature-dependent rate constants ---
        k1 = Arrhenius(A1, n1, Ea1, R, T);           
        k2 = Arrhenius(A2, n2, Ea2, R, T);           

        % --- Inlet concentrations ---
        Ctot = P/(R*T);

        C_O2_0 = x_O2 * Ctot;
        C_NO_0 = x_NO * Ctot;
        C_NH3_0 = x_NH3 * Ctot;

        y0 = [C_NH3_0; C_NO_0; C_O2_0];   % State vector at inlet
        
        % --- ODE integration --- 
        [~, y] = ode15s(@(t,y) odefun_SNCR(t,y,k1,k2), tspan, y0, options);
        
        % --- Output ---
        CNO_end = y(end,2);
        xNO_out = CNO_end / Ctot;
        NO_ppm(ib,iT) = xNO_out * 1e6;  
    end
end

%%  ========== Final plot =================================================
figure; hold on; grid on
markers = {'s','o','d'};
for ib = 1:numel(Betas)
    scatter(Tgrid, NO_ppm(ib,:), 60, markers{ib}, 'filled')
end

xline(1135.3, 'r--', 'LineWidth', 1.2);
xline(1232.0, 'r--', 'LineWidth', 1.2);

xlabel('Temperature [K]')
ylabel('NO [ppmv]')
legend(arrayfun(@(b) sprintf('\\beta = %.2f', b), Betas, 'UniformOutput', false))
title('SNCR model – NO vs Temperature')

%% ========== Function & model ============================================
% --- Arrhenius rate constant ---------------------------------------------
function k = Arrhenius(A, n, Ea, R, T)
    k = A * T^n * exp(-Ea / (R*T));
end

% --- ODE function --------------------------------------------------------
% Isothermal, perfectly mixed cross-section, plug-flow approximation.

% Reaction scheme (simplified):
%   (1) NH3 + NO  -> N2 + products      rate = k1 * [NH3]*[NO]
%   (2) NH3 + O2  -> NO + products      rate = k2 * [NH3]*[O2]

% Mass balances:
%   d[NH3]/dt = -r1 - r2
%   d[NO]/dt  = -r1 + r2
%   d[O2]/dt  = -r2

function dydt = odefun_SNCR(~, y, k1, k2)
    CNH3 = y(1);
    CNO  = y(2);
    C_O2  = y(3);

    r1 = k1 * CNH3 * CNO;  
    r2 = k2 * CNH3 * C_O2;  

    dNH3 = -r1 - r2; 
    dCNO = -r1 + r2;
    d_CO2 = -r2;

    dydt = [dNH3; dCNO; d_CO2];
end