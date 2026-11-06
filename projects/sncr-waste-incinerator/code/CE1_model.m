%% ========== COURSE EXERCISE 1 - MODEL ===================================
clear
clc 

% Output folder for figures
if ~exist('img','dir'), mkdir('img'); end

%% ========== Fuel composition ============================================
% Average waste composition (mass fractions, wt%)
C_wt = (30.4/100);  % Carbon mass fraction
C_MW = 12;          % Carbon MW [g/mol]
H_wt = (4.35/100);  % Hydrogen mass fraction
H_MW = 1;           % Hydrogen MW [g/mol]
O_wt = (18.9/100);  % Oxygen mass
O_MW = 16;          % Oxygen MW [g/mol]
W_wt = (27.7/100);  % Moisture (water) mass fraction
W_MW = 18;          % Moisture (water) MW [g/mol]

lambda = 1.5;       % Global excess-air ratio

%% ========== Operating conditions ========================================
T = 900 + 273.15;   % Gas temperature [K] (assumed constant for the SNCR model)
P = 1e5;            % Pressure [Pa] (≈ 1 atm)
R = 8.314;          % Universal gas constant [J/mol-K]

%% ========== Inlet species (flue gas) ====================================
beta = 1;               % NH3/NO molar ratio at injection (β = x_NH3 / x_NO)
x_NO = 200e-6;          % NO mole fraction in flue gas (200 ppm @ ~6% O2)
x_NH3 = beta * x_NO;    % Injected NH3 mole fraction (gas-phase injection)

%% ========== Arrhenius parameters ========================================
% k = A * T^n * exp(-Ea / (R*T))
A1 = 4.2e02; n1 = 5.30; Ea1 = 350000;       % Arrhenius parameters for reaction 1
A2 = 3.5e-01; n2 = 7.65; Ea2 = 525000;      % Arrhenius parameters for reaction 2

%% ========== Rate constant ===============================================
k1 = Arrhenius(A1, n1, Ea1, R, T);           % Rate constant for reaction 1
k2 = Arrhenius(A2, n2, Ea2, R, T);           % Rate constant for reaction 2

%% ========== Stoichiometric balance ======================================
% Convert the waste composition to molar amounts per kg of fuel
m_fuel = 1000;              % [g/kg]
c = C_wt/C_MW * m_fuel;     % [mol/kg_fuel] of C atoms
h = H_wt/H_MW * m_fuel;     % [mol/kg_fuel] of H atoms
o = O_wt/O_MW * m_fuel;     % [mol/kg_fuel] of O atoms (in the fuel)
w = W_wt/W_MW * m_fuel;     % [mol/kg_fuel] of H2O (fuel moisture)

% The following C2..C5 are standard combustion bookkeeping terms:
% C2: carbon flow (for CO2)
% C3: hydrogen + moisture contribution to H2O
% C4: O2 in excess
% C5: accompanying N2 from air

C2 = c;
C3 = h/2 + w;
C4 = (lambda-1)*(c + h/4 - o/2); 
C5 = 3.76*lambda*(c + h/4 - o/2);

% Dry flue-gas O2 mol fraction from the global balance
x_O2 = C4/(C2 + C3 + C4 + C5);

%% ========== Inlet concentrations ========================================
C_tot = P/(R*T);                    % Total molar concentration at (P,T)

C_O2_0 = x_O2  * C_tot;             % O2 inlet concentration
C_NO_0 = x_NO  * C_tot;             % NO inlet concentration
C_NH3_0 = x_NH3 * C_tot;            % NH3 inlet concentration

y0 = [C_NH3_0; C_NO_0; C_O2_0];     % State vector at reactor inlet

%% ========== Transient temperature input: T(t) ===========================
excel_file = 'testing_temperature.xlsx';    % Input file with temperature fluctuations

Ttab = readtable(excel_file, 'VariableNamingRule','preserve');
time_exp = Ttab{:,1}(:);           % Time vector [s] (force column)
Texp_C = Ttab{:,2}(:);             % Temperature vector [°C] (force column)

% --- Smoothing of the measured trace -------------------------------------
apply_smoothing = true;     % Toggle smoothing on/off
smooth_win_s = 0.05;        % Moving-average window [s]

if apply_smoothing && numel(time_exp) >= 3
    dt = median(diff(time_exp));
    win_pts = max(3, round(smooth_win_s / max(dt, eps)));
    Texp_C = movmean(Texp_C, win_pts, 'Endpoints', 'shrink');
end

% --- Extract representative temperatures from the ------------------------
Tmin_C  = min(Texp_C);
Tmean_C = mean(Texp_C);
Tmax_C  = max(Texp_C);  

% --- Package cases -------------------------------------------------------
Tcases_C = [Tmin_C, Tmean_C, Tmax_C];               % [°C]
case_names = {'T_{min}','T_{mean}','T_{max}'};

% --- Report derived temperatures -----------------------------------------
fprintf('=== Derived temperatures ===\n');
fprintf('Tmin = %.1f°C, Tmean = %.1f°C, Tmax = %.1f°C\n', ...
    Tmin_C, Tmean_C, Tmax_C);

% --- Colors set-up -------------------------------------------------------
col_min = [0.0000 0.4470 0.7410];  
col_mean = [0.9290 0.6940 0.1250];  
col_max = [0.8500 0.3250 0.0980];  
cols = [col_min; col_mean; col_max];  

% --- Plot measured/smoothed trace ----------------------------------------
fig = figure('Name','Temperature T(t) vs Time',  ...
    'Units','pixels','Position',[100 100 1200 300],'Visible','on');

hold on; box on; grid on;

plt = plot(time_exp, Texp_C, 'LineWidth', 2, 'Color', [0 0.5 0]);
xlabel('Time [s]', 'Interpreter','none');
ylabel('T [°C]', 'Interpreter','none');
xlim([0 10500])
ylim([860 960])
title('Temperature T(t) vs Time', 'Interpreter','none');
hold off

drawnow;
exportgraphics(fig,'img/temperature_profile.pdf','ContentType','vector');

%% ========== Residence time study ========================================
% Estimate local residence times at different measurement locations

% --- Calibration of the image time scale (ms per spatial unit) ---
L_bar_units = 20.0;         % Measured length of the reference bar [mm]
t_bar_ms = 500.0;           % Corresponding time span [ms]
scale_ms_per_unit = t_bar_ms / L_bar_units;  

% --- Injection locations -------------------------------------------------
locNames = { ...
    'Upper OFA Left', ...
    'Mid Freeboard Right', ...
    'Upper Freeboard Right', ...
    'Throat Right' ...
    };

dist_units = [37.0, 32.0, 31.0, 10.0 ];

% --- Convert distances to residence times --------------------------------
t_res_ms = scale_ms_per_unit .* dist_units;   % [ms]
t_res_s  = t_res_ms / 1000;                   % [s]

