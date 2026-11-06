clear
clc

%% === 1. INPUT DATA
% Gas conditions (assumed uniform)
T = 1200 + 273.15;      % Bulk gas temperature [K]
P = 1e5;                % Gas pressure [Pa] (≈ 1 atm)
R = 8.314;              % Universal gas constant [J/mol-K]

% Thermal power & reactor geometry
Qth_MW    = 33;         % Reactor thermal power [MW_th]
LHV_MJkg  = 16.3;       % Fuel lower heating value [MJ/kg_fuel]
W_reactor = 4.3;        % Reactor width [m]
L_reactor = 5.3;        % Reactor length [m]
A_cs      = W_reactor * L_reactor;  % Freeboard cross-sectional area [m^2]

% Fuel composition (mass fractions, wt% of wet fuel) 
C_wt = 47.3/100;        % Carbon mass fraction [-]
H_wt = 7.8/100;         % Hydrogen mass fraction [-]
O_wt = 44/100;          % Oxygen mass fraction [-]
W_wt = 10/100;          % Moisture (water) mass fraction [-]

% Atomic / molecular weights [g/mol] 
C_MW = 12;              % Carbon atomic weight [g/mol]
H_MW = 1;               % Hydrogen atomic weight [g/mol]
O_MW = 16;              % Oxygen atomic weight [g/mol]
N_MW = 14;              % Nitrogen atomic weight [g/mol]
W_MW = 2*H_MW + O_MW;   % Water (H2O) molecular weight [g/mol]

CO2_MW = C_MW + 2*O_MW; % CO2 molecular weight [g/mol]
O2_MW  = 2*O_MW;        % O2 molecular weight [g/mol]
N2_MW  = 2*N_MW;        % N2 molecular weight [g/mol]

% Combustion control parameter 
lambda = 1.4;           % Global excess-air ratio [-]

% Paths for output images and data 
dir_path = 'img';
if ~exist(dir_path,'dir'), mkdir(dir_path); end

%% === 2. STOICHIOMETRIC BALANCE
% All quantities in this section are expressed per kg of (wet) fuel

m_fuel = 1000;          % Reference fuel mass [g/kg_fuel]
m_dry  = 900;           % Dry fraction of the fuel [g/kg_fuel]

% Element and species moles in the fuel (per kg_fuel)
c = C_wt/C_MW * m_dry;   % Moles of C atoms [mol/kg_fuel]
h = H_wt/H_MW * m_dry;   % Moles of H atoms [mol/kg_fuel]
o = O_wt/O_MW * m_dry;   % Moles of O atoms (in dry fuel) [mol/kg_fuel]
w = W_wt/W_MW * m_fuel;  % Moles of H2O from fuel moisture [mol/kg_fuel]

% Stoichiometric O2 requirement (C–H–O fuel, neglecting S, N) 
nO2_st = c + h/4 - o/2;      % Stoichiometric O2 [mol O2/kg_fuel]

% Actual O2 and N2 supplied with excess air 
nO2_in = lambda * nO2_st;    % Actual O2 feed [mol O2/kg_fuel]
nN2_in = 3.76 * nO2_in;      % N2 from air (molar ratio N2/O2 ≈ 3.76) [mol/kg_fuel]

% Product moles (global, idealized combustion, no NOx/SOx)
nCO2   = c;                  % CO2 moles [mol/kg_fuel]
nH2O   = h/2 + w;            % Total H2O (from fuel H and moisture) [mol/kg_fuel]
nO2_ex = nO2_in - nO2_st;    % Excess O2 in flue gas [mol/kg_fuel]
nN2    = nN2_in;             % N2 in flue gas [mol/kg_fuel]

% Stoichiometric and actual air (O2 + N2) 
n_air_min = nO2_st / 0.21;   % Stoichiometric air at lambda = 1 [mol air/kg_fuel]
n_air     = n_air_min * lambda;  % Actual air moles [mol air/kg_fuel]

% Total moles in the (wet) flue gas 
n_tot_wet = nCO2 + nH2O + nO2_ex + nN2;

% Flue gas molar composition (wet basis)
xCO2 = nCO2   / n_tot_wet;   % CO2 mole fraction [-]
xH2O = nH2O   / n_tot_wet;   % H2O mole fraction [-]
xO2  = nO2_ex / n_tot_wet;   % O2 mole fraction [-]
xN2  = nN2    / n_tot_wet;   % N2 mole fraction [-]

% Effective molar mass of flue gas (for density calculation)
MW_flue = (xCO2 * CO2_MW + ...
           xH2O * W_MW   + ...
           xO2  * O2_MW  + ...
           xN2  * N2_MW) / 1000;   % Effective flue-gas MW [kg/mol]

%% === 3. FUEL MASS FLOW & GAS FLOW

% Fuel mass flow rate from thermal power
Qth_W   = Qth_MW * 1e6;       % Thermal power [W]
LHV_Jkg = LHV_MJkg * 1e6;     % Lower heating value [J/kg_fuel]
m_dot_fuel = Qth_W / LHV_Jkg; % Fuel mass flow rate [kg_fuel/s]

% Air molar flow rate (based on global stoichiometry)
n_dot_air = n_air * m_dot_fuel;      % Air molar flow rate [mol_air/s]

% Flue gas molar flow rate
n_dot_flue = n_tot_wet * m_dot_fuel; % Flue gas molar flow rate [mol/s]

% Volumetric flow rate of incoming air (ideal gas)
Vdot_air = n_dot_air * R * T / P;    % Air volumetric flow rate [m^3/s]

% Volumetric flow rate of flue gas (ideal gas)
Vdot_flue  = n_dot_flue * R * T / P; % Flue gas volumetric flow rate [m^3/s]

% Superficial gas velocity in the reactor
U = Vdot_air / A_cs;                 % Superficial gas velocity [m/s]
% Alternative choice (if using flue gas): U = Vdot_flue / A_cs;

% Gas density (ideal gas, using flue-gas MW)
rho_g = P * MW_flue / (R * T);       % Gas density [kg/m^3]

%% === 4. PARTICLE & FLUID PROPERTIES

g     = 9.81;       % Gravitational acceleration [m/s^2]
rho_p = 500;        % Char particle density [kg/m^3]
mu_g  = 50e-6;      % Gas dynamic viscosity [Pa·s], assumed constant

% Particle size range (radius and diameter)
r_min = 0;          % Minimum particle radius [m]
r_max = 600e-6;     % Maximum particle radius [m]
Npts  = 500;        % Number of points in radius grid
r = linspace(r_min, r_max, Npts);   % Radius vector [m]
d = 2 * r;                          % Corresponding diameters [m]

%% === 5. FORCES ON THE PARTICLE

% --- 5.1 Gravitational force (weight, neglecting buoyancy) ---
V_p = (4/3) * pi .* r.^3;      % Particle volume [m^3]
F_g = V_p .* rho_p * g;        % Gravitational force [N]

% --- 5.2 Stokes drag (creeping flow, Re << 1) ---
F_stokes = 6 * pi * mu_g .* r .* U;   % Stokes drag force [N]

% --- 5.3 Schiller–Naumann drag (valid for general Re) ---
Re_p = rho_g .* U .* d ./ mu_g;       % Particle Reynolds number [-]
Cd_SN = 24 ./ Re_p .* (1 + 0.15 .* Re_p.^0.687);  % Drag coefficient [-]
Cd_SN(Re_p == 0) = 0;                 % Avoid division-by-zero at r = 0