% --- ODE solver configuration --------------------------------------------
opts = odeset('MaxStep',0.01, 'AbsTol',1e-12, 'RelTol',1e-5);

% --- Constraint for acceptable NH3 slip ----------------------------------
slip_limit_ppm = 15.0;

% --- Preallocate results structure for each temperature case -------------
Res(numel(Tcases_C)) = struct('T_C',[], 'NO_out_ppm',[], 'NH3_slip_ppm',[], ...
                              'NO_reduction',[], 't_res_s',[], ...
                              'best_id',[], 't_end',[]);

% --- Loop over temperature cases (Tmin / Tmean / Tmax) -------------------
for ic = 1:numel(Tcases_C)

    % --- Current temperature (K) ---
    T_K = Tcases_C(ic) + 273.15;

    % --- Update inlet concentrations at this temperature ---
    C_tot = P / (R * T_K);
    C_O2_0 = x_O2  * C_tot;
    C_NO_0 = x_NO  * C_tot;

    x_NH3  = beta * x_NO;                  
    C_NH3_0 = x_NH3 * C_tot;
    y0 = [C_NH3_0; C_NO_0; C_O2_0];    % Initial state vector

    % --- Temperature-dependent rate constants ---
    k1 = Arrhenius(A1, n1, Ea1, R, T_K);
    k2 = Arrhenius(A2, n2, Ea2, R, T_K);

    fprintf('\n=== Residence-time screening @ %s (T = %.1f °C) ===\n', ...
            case_names{ic}, Tcases_C(ic));

    % --- Initialize result vectors for the 4 residence times ---
    NO_out_ppm   = zeros(size(t_res_s));
    NH3_slip_ppm = zeros(size(t_res_s));
    NO_reduction = zeros(size(t_res_s));

    % --- Loop over residence times ---
    for i = 1:numel(t_res_s)
        tspan_i = [0, t_res_s(i)];

        % Integrate kinetic ODE system over current residence time
        [~, y_i] = ode15s(@(t,y) odefun_SNCR(t,y,k1,k2), tspan_i, y0, opts);

        CNH3_end = y_i(end,1);
        CNO_end  = y_i(end,2);

        % --- Compute performance metrics ---
        NO_out_ppm(i)   = (CNO_end  / C_tot) * 1e6;              % [ppm]
        NH3_slip_ppm(i) = (CNH3_end / C_tot) * 1e6;              % [ppm]
        NO_reduction(i) = (C_NO_0 - CNO_end) / C_NO_0;           % Fractional

        % --- Print per-location summary ---
        fmt = ' %-24s | t_res = %8.3f ms | NO_out = %8.3f ppm | Red = %6.3f %% | Slip = %6.5f ppm\n';
        fprintf(fmt, locNames{i}, 1e3*t_res_s(i), NO_out_ppm(i), ...
                100*NO_reduction(i), NH3_slip_ppm(i));
    end

    % --- Selection of optimal injection location ---
    feasible = NH3_slip_ppm <= slip_limit_ppm;
    if any(feasible)
        cand = find(feasible);
        [minNO,~] = min(NO_out_ppm(feasible));
        tie = cand(NO_out_ppm(feasible) == minNO);
        [~, kbest] = min(NH3_slip_ppm(tie));   % tie-breaker: lowest slip
        best_id = tie(kbest);
    else
        [~, best_id] = min(NH3_slip_ppm);      % fallback: lowest slip only
    end
    t_end = t_res_s(best_id);

    fprintf('>>> Selected location: %s  | t_end = %.3f s\n', ...
            locNames{best_id}, t_end);

    % --- Store results ---
    Res(ic).T_C          = Tcases_C(ic);
    Res(ic).NO_out_ppm   = NO_out_ppm;
    Res(ic).NH3_slip_ppm = NH3_slip_ppm;
    Res(ic).NO_reduction = 100 * NO_reduction;
    Res(ic).t_res_s      = t_res_s;
    Res(ic).best_id      = best_id;
    Res(ic).t_end        = t_end;
end

% --- Plot summary: NO reduction and NH3 slip -----------------------------
catLoc = categorical(locNames, locNames, 'Ordinal', true);
nLoc = numel(locNames);
nC   = numel(Tcases_C);

% --- Assemble matrices [nLoc × nCase] for plotting -----------------------
RED_mat  = zeros(nLoc, nC);   % NO reduction [%]
SLIP_mat = zeros(nLoc, nC);

for ic = 1:nC
    RED_mat(:,ic)  = Res(ic).NO_reduction(:);
    SLIP_mat(:,ic) = Res(ic).NH3_slip_ppm(:);
end

t_res_ms = 1e3 * Res(1).t_res_s(:);

fig = figure('Name','Injection-level screening — All T', ...
             'Units','pixels','Position',[100 100 1200 300], 'Visible','on');

tl = tiledlayout(fig,1,2,'TileSpacing','compact','Padding','compact');

% --- Plot 1: NO reduction (bar chart grouped by temperature) -------------
ax1 = nexttile(tl); hold(ax1,'on'); grid(ax1,'on'); box(ax1,'on');
B = bar(ax1, catLoc, RED_mat);

for ic = 1:nC
    B(ic).FaceColor = cols(ic,:);
    B(ic).DisplayName = sprintf('%s', case_names{ic});
end

ylabel(ax1, 'NO reduction [%]');
title(ax1, sprintf('NO reduction per location @ \\beta = %.2f', beta));
legend(ax1, 'Location','southoutside','Orientation','horizontal');

% --- Plot 2: NH3 slip (log-scale, right axis) + residence time (left) ----
ax2 = nexttile(tl); hold(ax2,'on'); grid(ax2,'on'); box(ax2,'on');

% --- Left y-axis: residence time [ms] ------------------------------------
yyaxis(ax2,'left');
h_tres = plot(ax2, catLoc, t_res_ms, '--o', 'LineWidth',1.6, ...
    'DisplayName','t_{res}', 'Color',[0 0.5 0], 'MarkerFaceColor', [0 0.5 0]);
ylabel(ax2, 'Residence time [ms]');
ax2.YAxis(1).Color = [0 0.5 0];

% --- Right y-axis: NH3 slip [ppm] (log scale) ----------------------------
nC = numel(Tcases_C);
slip_colors = zeros(nC,3);
for ic = 1:nC
    slip_colors(ic,:) = B(ic).FaceColor;
end

yyaxis(ax2,'right');
h_slip = gobjects(1,nC);
for ic = 1:nC
    h_slip(ic) = plot(ax2, catLoc, SLIP_mat(:,ic), '-s', ...
        'LineWidth',1.8, 'MarkerSize',6, ...
        'DisplayName', sprintf('%s slip', case_names{ic}), ...
        'Color', slip_colors(ic,:), 'MarkerFaceColor',slip_colors(ic,:));
end

% --- Slip limit line -----------------------------------------------------
h_limit = yline(ax2, slip_limit_ppm, ':', 'DisplayName','Slip limit', ...
                'LineWidth',2);