A_p = pi .* d.^2 / 4;                 % Projected area [m^2]
F_SN = 0.5 .* Cd_SN .* rho_g .* U.^2 .* A_p;   % Schiller–Naumann drag [N]

% --- 5.4 Intersections ---
% Intersection between gravitational force and Stokes drag
diff_stokes = F_stokes - F_g;   % Sign change indicates equilibrium point

% Use a strict sign change to avoid the trivial root at r = 0
idx_s = find(diff_stokes(1:end-1) .* diff_stokes(2:end) < 0, 1, 'first');

if ~isempty(idx_s)
    % Linear interpolation to estimate r such that F_stokes = F_g
    r_eq_stokes = interp1( ...
        diff_stokes(idx_s:idx_s+1), ...
        r(idx_s:idx_s+1), ...
        0 ...
    );
    d_eq_stokes = 2 * r_eq_stokes;

    % Force at equilibrium (weight = drag)
    V_p_eq_s   = (4/3) * pi * r_eq_stokes^3;
    F_eq_s     = V_p_eq_s * rho_p * g;   % F_g = F_stokes at equilibrium
else
    r_eq_stokes = NaN;
    d_eq_stokes = NaN;
    F_eq_s      = NaN;
end

% Intersection between gravitational force and Schiller–Naumann drag
diff_SN = F_SN - F_g;
idx_sn = find(diff_SN(1:end-1) .* diff_SN(2:end) < 0, 1, 'first');

if ~isempty(idx_sn)
    % Linear interpolation to estimate r such that F_SN = F_g
    r_eq_SN = interp1( ...
        diff_SN(idx_sn:idx_sn+1), ...
        r(idx_sn:idx_sn+1), ...
        0 ...
    );
    d_eq_SN = 2 * r_eq_SN;

    V_p_eq_sn = (4/3) * pi * r_eq_SN^3;
    F_eq_sn   = V_p_eq_sn * rho_p * g;   % F_g = F_SN at equilibrium
else
    r_eq_SN = NaN;
    d_eq_SN = NaN;
    F_eq_sn = NaN;
end

% Print superficial gas velocity and equilibrium diameters
fprintf('Superficial gas velocity U = %.3f m/s\n', U);

if ~isnan(d_eq_stokes)
    fprintf('Equilibrium diameter (weight = Stokes drag): %.2f µm\n', ...
        d_eq_stokes * 1e6);
else
    fprintf(['No intersection found between weight and Stokes drag ', ...
             'in the radius range.\n']);
end

if ~isnan(d_eq_SN)
    fprintf('Equilibrium diameter (weight = Schiller-Naumann drag): %.2f µm\n', ...
        d_eq_SN * 1e6);
else
    fprintf(['No intersection found between weight and Schiller-Naumann drag ', ...
             'in the radius range.\n']);
end

% --- 5.5 Plot: force vs particle radius ---
fig = figure('Units','pixels', ...
    'Position',[100 100 1200 300], ...
    'Visible','on');

% Force curves as a function of particle radius
p1 = plot(r*1e6, F_g,      'LineWidth', 1.5); hold on;
p2 = plot(r*1e6, F_stokes, 'LineWidth', 1.5);
p3 = plot(r*1e6, F_SN,     'LineWidth', 1.5);

% Collect line handles and base legend labels
h_legend = [p1 p2 p3];
leg_labels = { ...
    'Weight (gravity - buoyancy)', ...
    'Stokes drag', ...
    'Schiller-Naumann drag'};

% Markers at equilibrium radii (if intersections exist) 
if ~isnan(r_eq_stokes)
    ms = plot(r_eq_stokes*1e6, F_eq_s, 'o', ...
        'MarkerSize', 8, ...
        'LineWidth', 1.2);          % Slight border around the marker
    ms.MarkerFaceColor = ms.Color;  % Filled marker

    h_legend(end+1) = ms;
    leg_labels{end+1} = 'Stokes = weight';
end

if ~isnan(r_eq_SN)
    mn = plot(r_eq_SN*1e6, F_eq_sn, 'o', ...
        'MarkerSize', 8, ...
        'LineWidth', 1.2);
    mn.MarkerFaceColor = mn.Color;

    h_legend(end+1) = mn;
    leg_labels{end+1} = 'Schiller-Naumann = weight';
end

% Plot formatting
grid on;
xlabel('Particle radius [\mum]');
ylabel('Force [N]');

legend(h_legend, leg_labels, 'Location', 'northwest');

title(sprintf('Forces on a particle, U = %.2f m/s', U));
drawnow;

% Export figure to PDF (vector format)
exportgraphics(fig, fullfile(dir_path, 'force_profile.pdf'), ...
    'ContentType', 'vector');

%% === 6. RESIDENCE TIME CALCULATION

% --- 6.1 Scaling factors: drawing → real furnace geometry ---

SF_V = 14/5.6;        % Vertical scale factor  [m / drawing-unit]
SF_H = 4.30/1.60;     % Horizontal scale factor [m / drawing-unit]

% --- 6.2 Drawing increments (Δx, Δy) for each segment ---
% The gas path is approximated as a sequence of straight-line segments
% connecting discrete points 0 → 1 → 2 → ... → 7 in the schematic.

% Segment 0 → 1
dHx_01 = 0.6;               % Horizontal increment (drawing units)
dVy_01 = 0.2;               % Vertical increment (drawing units)

% Segment 1 → 2
dHx_12 = 1.4;
dVy_12 = 1.35 - 0.2;

% Segment 2 → 3 (vertical only)
dHx_23 = 0.0;
dVy_23 = 2.00 - 1.35;

% Segment 3 → 4
dHx_34 = 0.0;
dVy_34 = 2.95 - 2.00;

% Segment 4 → 5
dHx_45 = 1.85;
dVy_45 = 4.45 - 2.95;

% Segment 5 → 6
dHx_56 = 0.0;
dVy_56 = 4.45 - 2.35;

% Segment 6 → 7
dHx_67 = 0.0;
dVy_67 = 2.35 - 0.45;

% Path lengths along real furnace (using scaled increments)
dHx_d = [dHx_01, dHx_12, dHx_23, dHx_34, dHx_45, dHx_56, dHx_67];
dVy_d = [dVy_01, dVy_12, dVy_23, dVy_34, dVy_45, dVy_56, dVy_67];

% Approximate total length of each segment by sum of horizontal and vertical
L = abs(dHx_d).*SF_H + abs(dVy_d).*SF_V;   % Segment lengths [m]

% Curvilinear coordinate s along the path 0 → 7
s = [0, cumsum(L)];    % Vector of s at points 0,1,...,7 [m]