ax2.YAxis(2).Color = [0.2 0.2 0.2];
ax2.YAxis(2).Scale = 'log';
ax2.YAxis(2).MinorTick = 'off';

% --- Adjust log-scale limits ---------------------------------------------
ymin_data = 0.5e-5;
ymax_data = max(200, max(SLIP_mat(:)));
ax2.YAxis(2).Limits = [ymin_data, 1.5 * ymax_data];

ylabel(ax2, 'NH_3 slip [ppm]');
title(ax2, sprintf('NH3 slip per location | Slip limit = %g ppm', slip_limit_ppm));

legend(ax2, [h_tres, h_slip, h_limit], ...
       ['t_{res}', arrayfun(@(k) sprintf('%s', case_names{k}), 1:nC, 'UniformOutput', false), {'Slip limit'}], ...
       'Location','southoutside','Orientation','horizontal');

% --- Export to PDF -------------------------------------------------------
drawnow;                                       
exportgraphics(fig, 'img/injection_level.pdf', 'ContentType','vector');

% --- Summary output per temperature case ---------------------------------
fprintf('\n=== Summary over temperatures ===\n');
for ic = 1:numel(Tcases_C)
    fprintf('T = %6.1f°C | best: %-10s | t_end = %.3f s | NO_out = %8.3f ppm | Red = %4.3f %% | Slip = %.5f ppm\n', ...
        Res(ic).T_C, locNames{Res(ic).best_id}, Res(ic).t_end, ...
        Res(ic).NO_out_ppm(Res(ic).best_id), Res(ic).NO_reduction(Res(ic).best_id), ...
        Res(ic).NH3_slip_ppm(Res(ic).best_id));
end

%% ========== Parametric study: β @ T_min, T_mean, T_max ==================
% Explore the influence of the NH3/NO molar ratio on SNCR performance
% for the three characteristic temperatures: T_min, T_mean, T_max.
fprintf('\n=== Summary over temperatures (β study) ===\n');

% --- Parameter vector: NH3/NO molar ratio --------------------------------
betas = 0.50:0.005:2.00;          

% --- Preallocate result arrays -------------------------------------------
NO_out_ppm_cases   = nan(numel(Tcases_C), numel(betas));  % outlet NO [ppm]
Slip_ppm_cases     = nan(numel(Tcases_C), numel(betas));  % NH3 slip [ppm]
Red_frac_cases     = nan(numel(Tcases_C), numel(betas));  % fractional NO reduction [-]

% Optimal (star) values per temperature case
beta_star_per_case = nan(1, numel(Tcases_C));
NO_star_per_case   = nan(1, numel(Tcases_C));
Slip_star_per_case = nan(1, numel(Tcases_C));
Red_star_per_case  = nan(1, numel(Tcases_C));      % [%] NO reduction at β*

% --- Sweep over β for each temperature case ------------------------------
for ic = 1:numel(Tcases_C)

    % --- Current temperature in Kelvin ---
    T_K = Tcases_C(ic) + 273.15;

    % --- Recompute inlet concentrations at this temperature ---
    C_tot   = P / (R * T_K);
    C_NO_0  = x_NO * C_tot;
    C_O2_0  = x_O2 * C_tot;

    % --- Temperature-dependent rate constants ---
    k1 = Arrhenius(A1, n1, Ea1, R, T_K);
    k2 = Arrhenius(A2, n2, Ea2, R, T_K);

    % --- ODE function handle with fixed kinetic parameters ---
    odefun_c = @(t,y) odefun_SNCR(t,y,k1,k2);
    opts = odeset('MaxStep',0.01,'AbsTol',1e-12,'RelTol',1e-5);

    % --- Loop over β values ---
    t_end = Res(ic).t_end;
    for jb = 1:numel(betas)
        beta = betas(jb);

        % --- Initial conditions: [NH3, NO, O2] ---
        y0 = [(beta * x_NO) * C_tot; C_NO_0; C_O2_0];

        % --- ODE integration ---
        [t_run, y_run] = ode15s(odefun_c, [0 t_end], y0, opts);

        % --- Extract outlet concentrations ---
        CNH3e = y_run(end,1);
        CNOe = y_run(end,2);

        % --- Store results ---
        Red_frac_cases(ic,jb) = (C_NO_0 - CNOe) / C_NO_0;    % fractional reduction
        NO_out_ppm_cases(ic,jb) = (CNOe  / C_tot) * 1e6;     % NO_out [ppm]
        Slip_ppm_cases(ic,jb) = (CNH3e / C_tot) * 1e6;       % NH3 slip [ppm]
    end

    % --- Identify optimal β* at this temperature ---
    % Selection rule: minimize NO_out under slip ≤ limit;
    % if multiple minima, pick the one with lowest slip.
    feas = Slip_ppm_cases(ic,:) <= slip_limit_ppm;
    if any(feas)
        feas_idx = find(feas);
        [minNO,~] = min(NO_out_ppm_cases(ic,feas));
        cand = feas_idx(NO_out_ppm_cases(ic,feas) == minNO);
        [~,k] = min(Slip_ppm_cases(ic,cand));
        jbest = cand(k);
    else
        [~, jbest] = min(Slip_ppm_cases(ic,:));
    end

    % --- Store β* and corresponding metrics ---
    beta_star_per_case(ic) = betas(jbest);
    NO_star_per_case(ic) = NO_out_ppm_cases(ic,jbest);
    Slip_star_per_case(ic) = Slip_ppm_cases(ic,jbest);
    Red_star_per_case(ic) = 100 * Red_frac_cases(ic,jbest); 

    % --- Print summary line to console ---
    fprintf('%-8s (%.1f°C): β* = %.2f | NO_out* = %8.2f ppm | Red* = %.1f%% | Slip* = %8.4f ppm \n', ...
        case_names{ic}, Tcases_C(ic), beta_star_per_case(ic), ...
        NO_star_per_case(ic), Red_star_per_case(ic), Slip_star_per_case(ic));
end

% --- Plot 1: NO reduction + NH3 slip vs β --------------------------------
fig = figure('Name','β study: NO reduction & NH_3 slip at T_min, T_mean, T_max',  ...
    'Units','pixels','Position',[100 100 1200 300],'Visible','on');
tl = tiledlayout(fig,1,2,'TileSpacing','compact','Padding','compact');

% --- Panel 1: NO reduction vs β ------------------------------------------
axr = nexttile(tl); hold(axr,'on'); grid(axr,'on'); box(axr,'on');

for ic = 1:numel(Tcases_C)
    plot(betas, 100 * Red_frac_cases(ic,:), '-', ...
        'LineWidth', 1.6, 'Color', cols(ic,:), ...
        'DisplayName', sprintf('%s', case_names{ic}));
end

xlabel(axr, '\beta = NH_3/NO'); 
ylabel(axr, 'NO reduction [%]');
title(axr, 'Parametric study on \beta (NO reduction)');
legend(axr, 'Location', 'southeast');

% --- Panel 2: NH3 slip vs β (log scale) + slip limit ---------------------
axs = nexttile(tl); hold(axs,'on'); grid(axs,'on'); box(axs,'on');

for ic = 1:numel(Tcases_C)
    plot(axs, betas, Slip_ppm_cases(ic,:), '-', ...
        'LineWidth', 1.6, 'Color', cols(ic,:), ...
        'DisplayName', sprintf('%s', case_names{ic}));
end

yline(axs, slip_limit_ppm, ':', 'LineWidth', 2, 'DisplayName', 'Slip limit');
axs.YAxis.Scale  = 'log';
axs.YMinorTick = 'off';
axs.YMinorGrid = 'off';
axs.YAxis.Limits = [1e-9, 1e3];

xlabel(axs, '\beta = NH_3/NO'); 
ylabel(axs, 'NH_3 slip [ppm]');
title(axs, 'Slip constraint across \beta and temperature');
legend(axs, 'Location', 'best');

% --- Export to PDF -------------------------------------------------------
drawnow;
exportgraphics(fig,'img/beta_study.pdf','ContentType','vector');


% --- Plot 2: Optimal NO reduction* & Slip* ------------------------------- 
fig = figure('Name','Optimal NO reduction* and Slip* vs temperature case', ...
             'Units','pixels','Position',[100 100 1200 300], 'Visible','on');

tl = tiledlayout(fig,1,2,'TileSpacing','compact','Padding','compact');
tcat = categorical(case_names, case_names, 'Ordinal', true);

% --- Subplot 1 -----------------------------------------------------------
ax1 = nexttile(tl);
b1  = bar(ax1, tcat, Red_star_per_case);
b1.FaceColor = 'flat';  b1.CData = cols;
ax1.YLim = [0 82];
ylabel(ax1,'NO reduction* [%]'); grid(ax1,'on');
title(ax1,'Optimal NO reduction*');

% --- Subplot 2 -----------------------------------------------------------
ax2 = nexttile(tl);
b2  = bar(ax2, tcat, Slip_star_per_case);
b2.FaceColor = 'flat';  b2.CData = cols;
hold(ax2,'on');  yline(ax2, slip_limit_ppm, ':', 'Slip limit','LineWidth',2);
grid(ax2,'on');  ax2.YScale = 'log';  ax2.YMinorTick = 'off';  ax2.YMinorGrid = 'off';
ymin_data = min(Slip_star_per_case(Slip_star_per_case > 0));
ymax_data = max([Slip_star_per_case(:); slip_limit_ppm]);
ax2.YLim = [ymin_data/2, ymax_data*2];
ylabel(ax2,'Slip* [ppm]');  title(ax2,'Optimal Slip*');

% --- Export to PDF -------------------------------------------------------
drawnow;                                       
exportgraphics(fig, 'img/bin_optimal.pdf', 'ContentType','vector');

%% ========== β*(T) per histogram bins ====================================
% Goal:
%   - For each temperature bin (from the measured T trace), find the optimal
%     NH3/NO ratio β* at a fixed injection location and residence time.

% --- Parameters --------------------------------------------------------
nbins = 20;                 % number of histogram bins (also used for per-bin optimization)
slip_limit_ppm = 15.0;      % hard slip constraint
slip_oper_ppm = 13.0;       % operational target (stricter than hard)
betas = 0.50:0.05:2.00;

% --- Fixed location and residence time -----------------------------------
if ~exist('fixed_location_id','var') || isempty(fixed_location_id)
    fixed_location_id = Res(2).best_id;   
end

t_end_fixed = Res(2).t_res_s(fixed_location_id);
fixed_loc_name = locNames{fixed_location_id};
%fprintf('\n=== β*(T) per histogram bin ===\n');

% --- Temperature binning -------------------------------------------------
% Use the bin edges from a PDF-normalized histogram; compute per-bin probabilities
[~, edges] = histcounts(Texp_C, nbins, 'Normalization','pdf');
prob_time = histcounts(Texp_C, edges, 'Normalization','probability');  
bin_idx = find(prob_time > 0); 
nb = numel(bin_idx);

% --- Per-bin β sweep and optimal selection -------------------------------
% Result container for each populated bin
Bin = struct('Tmin',[],'Tmax',[],'Trep',[],'p',[],'beta_star',[], ...
             'NO_star',[],'Slip_star',[],'Red_star',[], ...
             'feasible',false,'betas',[],'NO_curve',[],'Slip_curve',[],'Red_curve',[]);

Bin(nb).Tmin = [];  % preallocate last field to size the struct array

opts = odeset('MaxStep',0.01,'AbsTol',1e-12,'RelTol',1e-5);
for i = 1:nb
    e = bin_idx(i);            
    Tmin_i = edges(e);
    Tmax_i = edges(e+1);

    % --- Inclusive right edge for the last valid bin ---
    is_last_valid = (i == nb);
    idx_i = Texp_C >= Tmin_i & (Texp_C < Tmax_i | (is_last_valid & Texp_C <= Tmax_i));

    % --- Representative temperature and bin probability ---
    Trep_i = median(Texp_C(idx_i));  % robust representative temperature
    p_i = prob_time(e);              % time fraction in this bin

    % --- Thermodynamics and kinetics at Trep_i ---
    T_K = Trep_i + 273.15;
    
    C_tot = P/(R*T_K);
    C_NO_0 = x_NO * C_tot;
    C_O2_0 = x_O2 * C_tot;

    k1 = Arrhenius(A1, n1, Ea1, R, T_K);
    k2 = Arrhenius(A2, n2, Ea2, R, T_K);

    odefun_c = @(t,y) odefun_SNCR(t,y,k1,k2);   

    % --- Sweep β and evaluate NO_out, Slip, and Reduction ---
    NO_vec = nan(size(betas));
    Slip_vec = nan(size(betas));
    Red_vec = nan(size(betas));

    for jb = 1:numel(betas)
        beta = betas(jb);
        y0 = [(beta*x_NO)*C_tot; C_NO_0; C_O2_0];     
        [~, y_run] = ode15s(odefun_c, [0 t_end_fixed], y0, opts);

        CNH3e = y_run(end,1);
        CNOe  = y_run(end,2);

        NO_vec(jb)   = (CNOe  / C_tot) * 1e6;         
        Slip_vec(jb) = (CNH3e / C_tot) * 1e6;         
        Red_vec(jb)  = (C_NO_0 - CNOe) / C_NO_0;      
    end

    % --- Select β* ---
    feas_op = (Slip_vec <= slip_oper_ppm);
    feas_hard = (Slip_vec <= slip_limit_ppm);

    if any(feas_op)
        cand = find(feas_op);
    elseif any(feas_hard)
        cand = find(feas_hard);
    else
        cand = [];
    end

    if ~isempty(cand)
        [minNO, kmin] = min(NO_vec(cand));
        jbest = cand(kmin);
        ties = cand(NO_vec(cand) == minNO);
        if numel(ties) > 1
            [~, kk] = min(betas(ties));
            jbest = ties(kk);
        end
        feas_flag = true;
    else
        [~, jbest] = min(Slip_vec);
        feas_flag = false;
    end

    % --- Store per-bin results and full curves ---
    Bin(i).Tmin = Tmin_i;
    Bin(i).Tmax = Tmax_i;
    Bin(i).Trep = Trep_i;
    Bin(i).p = p_i;
    Bin(i).beta_star = betas(jbest);
    Bin(i).NO_star = NO_vec(jbest);
    Bin(i).Slip_star = Slip_vec(jbest);
    Bin(i).Red_star = Red_vec(jbest);
    Bin(i).feasible = feas_flag;
    Bin(i).betas = betas;
    Bin(i).NO_curve = NO_vec;
    Bin(i).Slip_curve = Slip_vec;
    Bin(i).Red_curve = Red_vec;

    %fprintf(['Bin %2d: [%.1f, %.1f]°C (p=%.3f) | T_rep=%.1f°C | ' ...
    %         'β* = %.2f | Red* = %5.1f %% | Slip* = %6.3f ppm | %s\n'], ...
    %        i, Tmin_i, Tmax_i, p_i, Trep_i, Bin(i).beta_star, 100*Bin(i).Red_star, ...
    %        Bin(i).Slip_star, ternary_local(feas_flag,'OK','NOT OK'));