% Optional check table: point index vs s-coordinate
pointNames = (0:7).';
disp(table(pointNames, s.', 'VariableNames', {'Point','s_m'}));

% --- 6.3 Plot of curvilinear positions s_0–s_7 ---

fig = figure('Name','Burner Path (s-coordinates)', ...
    'Units','pixels', ...
    'Position',[100 100 600 300], ...
    'Visible','on');

hold on; grid on; box on;

% Plot discrete burner points along the path in "index–s" space
C = parula(8);   % 8 distinct colors
scatter(0:7, s, 70, C, ...
    'filled', ...
    'MarkerEdgeColor', 'k');

xlabel('Burner point index (0–7)');
ylabel('Curvilinear coordinate s [m]');
title('Burner points along the reactor path');

% Export the burner-path plot
exportgraphics(fig, fullfile(dir_path, 'burner_points_s.pdf'), ...
    'ContentType','vector');

% --- 6.4 Residence time from point 3 to point 7 ---

s3    = s(3+1);               % s at point 3 (index 4 due to 1-based indexing)
s7    = s(end);               % s at point 7 (outlet)
s_vec = linspace(s3, s7, 200);% Fine spatial grid from point 3 to 7 [m]

% Residence time as function of s (assuming constant U)
t_vec = (s_vec - s3) ./ U;    % Gas residence time from 3 to 7 [s]

% --- 6.5 Path to CSV folder for experimental data ---
csv_path = 'csv';

% ---6.6 Read & clean O2 data ---
% Full path of original O2 file (with decimal commas)
fileO2_raw   = fullfile(csv_path, 'O2_concentration_measured.csv');
fileO2_clean = fullfile(csv_path, 'O2_clean.csv');

% Read raw O2 file as text and convert decimal commas to dots
rawO2 = fileread(fileO2_raw);
rawO2 = strrep(rawO2, ',', '.');

% Save cleaned O2 data to a new CSV file in the same folder
fid = fopen(fileO2_clean, 'w');
fwrite(fid, rawO2);
fclose(fid);

% Load cleaned numeric O2 data
O2_data = readmatrix(fileO2_clean, 'Delimiter',';');

% Extract columns: reactor position and O2 vol% (wet basis)
xO2_raw = round(O2_data(:,1));   % Measurement locations (1,3,4,6)
O2_raw  = O2_data(:,2);          % O2 concentration [% vol]

% --- 6.7 Read & clean temperature data ---
fileT_raw   = fullfile(csv_path, 'temperature_measured.csv');
fileT_clean = fullfile(csv_path, 'T_clean.csv');

% Read raw temperature file and convert decimal commas to dots
rawT = fileread(fileT_raw);
rawT = strrep(rawT, ',', '.');

% Save cleaned temperature data
fid = fopen(fileT_clean, 'w');
fwrite(fid, rawT);
fclose(fid);

% Load cleaned numeric temperature data
T_data = readmatrix(fileT_clean, 'Delimiter',';');

% Extract columns: reactor position and temperature
xT_raw = round(T_data(:,1));   % Measurement locations (2,3,4,5,6)
T_raw  = T_data(:,2);          % Temperature (°C, as in the file)

% --- 6.8 Map measured data to s-coordinate ---
% Reactor point indices corresponding to the schematic (0–7)
pos_reactor = [0 1 2 3 4 5 6 7];

% s_points: s-coordinate at each of the 8 schematic points
s_points = s;

% Map O2 measurement positions to s-coordinates
s_O2 = zeros(size(xO2_raw));
for i = 1:length(xO2_raw)
    idx = find(pos_reactor == xO2_raw(i));
    s_O2(i) = s_points(idx);
end

% Map T measurement positions to s-coordinates
s_T = zeros(size(xT_raw));
for i = 1:length(xT_raw)
    idx = find(pos_reactor == xT_raw(i));
    s_T(i) = s_points(idx);
end

% --- 6.9 Interpolation of O2(s) and T(s) along s_vec ---

% Use only measurement points located at or downstream of point 3
maskO2   = xO2_raw >= 3;
s_O2_use = s_O2(maskO2);
O2_use   = O2_raw(maskO2);

% Smooth interpolation of O2(%vol) along s_vec
O2_vec = interp1(s_O2_use, O2_use, s_vec, 'pchip');
xO2_vec = O2_vec/100;    % Convert O2 from vol% to mol fraction [-]

% Same for temperature data
maskT   = xT_raw >= 3;
s_T_use = s_T(maskT);
T_use   = T_raw(maskT);

% Smooth interpolation of temperature along s_vec
T_vec = interp1(s_T_use, T_use, s_vec, 'pchip');
T_vec_K = T_vec + 273.15;   % Convert from °C to K

% --- 6.10 Plot of O2(s) and T(s) profiles with measurements ---

fig = figure('Name','O2 and Temperature Profiles', ...
    'Units','pixels', ...
    'Position',[100 100 1200 300], ...
    'Visible','on');

% Subplot 1: O2 profile
subplot(1,2,1);
hold on; grid on;

% Measured O2 points
plot(s_O2, O2_raw, 'ko', ...
    'MarkerFaceColor', 'b', ...
    'DisplayName','O_2 measured');

% Interpolated O2 curve along the gas path
plot(s_vec, O2_vec, 'b-', ...
    'LineWidth', 1.8, ...
    'DisplayName','O_2 interpolated');

xlim([10 32]);         % s-range of interest [m]
ylim([2 8]);           % O2 [% vol]

xlabel('s [m]');
ylabel('O_2 [% vol]');
title('O_2 profile along reactor path');
legend show;

% Subplot 2: temperature profile
subplot(1,2,2);
hold on; grid on;

% Measured T points
plot(s_T, T_raw, 'ko', ...
    'MarkerFaceColor', 'r', ...
    'DisplayName','T measured');

% Interpolated temperature curve
plot(s_vec, T_vec, 'r-', ...
    'LineWidth', 1.8, ...
    'DisplayName','T interpolated');

xlim([10 32]);         % s-range [m]
ylim([600 1300]);      % Temperature range [°C]

xlabel('s [m]');
ylabel('T [°C or K]');
title('Temperature profile along reactor path');
legend show;

drawnow;

% Export combined O2/T profiles
exportgraphics(fig, fullfile(dir_path, 'O2_T_profiles.pdf'), ...
    'ContentType', 'vector');

%% === 7. CHAR OXIDATION MODEL
% Shrinking-particle model for char oxidation in the freeboard.
%
% Assumptions:
%  - Spherical char particles with initial diameter Dp0.
%  - Particle temperature equal to local gas temperature: T_p = T_g(s).
%  - Particles are fully entrained and follow the gas path 3 → 7 with
%    gas velocity U, i.e. no slip in the streamwise direction.
%  - Overall rate controlled by external mass transfer and surface
%    reaction in series (film + surface reaction).
%
% Objectives:
%  1) Compute burnout time t_burn(Dp0) for a set of particle diameters.
%  2) Compute conversion profiles X_p(s) = 1 - (r / r0)^3 along s.
%  3) Identify the burnout position of the largest particle that does
%     burn out completely; define that position as the starting point
%     for gas-phase CO oxidation.
%  4) Find the critical diameter D_crit that just burns out within the
%     freeboard residence time, and plot its evolution.

% --- 7.0 Base parameters for the char model ---

% Small entrained particle sizes [m]
Dp0_small = [10e-6, 30e-6, 80e-6];   % Initial diameters: 10, 30, 80 µm

% Add larger sizes up to the Stokes equilibrium diameter (worst entrainable)
if ~isnan(d_eq_stokes)
    % A few sizes between ~150 µm and d_eq_stokes
    Dp_min_large = 150e-6;  % 150 µm
    if Dp_min_large < d_eq_stokes
        Dp_extra = linspace(Dp_min_large, d_eq_stokes, 3); % 150, mid, d_eq
        Dp0_vec = [Dp0_small, Dp_extra];
    else
        % If d_eq_stokes < 150 µm, just include it as an additional size
        Dp0_vec = [Dp0_small, d_eq_stokes];
    end