end

% --- Global metrics (policy: β*(T) per-bin) ------------------------------
% This block computes time-weighted global KPIs (Key Performance Indicators)

% --- Extract per-bin data ------------------------------------------------
p = [Bin.p].';              % time weights per bin
Red_s = [Bin.Red_star].';   % fractional reduction
SLs = [Bin.Slip_star].';    % ppm

% --- Compute time-weighted global metrics --------------------------------
E_Red = 100 * sum(p .* Red_s);                          % [%] expected NO reduction (weighted)
W_Red = 100 * min(Red_s);                               % [%] worst-case (minimum reduction)
E_Slip = sum(p .* SLs);                                 % [ppm] expected slip (weighted)
W_Slip = max(SLs);                                      % [ppm] worst-case (maximum slip)
P_viol = sum(p .* (SLs > slip_limit_ppm));     % [-] Probability that slip > limit

% --- Print summary -------------------------------------------------------
fprintf('\n=== Global, time-weighted metrics ===\n');
fprintf('E[NO reduction] = %8.1f %% | worst-case = %6.1f %%\n', E_Red, W_Red);
fprintf('E[NH3 slip] = %10.3f ppm | worst-case = %6.3f ppm (limit = %.1f)\n', E_Slip, W_Slip, slip_limit_ppm);
fprintf('P(Slip>%.1f) = %5.2f %%\n', slip_limit_ppm, 100 * P_viol);


% --- Plot1: Temperature histogram + PDF ----------------------------------
fig = figure('Name','Temperature distribution', ...
    'Units','pixels','Position',[100 100 1200 300],'Visible','on');
ax = axes('Parent',fig); hold(ax,'on'); grid(ax,'on'); box(ax,'on');
ax.YLim = [0 0.0255]; 

% Histogram (PDF-normalized)
counts_pdf = histcounts(Texp_C, edges, 'Normalization','pdf');

nb_full = numel(edges) - 1;
cmap = parula(nb_full);     
alpha_val = 0.85; 

for k = 1:nb_full
    xk = [edges(k) edges(k+1) edges(k+1) edges(k)];
    yk = [0         0         counts_pdf(k) counts_pdf(k)];
    patch('Parent',ax, 'XData',xk, 'YData',yk, ...
          'FaceColor',cmap(k,:), 'FaceAlpha',alpha_val);
end

% Smoothed PDF without toolbox
nbins_pdf = max(50, 2*nbins);
[counts_f, edges_f] = histcounts(Texp_C, nbins_pdf, 'Normalization', 'pdf');
centers_f = 0.5 * (edges_f(1:end-1) + edges_f(2:end));

w = 7;  sigma = max(1, round(w/2));                     
g = exp(-((-w:w).^2) / (2*sigma^2)); g = g/sum(g);      % Gaussian weights
counts_s = conv(counts_f, g, 'same');

x_plot = linspace(min(Texp_C), max(Texp_C), 400);
y_plot = pchip(centers_f, counts_s, x_plot);            % shape-preserving spline

plot(ax, x_plot, y_plot, '-', 'LineWidth', 2, 'Color', [0.8500 0.3250 0.0980])
xlabel(ax, 'Temperature [°C]'); ylabel(ax, 'PDF');
title(ax, sprintf('Temperature distribution'));

% Export to PDF
drawnow;
exportgraphics(fig,'img/temperature_distribution.pdf','ContentType','vector');

% --- Plot 2: β*(T) as step function --------------------------------------
fig2 = figure('Name','\beta*(T) per bin','Units','pixels','Position',[100 100 1200 300],'Visible','on');
ax2 = axes('Parent',fig2); hold(ax2,'on'); grid(ax2,'on'); box(ax2,'on');
ax2.YLim = [0.45 2.05]; 

bcent = arrayfun(@(s) 0.5*(s.Tmin + s.Tmax), Bin);      % bin centers
bstar = [Bin.beta_star];

stairs(ax2, [Bin(1).Tmin, bcent, Bin(end).Tmax], [bstar(1), bstar, bstar(end)], 'LineWidth', 2, 'Color', [0 0.4470 0.7410]);

nb_full   = numel(edges) - 1;     
cmap_full = parula(nb_full);      

for kk = 1:numel(bin_id)
    j = bin_id(kk);               
    if kk == 1
        plot(ax2, bcent(kk), bstar(kk), 'o', ...
            'MarkerSize', 6, ...
            'MarkerEdgeColor', cmap_full(j,:), ...
            'MarkerFaceColor', cmap_full(j,:), ...
            'DisplayName', 'Per-bin \beta*');  
    else
        plot(ax2, bcent(kk), bstar(kk), 'o', ...
            'MarkerSize', 6, ...
            'MarkerEdgeColor', cmap_full(j,:), ...
            'MarkerFaceColor', cmap_full(j,:), ...
            'HandleVisibility', 'off');        
    end
end



xlabel(ax2, 'Temperature [°C]'); ylabel(ax2, '\beta*');
title(ax2, sprintf('\\beta*(T) per bin'));

drawnow;
exportgraphics(fig2,'img/beta_star_per_bin.pdf','ContentType','vector');

% --- Plot 3: Per-bin bars — NO reduction* and Slip* ----------------------
fig3 = figure('Name','Per-bin NO reduction * and Slip * ','Units','pixels','Position',[100 100 1200 300],'Visible','on');
tl3  = tiledlayout(fig3,1,2,'TileSpacing','compact','Padding','compact');
tcat = categorical(compose('B%d', (1:nb).'), compose('B%d', (1:nb).'), 'Ordinal', true);
cmap = parula(nb);

% Panel 1: NO reduction* [%]
axL = nexttile(tl3); 
Red_pct = 100 * [Bin.Red_star].';
bNO = bar(axL, tcat, Red_pct); 
bNO.FaceColor = 'flat'; 
for k = 1:nb, bNO.CData(k,:) = cmap(k,:); end
ylabel(axL,'NO reduction* [%]'); 
title(axL,'Per-bin NO reduction *');
grid(axL,'on'); box(axL,'on');

% Panel 2: Slip* [ppm] (log scale) + slip limit
axr = nexttile(tl3);
SLs_col = SLs(:);
bSL = bar(axr, tcat, SLs_col);
bSL.FaceColor = 'flat';
for k = 1:nb, bSL.CData(k,:) = cmap(k,:); end
hold(axr,'on'); yline(axr, slip_limit_ppm, ':', 'Slip limit', 'LineWidth', 2);

axr.YScale = 'log';
axr.YMinorTick = 'off';
axr.YMinorGrid = 'off';

ymin_data = min(SLs_col(SLs_col > 0)); 
if isempty(ymin_data), ymin_data = 1e-6; end
ymax_data = max([SLs_col; slip_limit_ppm]);
axr.YLim = [max(ymin_data/2, 1e-6), ymax_data*2];

ylabel(axr,'NH_3 slip* [ppm]'); 
title(axr,'Per-bin Slip*');
grid(axr,'on'); box(axr,'on');

drawnow;
exportgraphics(fig3,'img/per_bin_reduction_slip.pdf','ContentType','vector');