else
    % If no equilibrium diameter found, use only the small sizes
    Dp0_vec = Dp0_small;
end

% Remove duplicate diameters and sort ascending
Dp0_vec = unique(Dp0_vec);
nD = length(Dp0_vec);

% Log the diameters considered in the char oxidation model
fprintf('\n===== PARTICLE SIZES FOR CHAR OXIDATION =====\n');
for k = 1:nD
    fprintf('  Dp0(%d) = %.1f µm\n', k, Dp0_vec(k)*1e6);
end
if ~isnan(d_eq_stokes)
    fprintf('Largest entrainable diameter (Stokes): %.1f µm\n', d_eq_stokes*1e6);
end

% --- 7.0.1 O2 diffusivity reference parameters (gas phase) ---
D_O2_ref = 2.0e-5;   % O2-gas diffusivity at ~300 K, 1 atm [m^2/s]
T_ref    = 300;      % Reference temperature [K]
P_ref    = 1e5;      % Reference pressure [Pa]

% Stoichiometry C + O2 -> CO2, 1 mol C per mol O2 consumed
Phi = 1.0;           % Stoichiometric factor mol C / mol O2 [-]

% Molar mass of carbon
M_C = 12e-3;         % [kg/mol]

% --- 7.0.2 Gas-phase O2 concentration profile along s ---

% Bulk O2 concentration along s_vec [mol/m^3]
O2_conc_vec = xO2_vec .* P ./ (R .* T_vec_K);

% Local time step between s(i) and s(i+1) assuming constant U
dt_vec = diff(s_vec) ./ U;   % Time step between successive s-points [s]

% Number of spatial points from position 3 to 7
Ns = length(s_vec);

% --- 7.0.3 Preallocation for char oxidation results ---

t_burn_vec = nan(nD,1);   % Burnout time for each initial diameter [s]
Xp_along_s = nan(nD, Ns); % Conversion X_p(s) for each initial diameter
r_along_s  = nan(nD, Ns); % Particle radius r(s) [m] for each initial diameter

% --- 7.1 Loop over initial diameters ---
for k = 1:nD
    
    Dp0 = Dp0_vec(k);    % Initial particle diameter [m]
    
    % Call helper function to compute burnout time and profiles r(s), X_p(s)
    [t_burn, r_prof, X_prof] = compute_burnout_time( ...
        Dp0, T_vec_K, O2_conc_vec, dt_vec, ...
        rho_g, mu_g, D_O2_ref, T_ref, P_ref, ...
        P, M_C, rho_p, Phi, U, s_vec);
    
    t_burn_vec(k) = t_burn;
    r_along_s(k,:)  = r_prof;
    Xp_along_s(k,:) = X_prof;
end

% --- 7.2 Burnot vs residence time ---
% Total gas residence time from position 3 to outlet (position 7)
t_res_3to7 = t_vec(end);    % [s] (t_vec(1) = 0 by construction)

fprintf('\n===== CHAR OXIDATION RESULTS =====\n');
fprintf('Gas residence time (3 -> 7): %.2f s\n', t_res_3to7);

for k = 1:nD
    Dp0_um = Dp0_vec(k) * 1e6;   % Diameter [µm]
    if isnan(t_burn_vec(k))
        fprintf('Dp0 = %.1f µm: NO complete burnout within furnace (3 -> 7)\n', Dp0_um);
    else
        fprintf(['Dp0 = %.1f µm: burnout time t_burn = %.2f s ', ...
                 '(residence = %.2f s)\n'], ...
            Dp0_um, t_burn_vec(k), t_res_3to7);
    end
end

% --- 7.2.1 Largest particle that DOES burn out (if any) ---

idx_burn = find(~isnan(t_burn_vec));   % Indices of sizes that burn out

if ~isempty(idx_burn)
    % Largest diameter among those that completely burn out
    [Dp_burn_max, idx_loc] = max(Dp0_vec(idx_burn));
    k_burn_max   = idx_burn(idx_loc);
    t_burn_max   = t_burn_vec(k_burn_max);       % Burnout time [s]
    
    % Burnout position along the path:
    s3_local = s_vec(1);                         % s at position 3
    s_burn   = s3_local + U * t_burn_max;        % Burnout coordinate [m]
    
    fprintf('\nLargest particle that DOES burn out:\n');
    fprintf('  Dp0 = %.1f µm\n', Dp_burn_max*1e6);
    fprintf('  Burnout time t_burn = %.2f s\n', t_burn_max);
    fprintf('  Burnout position s_burn ≈ %.2f m along 3 -> 7\n', s_burn);
else
    fprintf('\nWARNING: No particle burns out completely between 3 and 7.\n');
    s_burn = s_vec(1);  % Fallback: start gas-phase at position 3
end

% --- 7.3 Critical diameter D_crit ---
% Automatic selection of bounds for D_crit from the precomputed results:
%   Dp_low  = largest diameter that still burns out
%   Dp_high = smallest diameter that does NOT burn out
idx_noburn = find(isnan(t_burn_vec));

if ~isempty(idx_burn) && ~isempty(idx_noburn)
    Dp_low  = max(Dp0_vec(idx_burn));   % Lower bound: surely burns
    Dp_high = min(Dp0_vec(idx_noburn)); % Upper bound: surely does NOT burn
    
    fprintf('\nInitial bounds for D_crit: [%.1f, %.1f] µm\n', ...
        Dp_low*1e6, Dp_high*1e6);
    
    % Bisection loop to refine D_crit
    for it = 1:30   % 30 iterations are more than enough
        Dp_mid = 0.5 * (Dp_low + Dp_high);
        
        % For the bisection, only the burnout time is needed (first output)
        t_mid = compute_burnout_time(Dp_mid, T_vec_K, O2_conc_vec, dt_vec, ...
                                     rho_g, mu_g, D_O2_ref, T_ref, P_ref, ...
                                     P, M_C, rho_p, Phi, U, s_vec);
        if isnan(t_mid) || t_mid > t_res_3to7
            % No burnout within freeboard => particle is too large
            Dp_high = Dp_mid;
        else
            % Complete burnout within freeboard => can increase diameter
            Dp_low = Dp_mid;
        end
    end
    
    Dp_crit = Dp_low;  % Critical maximum diameter that still burns out
    
    % Compute full profiles for D_crit
    [t_crit, r_crit, X_crit] = compute_burnout_time( ...
        Dp_crit, T_vec_K, O2_conc_vec, dt_vec, ...
        rho_g, mu_g, D_O2_ref, T_ref, P_ref, ...
        P, M_C, rho_p, Phi, U, s_vec);
    
    fprintf('\n===== CRITICAL DIAMETER FOR COMPLETE BURNOUT =====\n');
    fprintf('D_crit ≈ %.1f µm\n', Dp_crit * 1e6);
    fprintf('Burnout time at D_crit: t_burn ≈ %.2f s (residence = %.2f s)\n', ...
            t_crit, t_res_3to7);
else
    Dp_crit = NaN;
    r_crit  = nan(1,Ns);
    X_crit  = nan(1,Ns);
    fprintf('\nWARNING: cannot determine D_crit (all burn or none burn).\n');
end

% --- 7.4 Plot: conversion & radius vs s ---
fig = figure('Name','Particle Conversion and Radius','Units','pixels',...
    'Position',[100 100 1200 600],'Visible','on');
set(fig, 'ToolBar', 'none');
colors = lines(nD);

% Subplot 1: particle conversion X_p(s)
subplot(2,1,1);
hold on; grid on;

for k = 1:nD
    plot(s_vec, Xp_along_s(k,:), '-', 'LineWidth', 1.5, ...
        'Color', colors(k,:), ...
        'DisplayName', sprintf('D_{p0} = %.0f \\mum', Dp0_vec(k)*1e6));
end

% Add D_crit curve if available
if ~isnan(Dp_crit)
    plot(s_vec, X_crit, 'k--', 'LineWidth', 2.2, ...
        'DisplayName', sprintf('D_{crit} = %.0f \\mum', Dp_crit*1e6));
end

xlabel('s [m]');
ylabel('X_p [-]');
title('Char particle conversion X_p(s)');
xlim([10 32]);         % s-range [m]
ylim([0 1.05]);

% Subplot 2: Particle radius r_p(s)
subplot(2,1,2);
hold on; grid on;

for k = 1:nD
    plot(s_vec, r_along_s(k,:)*1e6, '-', 'LineWidth', 1.5, ...
        'Color', colors(k,:), ...
        'DisplayName', sprintf('D_{p0} = %.0f \\mum', Dp0_vec(k)*1e6));
end

% Add D_crit radius curve if available
if ~isnan(Dp_crit)
    plot(s_vec, r_crit*1e6, 'k--', 'LineWidth', 2.2, ...
        'DisplayName', sprintf('D_{crit} = %.0f \\mum', Dp_crit*1e6));
end

xlabel('s [m]');
ylabel('r_p [\mum]');
title('Char particle radius r_p(s)');
xlim([10 32]);         % s-range [m]
ylim([-50 400]);
lgd = legend('NumColumns', 7, 'Location','southoutside');
lgd.Position = [0.015 0.01 1 0.03]; 

drawnow;

% Export char oxidation plot
exportgraphics(fig, fullfile(dir_path, 'char_oxidation.pdf'), ...
    'ContentType', 'vector');

%% === 8. GAS-PHASE CO OXIDATION (DRYER–GLASSMAN, ODE45)

fprintf('\n===== GAS-PHASE CO OXIDATION (DRYER–GLASSMAN, ODE45) =====\n');

% --- 8.0 Common input data for gas-phase CO oxidation ---

T_mean      = mean(T_vec_K);        % Mean gas temperature between 3 and 7 [K]
C_tot_mean  = P / (R * T_mean);     % Mean total molar concentration [mol/m^3]
H2O_conc    = xH2O * C_tot_mean;    % Bulk H2O concentration [mol/m^3]

fprintf('Assuming [H2O] ≈ %.3e mol/m^3 (from global flue-gas composition).\n', H2O_conc);

% Dryer–Glassman kinetic parameters for CO + OH → CO2 + H
A_CO     = 1.3e10;      % Pre-exponential factor [units: m^(3+0.5)/mol^(1.5)/s]
E_over_R = 20130;       % Activation energy divided by R [K]

% Assumed initial CO level at gas-phase model inlet (user-defined)
CO0_ppm = 1000;         % Initial CO concentration [ppm]

% --- 8.A – CASE A (start at s3, variable T(s)) ---
s3 = s_vec(1);  % Starting position for gas-phase model: position 3

[sA, tA, COppmA] = solve_CO_profile_clean( ...
    s3, CO0_ppm, T_vec_K, O2_conc_vec, ...
    s_vec, U, P, R, H2O_conc, A_CO, E_over_R, ...
    'variable', NaN);

fprintf('\nCASE A (start at s3 = %.2f m):\n', s3);
fprintf('Gas-phase model starts at s = %.2f m and ends at s = %.2f m\n', ...
        sA(1), sA(end));
fprintf('Available residence time for gas-phase oxidation: %.2f s\n', ...
        tA(end));

% Convert initial CO ppm to mol/m^3 using local T at inlet
T_start_A    = interp1(s_vec, T_vec_K, sA(1), 'linear', 'extrap');
C_tot_startA = P / (R * T_start_A);
CO0_conc_A   = CO0_ppm * 1e-6 * C_tot_startA;

fprintf('Initial CO at s = %.2f m: CO0 = %.0f ppm -> [CO]_0 = %.3e mol/m^3\n', ...
        sA(1), CO0_ppm, CO0_conc_A);
fprintf('Exit CO (ODE45) at s = %.2f m: %.2f ppm\n', sA(end), COppmA(end));

% --- 8.B – CASE B (start at s_burn, variable T(s)) ---
if exist('s_burn','var') && ~isnan(s_burn)
    [sB, tB, COppmB] = solve_CO_profile_clean( ...
        s_burn, CO0_ppm, T_vec_K, O2_conc_vec, ...
        s_vec, U, P, R, H2O_conc, A_CO, E_over_R, ...
        'variable', NaN);

    fprintf('\nCASE B (start at s_burn = %.2f m):\n', s_burn);
    fprintf('Gas-phase model starts at s = %.2f m and ends at s = %.2f m\n', ...
            sB(1), sB(end));
    fprintf('Available residence time for gas-phase oxidation: %.2f s\n', ...
            tB(end));

    T_start_B    = interp1(s_vec, T_vec_K, sB(1), 'linear', 'extrap');
    C_tot_startB = P / (R * T_start_B);
    CO0_conc_B   = CO0_ppm * 1e-6 * C_tot_startB;

    fprintf('Initial CO at s = %.2f m: CO0 = %.0f ppm -> [CO]_0 = %.3e mol/m^3\n', ...
            sB(1), CO0_ppm, CO0_conc_B);
    fprintf('Exit CO (ODE45) at s = %.2f m: %.2f ppm\n', sB(end), COppmB(end));
else
    warning('s_burn not available: CASE B skipped.');
    sB = []; tB = []; COppmB = [];
end

% --- 8.C – CASE C (start at s_burn, constant T = 900 K) ---
T_const_caseC = 900;  % Constant gas temperature for Case C [K]

if exist('s_burn','var') && ~isnan(s_burn)
    [sC, tC, COppmC] = solve_CO_profile_clean( ...
        s_burn, CO0_ppm, T_vec_K, O2_conc_vec, ...
        s_vec, U, P, R, H2O_conc, A_CO, E_over_R, ...
        'constant', T_const_caseC);

    fprintf('\nCASE C (start at s_burn = %.2f m, T = %.0f K constant):\n', ...
            s_burn, T_const_caseC);
    fprintf('Gas-phase model starts at s = %.2f m and ends at s = %.2f m\n', ...
            sC(1), sC(end));
    fprintf('Available residence time for gas-phase oxidation: %.2f s\n', ...
            tC(end));

    C_tot_startC = P / (R * T_const_caseC);
    CO0_conc_C   = CO0_ppm * 1e-6 * C_tot_startC;

    fprintf('Initial CO at s = %.2f m: CO0 = %.0f ppm -> [CO]_0 = %.3e mol/m^3\n', ...
            sC(1), CO0_ppm, CO0_conc_C);
    fprintf('Exit CO (ODE45) at s = %.2f m: %.2f ppm\n', sC(end), COppmC(end));
else
    warning('s_burn not available: CASE C skipped.');
    sC = []; tC = []; COppmC = [];
end

% Summary plot for Cases A, B, C
fig = figure('Name','gas phase oxidation', ...
    'Units','pixels', ...
    'Position',[100 100 1200 300], ...
    'Visible','on');