% --- Table: per-bin optimal summary --------------------------------------
BinID = bin_idx(:);
TminC = round([Bin.Tmin].', 2);
TmaxC = round([Bin.Tmax].', 2);
TrepC = round([Bin.Trep].', 2);
p_pct = round(100 * [Bin.p].', 1);
betaStar = round([Bin.beta_star].', 2);
RedStarPC = round(100 * [Bin.Red_star].', 2);   
SlipStar = round([Bin.Slip_star].', 3);        
Feasible = [Bin.feasible].';

Table = table(BinID, TminC, TmaxC, TrepC, p_pct, betaStar, RedStarPC, SlipStar, Feasible, ...
    'VariableNames', {'Bin','Tmin_C','Tmax_C','Trep_C','p_percent','beta*','Red*','Slip*','Feasible'});

disp(' '); 
disp('=== Table — Per-bin optimal summary ===');
disp(Table);

%% ========== Piecewise and continuous β(T) from temperature bins =========
% Build a K-piece piecewise-constant β(T) policy using temperature bins. 

K = 54.27;              % number of β(T) segments 
epsilon_target = 0.00;  % allowed global violation probability 
slip_thr = 15;

apply_global_constraint = true; 

% --- Gather per-bin inputs -----------------------------------------------
bin_id = find(prob_time > 0);       % indices of non-empty bins
nb = numel(bin_id);
if nb < K
    error('Not enough non-empty bins (%d) to make %d segments.', nb, K);
end

beta_grid = Bin(1).betas(:).';      % same β grid used for all bins
nB = numel(beta_grid);

NO_bin_mat   = zeros(nb, nB);
SLIP_bin_mat = zeros(nb, nB);
RED_bin_mat  = zeros(nb, nB);    
for i = 1:nb
    NO_bin_mat(i,:)   = Bin(bin_id(i)).NO_curve(:).';
    SLIP_bin_mat(i,:) = Bin(bin_id(i)).Slip_curve(:).';
    RED_bin_mat(i,:)  = Bin(bin_id(i)).Red_curve(:).';   
end

% --- Time weights normalized over the non-empty bins ---------------------
w_bin = prob_time(bin_id).';
w_bin = w_bin / max(sum(w_bin), eps);

% --- Exhaustive search over all K–1 breakpoint combinations --------------
all_breaks = nchoosek(1:nb-1, K-1);

% --- Best feasible solution (+ NO reduction) -----------------------------
best = struct('E_NO',inf,'E_RED',-inf,'Pslip',inf,'b_idx',[], ...
    'jstars',[],'reason',"feasible");

% --- Relaxed candidate ---------------------------------------------------
best_relax = struct('E_NO',inf,'E_RED',-inf,'Pslip',inf,'b_idx',[], ...
    'jstars',[],'reason',"RELAXED — min Pslip");

for r = 1:size(all_breaks,1)
    b_idx = all_breaks(r,:);      % indices of breaks in bin space
    cuts = [0, b_idx, nb];        % segment boundaries in [1..nb]

    NOseg  = zeros(1,K);          % expected NO per segment (ppm)
    REDseg = zeros(1,K);          % expected NO reduction per segment 
    Pseg   = zeros(1,K);          % slip violation probability per segment
    jseg   = zeros(1,K);          % chosen β index per segment
    wseg   = zeros(1,K);          % segment weights (sum of bin weights)

    % --- Optimize β on each segment independently ---
    for s = 1:K
        i1 = cuts(s)+1; i2 = cuts(s+1);
        [jseg(s), NOseg(s), Pseg(s), REDseg(s)] = best_beta_for_segment( ...
    i1, i2, NO_bin_mat, SLIP_bin_mat, RED_bin_mat, ...
    w_bin, beta_grid, slip_oper_ppm, slip_limit_ppm, epsilon_target);
        wseg(s) = sum(w_bin(i1:i2));
    end

    % --- Aggregate metrics across segments ---
    E_NO_tot  = sum(wseg .* NOseg);     % ppm
    E_RED_tot = sum(wseg .* REDseg);    % fraction 0..1
    Pglob     = sum(wseg .* Pseg);      % probability

    % --- Feasibility under the chosen policy ---
    is_feasible = ~apply_global_constraint || (Pglob <= epsilon_target);

    % Keep best feasible (primary: lowest E_NO_tot; tie-break: lowest Pglob)
    if is_feasible
        if (E_NO_tot < best.E_NO) || (abs(E_NO_tot - best.E_NO) < 1e-9 && Pglob < best.Pslip)
            best.E_NO  = E_NO_tot;
            best.E_RED = E_RED_tot;
            best.Pslip = Pglob;
            best.b_idx = b_idx;
            best.jstars = jseg;
            best.reason = "feasible";
        end
    end

    % --- Keep best relaxed candidate ---
    if (Pglob < best_relax.Pslip) || (abs(Pglob - best_relax.Pslip) < 1e-9 && E_NO_tot < best_relax.E_NO)
        best_relax.E_NO  = E_NO_tot;
        best_relax.E_RED = E_RED_tot;
        best_relax.Pslip = Pglob;
        best_relax.b_idx = b_idx;
        best_relax.jstars = jseg;
    end
end

% Fallback if no combination is feasible under the global constraint
if ~isfinite(best.E_NO) || isempty(best.jstars)
    best = best_relax;
    best.reason = "RELAXED — global constraint infeasible at given ε";
end
% --- PIECEWISE (assumes optimizer just ran) ------------------------------
assert(exist('best','var') && isfield(best,'b_idx') && ~isempty(best.b_idx), ...
    'best.b_idx is missing: run the K-piece optimizer block first.');
assert(exist('best','var') && isfield(best,'jstars') && ~isempty(best.jstars), ...
    'best.jstars is missing: run the K-piece optimizer block first.');

% --- Map break indices to temperatures -----------------------------------
Tbreaks = edges( bin_id(best.b_idx) + 1 );     

% --- Segment β values ----------------------------------------------------
beta_idx = best.jstars;                         
beta_seg = beta_grid(beta_idx);                 

% --- Vectorized β(T) mapping (piecewise-constant) ------------------------
beta_piecewise = @(T) arrayfun(@(TT) beta_seg( find([TT <= Tbreaks, true], 1, 'first') ), T);

% --- CONTINUOUS β(T) -----------------------------------------------------
Trep  = reshape([Bin(bin_id).Trep],      1, []);   
betaP = reshape([Bin(bin_id).beta_star], 1, []);   

enforce_monotone = true;
smooth_lambda    = 0.15;             
beta_min         = min(beta_grid);
beta_max         = max(beta_grid);

beta_cont = make_beta_continuous( ...
    Trep, betaP, beta_min, beta_max, enforce_monotone, smooth_lambda);

% ------------- Evaluate global metrics for the continuous policy ----------
% Interpolate per-bin NO/SLIP/RED curves at β_cont(Trep_i)
nb_loc = numel(bin_id);
NOc    = zeros(nb_loc,1);
SLIPc  = zeros(nb_loc,1);
REDc   = zeros(nb_loc,1);           

for kbin = 1:nb_loc
    % --- Using the same beta grid for every bin ---
    bvec    = beta_grid(:);               
    NOvec   = NO_bin_mat(kbin,:).';       
    SLIPvec = SLIP_bin_mat(kbin,:).';     
    REDvec  = RED_bin_mat(kbin,:).';      

    beta_k = beta_cont(Trep(kbin));       

    % --- Linear interpolation along β ---
    NOc(kbin)   = interp1(bvec, NOvec,   beta_k, 'linear', 'extrap');
    SLIPc(kbin) = interp1(bvec, SLIPvec, beta_k, 'linear', 'extrap');
    REDc(kbin)  = interp1(bvec, REDvec,  beta_k, 'linear', 'extrap');
end

w_bin_loc = prob_time(bin_id).';
w_bin_loc = w_bin_loc / max(sum(w_bin_loc), eps);

thr_eval_ppm = slip_limit_ppm;   

E_NO_cont   = sum(w_bin_loc .* NOc);                            % [ppm]
E_RED_cont  = 100 * sum(w_bin_loc .* REDc);                     % [%]
Pviol_cont  = 100 * sum(w_bin_loc .* (SLIPc > thr_eval_ppm));   % [%]
E_SLIP_cont = sum(w_bin_loc .* SLIPc);                          % [ppm]
W_RED_cont  = 100 * min(REDc);                                  % [%] worst-case
W_SL_cont   = max(SLIPc);                                       % [ppm]

% --- Unified figure (2 panels) -------------------------------------------
fig = figure('Name','Temperature bins and β(T) policies','Units','pixels', ...
             'Position',[100 100 1200 320], 'Visible','on');
tl = tiledlayout(fig,1,2,'TileSpacing','compact','Padding','compact');

% --- LEFT: colored bins + red T-breaks -----------------------------------
axL = nexttile(tl); hold(axL,'on'); grid(axL,'on'); box(axL,'on');
centers_all = 0.5*(edges(1:end-1) + edges(2:end));
nb_full     = numel(edges) - 1;
cmap        = parula(nb_full);

w_plot = zeros(1, nb_full);
w_plot(bin_id) = w_bin_loc;
hb = bar(axL, centers_all, w_plot, 'FaceColor','flat', 'FaceAlpha',0.85);
for k = 1:nb_full
    hb.CData(k,:) = cmap(k,:);
end

for t = 1:numel(Tbreaks)
    xline(axL, Tbreaks(t), 'r--', 'LineWidth',1.2);
end
xlabel(axL,'Temperature [°C]');
ylabel(axL,'Time weight (w_i)');
title(axL,'Temperature distribution and K-piece breaks');

% --- RIGHT: per-bin markers, piecewise, continuous -----------------------
axR = nexttile(tl); hold(axR,'on'); grid(axR,'on'); box(axR,'on');

for k = 1:numel(bin_id)
    if k == 1
        plot(axR, Trep(k), betaP(k), 'o', ...
            'MarkerSize', 6, ...
            'MarkerEdgeColor', cmap(bin_id(k),:), ...
            'MarkerFaceColor', cmap(bin_id(k),:), ...
            'DisplayName', 'Per-bin β*');  
    else
        plot(axR, Trep(k), betaP(k), 'o', ...
            'MarkerSize', 6, ...
            'MarkerEdgeColor', cmap(bin_id(k),:), ...
            'MarkerFaceColor', cmap(bin_id(k),:), ...
            'HandleVisibility', 'off');     
    end
end

xmin = min([Bin.Tmin]); xmax = max([Bin.Tmax]);
x_stairs = [xmin, Tbreaks, xmax];
y_stairs = [beta_seg, beta_seg(end)];
stairs(axR, x_stairs, y_stairs, 'LineWidth', 2, ...
       'Color', [0.8500 0.3250 0.0980], 'DisplayName','β(T) piecewise');

TT_plot = linspace(xmin, xmax, 800);
plot(axR, TT_plot, beta_cont(TT_plot), 'LineWidth', 2, ...
     'Color', [0.70 0.50 0.90], 'DisplayName','β(T) continuous');

xlabel(axR,'Temperature [°C]');
ylabel(axR,'\beta(T)');
title(axR,'Piecewise vs Continuous β(T)');
legend(axR, 'Location','best');

drawnow;
exportgraphics(fig,'img/beta_policies.pdf','ContentType','vector');

% --- LOGS ----------------------------------------------------------------
fprintf('\n=== K-piece β(T) from bins ===\n');
fprintf('K = %d | constraint = %s | status = %s\n', K, ...
    ternary_local(apply_global_constraint,'GLOBAL','PER-SEGMENT'), char(best.reason));
fprintf('Breaks T [°C] = %s\n', mat2str(round(Tbreaks,1)));
fprintf('Betas (segments) = %s\n', mat2str(round(beta_seg,3)));
fprintf('E[NO_out] = %.1f ppm | E[NO_red] = %.1f %% | P(slip>%.1f) = %.2f %%\n', ...
        best.E_NO, 100*best.E_RED, slip_limit_ppm, 100*best.Pslip);

thr_dbg = slip_limit_ppm;
cuts = [0, best.b_idx, numel(bin_id)];
viol_pw = false(numel(bin_id),1);
for s = 1:K
    ii = (cuts(s)+1):cuts(s+1);
    viol_pw(ii) = SLIP_bin_mat(ii, best.jstars(s)) > thr_dbg;
end
fprintf('K-piece: bins above %.1f ppm: %s | Sum weights = %.3f %%\n', ...
        thr_dbg, mat2str(find(viol_pw)), 100*sum(w_bin_loc(viol_pw)));

fprintf('\n=== Continuous β(T) from per-bin β* ===\n');
fprintf('Smooth λ = %.2f | monotone = %d | thr = %.1f ppm\n', smooth_lambda, enforce_monotone, thr_eval_ppm);
fprintf('E[NO_out] = %.1f ppm | E[NO_red] = %.1f %% | P(slip>%.1f) = %.2f %%\n', ...
        E_NO_cont, E_RED_cont, thr_eval_ppm, Pviol_cont);
fprintf('E[Slip] = %.3f ppm | worst Red = %.1f %% | worst Slip = %.3f ppm\n', ...
        E_SLIP_cont, W_RED_cont, W_SL_cont);

viol_ct = SLIPc > thr_eval_ppm;
fprintf('Continuous: bins above %.1f ppm: %s | Sum weights = %.3f %%\n', ...
        thr_eval_ppm, mat2str(find(viol_ct)), 100*sum(w_bin_loc(viol_ct)));

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

% --- Local helper --------------------------------------------------------
function out = ternary_local(cond, a, b)
    if cond, out = a; else, out = b; end
end

% ---------- Helper function: find optimal β for a bin segment ------------
function [jstar, NOexp_seg, Pslip_seg, REDexp_seg] = best_beta_for_segment( ...
            i1, i2, NO_mat, SL_mat, RED_mat, w_vec, beta_grid, slip_oper, slip_limit, eps_seg)

    idx  = i1:i2;
    wloc = w_vec(idx);
    wloc = wloc / max(sum(wloc), eps);   

    nB = numel(beta_grid);
    NOexp_j   = zeros(1,nB);
    Pslip13_j = zeros(1,nB);
    Pslip15_j = zeros(1,nB);
    REDexp_j  = zeros(1,nB);
    SLexp_j   = zeros(1,nB);

    for j = 1:nB
        NOexp_j(j)   = sum(wloc .* NO_mat(idx,j));
        Pslip13_j(j) = sum(wloc .* (SL_mat(idx,j) > slip_oper));  
        Pslip15_j(j) = sum(wloc .* (SL_mat(idx,j) > slip_limit)); 
        REDexp_j(j)  = sum(wloc .* RED_mat(idx,j));
        SLexp_j(j)   = sum(wloc .* SL_mat(idx,j));                
    end

    if any(Pslip13_j <= eps_seg)
        % 1) β with slip ≤13
        feas = Pslip13_j <= eps_seg;
        NOmin = min(NOexp_j(feas));
        cand  = find(feas & abs(NOexp_j - NOmin) < 1e-12);
        [~,k] = min(beta_grid(cand));  
        jstar = cand(k);

    elseif any(Pslip15_j <= eps_seg)
        % 2) β with slip ≤15
        feas = Pslip15_j <= eps_seg;
        NOmin = min(NOexp_j(feas));
        cand  = find(feas & abs(NOexp_j - NOmin) < 1e-12);
        [~,k] = min(beta_grid(cand));
        jstar = cand(k);

    else
        % 3) no-one feasible - slip min
        SLmin = min(SLexp_j);
        cand  = find(abs(SLexp_j - SLmin) < 1e-12);
        NOmin = min(NOexp_j(cand));
        cand  = cand(abs(NOexp_j(cand) - NOmin) < 1e-12);
        [~,k] = min(beta_grid(cand));
        jstar = cand(k);
    end

    % --- output ---
    NOexp_seg  = NOexp_j(jstar);
    Pslip_seg  = Pslip15_j(jstar);    
    REDexp_seg = REDexp_j(jstar);
end

% ---------- Helper function: continuous β --------------------------------
function beta_fun = make_beta_continuous(Trep, betaP, beta_min, beta_max, enforce_monotone, smooth_lambda)
    if nargin < 5 || isempty(enforce_monotone), enforce_monotone = true; end
    if nargin < 6 || isempty(smooth_lambda),    smooth_lambda    = 0.15; end

    Trep  = Trep(:).';    % ensure row
    betaP = betaP(:).';   % ensure row

    % 1) Optional monotonic pass (isotonic regression, non-decreasing)
    beta_use = betaP;
    if enforce_monotone
        beta_use = pav_isotonic(beta_use);  % equal weights
    end

    % 2) Base interpolant (PCHIP) in T
    Tmin = min(Trep); Tmax = max(Trep);
    base_pchip = @(TT) pchip(Trep, beta_use, TT);

    % 3) Optional smoothing on a fine T-grid (moving average, no toolbox)
    if smooth_lambda > 0
        TT = linspace(Tmin, Tmax, 400);
        beta_raw = base_pchip(TT);
        span = max(3, round(numel(TT) * smooth_lambda * 0.3));
        beta_s = smoothdata(beta_raw, 'movmean', span);
        smooth_fun = @(TTq) interp1(TT, beta_s, TTq, 'pchip', 'extrap');
    else
        smooth_fun = base_pchip;
    end

    % 4) Clamp to admissible β range and return handle
    beta_fun = @(TTq) min(max(smooth_fun(TTq), beta_min), beta_max);