hold on; grid on;

plot(sA, COppmA, 'LineWidth', 1.8, 'DisplayName','Case A: start at s_3');

if ~isempty(sB)
    plot(sB, COppmB, 'LineWidth', 1.8, 'DisplayName','Case B: start at s_{burn}');
end
if ~isempty(sC)
    plot(sC, COppmC, 'LineWidth', 1.8, ...
         'DisplayName',sprintf('Case C: s_{burn}, T = %.0f K',T_const_caseC));
end

xlabel('s [m]');
ylabel('CO [ppm]');
xlim([10 32]);         % s-range [m]
title('Gas-phase CO oxidation along reactor path (Cases A, B, C)');
legend('Location','northeast');

drawnow;

exportgraphics(fig, fullfile(dir_path, 'gas_phase_oxidation.pdf'), ...
    'ContentType', 'vector');

% --- 8.2 Sweep over different gas-phase start location ---
fprintf('\n--- 8.2: Location sweep for gas-phase start ---\n');

s3_loc = s_vec(1);   % s at position 3

% Candidate start locations (including s3 and up to s(end-1))
base_locs     = linspace(s_vec(1), s_vec(end-1), 6);
loc_candidates = [s3_loc, base_locs];

% Also add s_burn, if available and strictly internal to [s3, s(end-1)]
if exist('s_burn','var') && ~isnan(s_burn) && ...
        s_burn > s_vec(1) && s_burn < s_vec(end-1)
    loc_candidates = [loc_candidates, s_burn];
end

s_start_vec = unique(loc_candidates);   % Sorted unique starting positions
N_loc       = numel(s_start_vec);

CO_exit_loc    = nan(N_loc,1);    % Exit CO for each start location [ppm]
t_res_loc      = nan(N_loc,1);    % Residence time in gas-phase model [s]
s_loc_cell     = cell(N_loc,1);   % s profiles
t_loc_cell     = cell(N_loc,1);   % t profiles
COppm_loc_cell = cell(N_loc,1);   % CO profiles

for j = 1:N_loc
    s_start_j = s_start_vec(j);

    [s_j, t_j, COppm_j] = solve_CO_profile_clean( ...
        s_start_j, CO0_ppm, T_vec_K, O2_conc_vec, ...
        s_vec, U, P, R, H2O_conc, A_CO, E_over_R, ...
        'variable', NaN);

    s_loc_cell{j}     = s_j;
    t_loc_cell{j}     = t_j;
    COppm_loc_cell{j} = COppm_j;

    CO_exit_loc(j) = COppm_j(end);  % Exit CO [ppm]
    t_res_loc(j)   = t_j(end);      % Residence time from s_start_j to outlet [s]

    fprintf('Start at s = %.2f m: t_res = %.2f s, CO_exit = %.2f ppm\n', ...
            s_start_j, t_res_loc(j), CO_exit_loc(j));
end

% Plot CO(s) for different starting positions

fig = figure('Units','pixels', ...
    'Position',[100 100 800 300], ...
    'Visible','on');
set(fig, 'ToolBar', 'none');
hold on; grid on;

for j = 1:N_loc
    plot(s_loc_cell{j}, COppm_loc_cell{j}, 'LineWidth', 1.5, ...
        'DisplayName', sprintf('s_{start} = %.2f m', s_start_vec(j)));
end

% Mark s_3 and s_burn (if available)
h3 = xline(s3_loc, '--k', 's_3', 'LabelOrientation','horizontal');
h3.HandleVisibility = 'off';
if exist('s_burn','var') && ~isnan(s_burn)
    hb = xline(s_burn, '--r', 's_{burn,max}', 'LabelOrientation','horizontal');
    hb.HandleVisibility = 'off';
end

xlabel('s [m]');
ylabel('CO [ppm]');
title('Gas-phase CO oxidation for different start locations');
lgd = legend('NumColumns', 1);
lgd.Location = 'southeast';
lgd.Orientation = 'horizontal';

exportgraphics(fig, fullfile(dir_path, 'gas-phase_for_different_start_location.pdf'), ...
    'ContentType', 'vector');
    
% Plot exit CO vs start location

fig = figure('Units','pixels', ...
    'Position',[100 100 400 300], ...
    'Visible','on');

plot(s_start_vec, CO_exit_loc, '-o', 'LineWidth', 1.5);
grid on;
xlim([10 32]);         % s-range [m]
xlabel('s_{start} [m]');
ylabel('CO_{exit} [ppm]');
title('Exit CO vs. gas-phase start location');

drawnow;

exportgraphics(fig, fullfile(dir_path, 'CO_exit_for_different_start_location.pdf'), ...
    'ContentType', 'vector');

% --- 8.3 Sweep over different particle diameters ---
fprintf('\n--- 8.3: Diameter sweep (char burnout → gas-phase start) ---\n');

% Base list of diameters to analyze [m]
Dp_list = [50e-6, 80e-6, 100e-6, 150e-6];

% Append Dp_burn_max and Dp_crit when available
if exist('Dp_burn_max','var') && ~isnan(Dp_burn_max)
    Dp_list = [Dp_list, Dp_burn_max];
end
if exist('Dp_crit','var') && ~isnan(Dp_crit)
    Dp_list = [Dp_list, Dp_crit];
end

Dp_vec = unique(Dp_list);

% Restrict to diameters ≤ Dp_crit (+ small tolerance) if Dp_crit is defined
if exist('Dp_crit','var') && ~isnan(Dp_crit)
    Dp_vec = Dp_vec(Dp_vec <= Dp_crit + 1e-9);
end

nD_test       = length(Dp_vec);
t_burn_test   = nan(nD_test,1);    % Burnout times for test diameters [s]
s_burn_test   = nan(nD_test,1);    % Burnout positions [m]
t_res_remain  = nan(nD_test,1);    % Remaining gas-phase residence time [s]
CO_exit_Dp    = nan(nD_test,1);    % Exit CO [ppm]
s_Dp_cell     = cell(nD_test,1);   % s profiles for each diameter
t_Dp_cell     = cell(nD_test,1);   % t profiles
COppm_Dp_cell = cell(nD_test,1);   % CO profiles

for k = 1:nD_test
    Dp0 = Dp_vec(k);

    % Compute burnout time for Dp0 (no need for full profiles here)
    [t_burn_k, ~, ~] = compute_burnout_time( ...
        Dp0, T_vec_K, O2_conc_vec, dt_vec, ...
        rho_g, mu_g, D_O2_ref, T_ref, P_ref, ...
        P, M_C, rho_p, Phi, U, s_vec);

    t_burn_test(k) = t_burn_k;

    if isnan(t_burn_k)
        % No burnout within freeboard; no meaningful gas-phase start
        fprintf('Dp0 = %.1f µm: NO burnout within freeboard.\n', Dp0*1e6);
        CO_exit_Dp(k) = NaN;
        continue;
    end

    % Burnout position s_burn_k along the path
    s_burn_k = s_vec(1) + U * t_burn_k;
    s_burn_test(k) = s_burn_k;

    % If burnout occurs essentially at the outlet, no time for gas-phase oxidation
    if s_burn_k >= s_vec(end-1)
        t_res_remain(k) = 0;
        CO_exit_Dp(k)   = CO0_ppm;   % No oxidation -> same as inlet
        fprintf(['Dp0 = %.1f µm: t_{burn} ≈ t_{res}, s_{burn} ≈ outlet, ', ...
                 'no time for gas-phase (CO_exit ≈ CO_0).\n'], Dp0*1e6);
        continue;
    end

    % Remaining residence time for gas-phase oxidation
    t_res_remain(k) = (s_vec(end) - s_burn_k) / U;

    % Solve gas-phase CO oxidation starting at s_burn_k
    [s_k, t_k, COppm_k] = solve_CO_profile_clean( ...
        s_burn_k, CO0_ppm, T_vec_K, O2_conc_vec, ...
        s_vec, U, P, R, H2O_conc, A_CO, E_over_R, ...
        'variable', NaN);

    s_Dp_cell{k}     = s_k;
    t_Dp_cell{k}     = t_k;
    COppm_Dp_cell{k} = COppm_k;

    CO_exit_Dp(k) = COppm_k(end);

    fprintf(['Dp0 = %.1f µm: t_{burn} = %.2f s, s_{burn} = %.2f m, ', ...
             't_{res,gas} = %.2f s, CO_exit = %.2f ppm\n'], ...
             Dp0*1e6, t_burn_k, s_burn_k, t_res_remain(k), CO_exit_Dp(k));
end

% Plot CO(s) for different initial diameters, including char burnout
fig = figure('Units','pixels', ...
    'Position',[100 100 800 300], ...
    'Visible','on');
set(fig, 'ToolBar', 'none');
hold on; grid on;

for k = 1:nD_test
    if ~isempty(s_Dp_cell{k})
        plot(s_Dp_cell{k}, COppm_Dp_cell{k}, 'LineWidth', 1.5, ...
            'DisplayName', sprintf('D_{p0} = %.0f \\mum', Dp_vec(k)*1e6));
    end
end

% Mark the maximum burnout position among the considered sizes (if available)
if exist('s_burn','var') && ~isnan(s_burn)
    hb = xline(s_burn, '--k', 's_{burn,max}', 'LabelOrientation','horizontal');
    hb.HandleVisibility = 'off';
end

xlabel('s [m]');
ylabel('CO [ppm]');
xlim([10 32]);         % s-range [m]
title('Gas-phase CO oxidation: different particle diameters');
legend('Location','northeast');

drawnow;

exportgraphics(fig, fullfile(dir_path, 'CO_or_different_diameter.pdf'), ...
    'ContentType', 'vector');

% Plot exit CO vs initial particle diameter
fig = figure('Units','pixels', ...
    'Position',[100 100 400 300], ...
    'Visible','on');
plot(Dp_vec*1e6, CO_exit_Dp, '-o', 'LineWidth', 1.5);
grid on;
xlabel('D_{p0} [\mum]');
ylabel('CO_{exit} [ppm]');
title('Exit CO vs. initial particle diameter');

drawnow;

exportgraphics(fig, fullfile(dir_path, 'CO_exit_for_different_diameter.pdf'), ...
    'ContentType', 'vector');

% --- 8.4 Sweep over different constant gas temperature ---
fprintf('\n--- 8.4: Temperature sweep (constant T in gas-phase model) ---\n');

% Reference start for temperature sweep: s_burn if available, else s_3
if exist('s_burn','var') && ~isnan(s_burn)
    s_start_T = s_burn;
else
    s_start_T = s_vec(1);
end

T_const_vec = [900, 1000, 1100];   % Constant temperatures [K]
nT          = length(T_const_vec);

CO_exit_T     = nan(nT,1);         % Exit CO for each constant T [ppm]
s_T_cell      = cell(nT,1);        % s profiles
t_T_cell      = cell(nT,1);        % t profiles
COppm_T_cell  = cell(nT,1);        % CO profiles

for iT = 1:nT
    T_const = T_const_vec(iT);

    [s_Ti, t_Ti, COppm_Ti] = solve_CO_profile_clean( ...
        s_start_T, CO0_ppm, T_vec_K, O2_conc_vec, ...
        s_vec, U, P, R, H2O_conc, A_CO, E_over_R, ...
        'constant', T_const);

    s_T_cell{iT}     = s_Ti;
    t_T_cell{iT}     = t_Ti;
    COppm_T_cell{iT} = COppm_Ti;

    CO_exit_T(iT) = COppm_Ti(end);

    fprintf(['T = %.0f K (constant), start at s = %.2f m: ', ...
             't_res = %.2f s, CO_exit = %.4f ppm\n'], ...
             T_const, s_start_T, t_Ti(end), CO_exit_T(iT));
end

% Plot CO(s) for different constant temperatures

fig = figure('Units','pixels', ...
    'Position',[100 100 600 300], ...
    'Visible','on');
set(fig, 'ToolBar', 'none');
hold on; grid on;

for iT = 1:nT
    plot(s_T_cell{iT}, COppm_T_cell{iT}, 'LineWidth', 1.5, ...
        'DisplayName', sprintf('T = %.0f K', T_const_vec(iT)));
end

xlabel('s [m]');
ylabel('CO [ppm]');
title('Gas-phase CO oxidation for different constant temperatures');
legend('Location','northeast');

drawnow;

exportgraphics(fig, fullfile(dir_path, 'CO_for_different_temperature.pdf'), ...
    'ContentType', 'vector');

% Plot exit CO vs constant temperature

fig = figure('Units','pixels', ...
    'Position',[100 100 600 300], ...
    'Visible','on');
plot(T_const_vec, CO_exit_T, '-o', 'LineWidth', 1.5);
grid on;
xlabel('T_{const} [K]');
ylabel('CO_{exit} [ppm]');
title('Exit CO vs. constant gas temperature');

drawnow;

exportgraphics(fig, fullfile(dir_path, 'CO_exit_for_different_temperature.pdf'), ...
    'ContentType', 'vector');