end

% ---------- Helper functio -----------------------------------------------
function y_iso = pav_isotonic(y, w)
    y = y(:);                      
    n = numel(y);
    if nargin < 2 || isempty(w)
        w = ones(n,1);
    else
        w = w(:);
    end

    % Initialize each sample as its own block
    lvl = y;                       % block levels (means)
    wt  = w;                       % block weights
    idx = (1:n)';                  % block start indices
    k   = 1;                       % current number of blocks

    for i = 2:n
        k = k + 1;
        lvl(k) = y(i);
        wt(k)  = w(i);
        idx(k) = i;

        % Pool while violating monotonicity
        while k > 1 && (lvl(k-1) > lvl(k))
            new_w   = wt(k-1) + wt(k);
            new_lvl = (wt(k-1)*lvl(k-1) + wt(k)*lvl(k)) / max(new_w, eps);

            wt(k-1)  = new_w;
            lvl(k-1) = new_lvl;

            wt(k)  = [];
            lvl(k) = [];
            idx(k) = [];
            k = k - 1;
        end
    end

    % Expand block levels back to all points
    y_iso = zeros(n,1);
    for b = 1:k
        j1 = idx(b);
        if b < k
            j2 = idx(b+1) - 1;   
        else
            j2 = n;
        end
        y_iso(j1:j2) = lvl(b);
    end

    % Return in same orientation as input
    if isrow(y)
        y_iso = y_iso.';
    end
end