%% === 9. LOCAL HELPER FUNCTIONS
% --- 9.1 Char burnout model: compute_burnout_time() ---
function [t_burn, r_prof, X_prof] = compute_burnout_time( ...
    Dp0, T_vec_K, O2_conc_vec, dt_vec, ...
    rho_g, mu_g, D_O2_ref, T_ref, P_ref, ...
    P, M_C, rho_p, Phi, U, s_vec)

    % This function computes the burnout time and particle evolution for a
    % single initial particle diameter Dp0 along the freeboard path.
    %
    % Inputs:
    %   Dp0          - Initial particle diameter [m]
    %   T_vec_K      - Gas temperature profile along s_vec [K]
    %   O2_conc_vec  - Gas O2 concentration profile [mol/m^3]
    %   dt_vec       - Time steps between successive s-points [s]
    %   rho_g        - Gas density [kg/m^3]
    %   mu_g         - Gas dynamic viscosity [Pa·s]
    %   D_O2_ref     - Reference O2 diffusivity at (T_ref, P_ref) [m^2/s]
    %   T_ref        - Reference temperature [K]
    %   P_ref        - Reference pressure [Pa]
    %   P            - Operating pressure [Pa]
    %   M_C          - Molar mass of carbon [kg/mol]
    %   rho_p        - Particle density [kg/m^3]
    %   Phi          - Stoichiometric factor mol C/mol O2 [-]
    %   U            - Gas velocity [m/s]
    %   s_vec        - Spatial grid from s3 to s7 [m]
    %
    % Outputs:
    %   t_burn       - Burnout time [s]; NaN if no burnout within domain
    %   r_prof       - Particle radius along s_vec [m]
    %   X_prof       - Particle conversion X_p along s_vec [-]

    Ns = length(s_vec);   % Number of spatial points
    r0 = Dp0 / 2;         % Initial particle radius [m]
    rp = r0;              % Current radius [m]
    t_cum = 0;            % Cumulative time [s]
    burned_out = false;   % Flag for complete burnout

    % Preallocate profiles
    r_prof = nan(1,Ns);   % Radius profile [m]
    X_prof = nan(1,Ns);   % Conversion profile [-]
    r_prof(1) = rp;
    X_prof(1) = 0.0;

    % March along the s-grid (from 3 to 7)
    for i = 1:Ns-1
        T_loc  = T_vec_K(i);       % Local gas temperature [K]
        O2_loc = O2_conc_vec(i);   % Local O2 concentration [mol/m^3]
        dt_loc = dt_vec(i);        % Local time step [s]

        % Temperature- and pressure-dependent O2 diffusivity [m^2/s]
        D_O2 = D_O2_ref * (T_loc/T_ref)^1.5 * (P_ref/P);

        % Local particle diameter and Reynolds number
        Dp_loc = 2 * rp;
        Re_p   = rho_g * U * Dp_loc / mu_g;

        % Schmidt number (Sc = nu / D_O2)
        Sc     = mu_g / (rho_g * D_O2);

        % Sherwood number (Ranz–Marshall correlation, with floor on Re_p)
        Sh = 2 + 0.6 * max(Re_p,0)^0.5 * Sc^(1/3);

        % Gas-phase mass-transfer coefficient [m/s]
        kg = Sh * D_O2 / Dp_loc;

        % Intrinsic surface reaction rate coefficient [m/s]
        % (empirical correlation: kc = k0 * T * exp(-E/RT))
        kc = 1e3 * T_loc * exp(-15900 / T_loc);

        % Overall effective rate coefficient (film + surface in series)
        k_eff = 1 / ( 1/(kg * Phi) + 1/kc );

        % Radius evolution equation dr/dt (shrinking core model)
        drdt = - (M_C * k_eff * O2_loc) / (rho_p * Phi);

        % Explicit Euler step for radius
        rp_new = rp + drdt * dt_loc;

        if rp_new <= 0
            % Particle completely consumed within this time step
            burned_out = true;
            rp_new = 0;
            t_cum = t_cum + dt_loc;
            r_prof(i+1) = rp_new;
            X_prof(i+1) = 1.0;
            % Force full conversion and zero radius for all remaining points
            if i+1 < Ns
                r_prof(i+2:end) = 0;
                X_prof(i+2:end) = 1;
            end
            break;
        end

        % Update radius and time
        rp = rp_new;
        t_cum = t_cum + dt_loc;

        r_prof(i+1) = rp;
        X_prof(i+1) = 1 - (rp / r0)^3;  % Volumetric conversion
    end

    % Assign burnout time (NaN if not fully consumed)
    if burned_out
        t_burn = t_cum;
    else
        t_burn = NaN;  % No burnout within the freeboard path
    end
end

% --- 9.2 Gas-phase CO oxidation ODE: solve_CO_profile_clean() ---
function [s_sol, t_sol, CO_ppm_sol] = solve_CO_profile_clean( ...
    s_start, CO0_ppm, T_vec_K, O2_conc_vec, ...
    s_vec, U, P, R, H2O_conc, A_CO, E_over_R, ...
    mode, T_const)

    % This function solves the Dryer–Glassman CO oxidation ODE along the
    % gas path starting from s_start to the outlet.
    %
    % Inputs:
    %   s_start      - Starting coordinate of gas-phase model [m]
    %   CO0_ppm      - Initial CO level at s_start [ppm]
    %   T_vec_K      - Gas temperature profile along s_vec [K]
    %   O2_conc_vec  - O2 concentration profile [mol/m^3]
    %   s_vec        - Full spatial grid from s3 to s7 [m]
    %   U            - Gas velocity [m/s]
    %   P            - Gas pressure [Pa]
    %   R            - Universal gas constant [J/mol-K]
    %   H2O_conc     - Bulk H2O concentration [mol/m^3]
    %   A_CO         - Pre-exponential factor of kinetic law
    %   E_over_R     - Activation energy divided by R [K]
    %   mode         - 'variable' (use measured T(s)) or 'constant'
    %   T_const      - Constant T for 'constant' mode [K] (ignored otherwise)
    %
    % Outputs:
    %   s_sol        - Spatial coordinate vector of the ODE solution [m]
    %   t_sol        - Time vector associated to s_sol [s]
    %   CO_ppm_sol   - CO concentration along s_sol [ppm]

    % --- Select sub-domain in s starting from s_start ---
    idx_start = find(s_vec >= s_start, 1, 'first');
    s_sub  = s_vec(idx_start:end);   % s-grid used in the ODE integration

    T_sub0 = T_vec_K(idx_start:end); % Corresponding T profile
    O2_sub = O2_conc_vec(idx_start:end); % Corresponding O2 profile

    % Build time coordinate (t = 0 at s_start, ds/dt = U)
    t_sub = (s_sub - s_sub(1)) ./ U;
    t_end = t_sub(end);

    % Select temperature profile depending on the mode
    switch mode
        case 'variable'
            T_sub = T_sub0;                      % Use measured T(s)
        case 'constant'
            T_sub = T_const * ones(size(T_sub0));% Force constant T
    end

    % Interpolating functions for T(t) and O2(t)
    T_fun  = @(t) interp1(t_sub, T_sub,  t, 'linear', 'extrap');
    O2_fun = @(t) interp1(t_sub, O2_sub, t, 'linear', 'extrap');

    % Initial CO concentration from ppm at t = 0
    T0 = T_fun(0);
    C_tot0 = P / (R * T0);
    CO0_conc = CO0_ppm * 1e-6 * C_tot0;   % [mol/m^3]

    % --- Ensure at least two spatial points in the sub-domain ---
    % If there is no actual residence length (e.g. s_start ≈ outlet),
    % we return a flat profile equal to the inlet CO level.
    if length(s_sub) < 2
        T0       = T_vec_K(end);
        C_tot0   = P / (R * T0);
        CO0_conc = CO0_ppm * 1e-6 * C_tot0;
    
        s_sol      = [s_start; s_vec(end)];
        t_sol      = [0; 0];
        CO_ppm_sol = [CO0_ppm; CO0_ppm];
        return;
    end

    % Dryer–Glassman type ODE: dCO/dt = -k(T) * CO * [H2O]^0.5 * [O2]^0.25
    dCOdt = @(t, CO) ...
        - A_CO .* exp(-E_over_R ./ T_fun(t)) .* ...
          CO .* H2O_conc^0.5 .* (O2_fun(t)).^0.25;

    % ODE solver settings (stiffness not extreme, but use tight tolerances)
    opts = odeset('RelTol',1e-6,'AbsTol',1e-9);
    [t_sol, CO_sol] = ode45(dCOdt, [0 t_end], CO0_conc, opts);

    % Map time back to space: s = s_start + U*t
    s_sol = s_sub(1) + U * t_sol;

    % Convert CO concentration [mol/m^3] back to ppm using local T
    T_sol     = T_fun(t_sol);
    C_tot_sol = P ./ (R .* T_sol);
    xCO_sol   = CO_sol ./ C_tot_sol;
    CO_ppm_sol = xCO_sol * 1e6;      % CO ppm along s_sol
end