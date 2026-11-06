%% ************************************************************************
% File: NS2dRe1000ConvergenceAnalysis.m
%   Driver script for Task 8.
%   Performs a grid-convergence analysis for the lid-driven square cavity
%   flow at Re = 1000 using the implemented Navier-Stokes solver.
%
%   The solver is run for several grid resolutions using:
%     - Ulid = -1, to match the benchmark convention
%     - reordered LU factorization of the Poisson matrix
%     - discrete continuity correction
%     - steady-state tolerance on the maximum velocity rate of change
%
%   The computed steady-state velocity and pressure fields are compared
%   against the Bruneau and Saad benchmark data along:
%     - the vertical centerline x = 0.5
%     - the horizontal centerline y = 0.5
%
%   Pressure is referenced to the cavity center before comparison:
%       p_ref = p - p(0.5,0.5)
%
%   The script computes:
%     - centerline velocity and pressure profiles
%     - maximum norm errors with respect to benchmark values
%     - convergence rates with grid refinement
%     - final steady-state and mass-conservation diagnostics
%
% Output:
%   - MAT-file containing run data and convergence data
%   - CSV table with errors and diagnostics
%   - velocity centerline benchmark plot
%   - pressure centerline benchmark plot
%   - velocity error convergence plot
%   - pressure error convergence plot
%   - streamline comparison plot
%   - pressure field plot on the finest grid
%
%   Author      : Giulio La Sala
%   Date        : Sunday 17/05/2026
%   Version     : Final
%**************************************************************************

%% Clear
clear
close all
clc

%% Setup project paths
this_file    = mfilename('fullpath');
analysis_dir = fileparts(this_file);
project_dir  = fileparts(analysis_dir);
startup_dir  = fullfile(project_dir, 'startup');
solver_dir   = fullfile(project_dir, 'solver');

addpath(startup_dir);
paths = setupPaths();

%% Task 8 parameters
Nvec = [21 41 81 161 321];

Re   = 1000;
Ulid = -1;

dt_user    = 1e-2;
steadytol  = 1e-6;
statstride = 1000;

useLUfactorization      = true;
useContinuityCorrection = true;

saveRe1000Figures = true;
saveRe1000Results = true;

% Conservative maxstep values for increasing grid resolution
maxstepVec = [100000 200000 400000 800000 1600000];

%% Output folders
re1000_results_dir = fullfile(paths.results, 'Re1000');
re1000_figures_dir = fullfile(paths.figures, 'Re1000');

if ~exist(re1000_results_dir, 'dir')
    mkdir(re1000_results_dir);
end

if ~exist(re1000_figures_dir, 'dir')
    mkdir(re1000_figures_dir);
end

%% Benchmark data: Bruneau and Saad, Re = 1000, Ulid = -1
% Vertical centerline: [y, u, p]
vert = [ 1.0000 -1.00000  0.052971
         0.9688 -0.58031  0.051493
         0.9531 -0.47239  0.050314
         0.7344 -0.18861  0.012113
         0.5000  0.06205  0.000000
         0.2813  0.28040  0.040381
         0.1016  0.30029  0.104416
         0.0625  0.20227  0.109160
         0.0000  0.00000  0.110560 ];

% Horizontal centerline: [x, v, p]
hor  = [ 0.0000  0.00000  0.077429
         0.0391 -0.29330  0.078658
         0.0547 -0.41018  0.077128
         0.1406 -0.42634  0.049004
         0.5000  0.02580  0.000000
         0.7734  0.33398  0.047259
         0.9062  0.33290  0.084369
         0.9297  0.29627  0.087625
         1.0000  0.00000  0.090448 ];

%% Initialize storage
nRuns = length(Nvec);

dxvec       = zeros(nRuns, 1);
Nunknowns   = zeros(nRuns, 1);
steps       = zeros(nRuns, 1);
dt_used     = zeros(nRuns, 1);
steadyFinal = zeros(nRuns, 1);
divFinal    = zeros(nRuns, 1);
steadyMet   = false(nRuns, 1);

ERROR = zeros(4, nRuns);
% 1: u vertical centerline
% 2: v horizontal centerline
% 3: p vertical centerline
% 4: p horizontal centerline

runData_all = cell(nRuns, 1);

profileData = struct();

%% Main loop over grid sizes
for i = 1:nRuns

    n = Nvec(i);
    Nunknowns(i) = n^2;

    fprintf('\n============================================================\n');
    fprintf('TASK 8: Re = 1000 convergence run, n = %d\n', n);
    fprintf('============================================================\n');

    %% Solver configuration
    runConfig = struct();

    runConfig.n    = n;
    runConfig.Re   = Re;
    runConfig.Ulid = Ulid;

    runConfig.maxstep    = maxstepVec(i);
    runConfig.dt_user    = dt_user;
    runConfig.steadytol  = steadytol;
    runConfig.statstride = statstride;

    runConfig.useLUfactorization      = useLUfactorization;
    runConfig.useContinuityCorrection = useContinuityCorrection;

    runConfig.createPlots = false;
    runConfig.saveFigures = false;
    runConfig.saveResults = true;

    runConfig.results_subdir = 'Re1000';
    runConfig.figures_subdir = 'Re1000';

    %% Run solver
    clear runData
    run(fullfile(solver_dir, 'NavierStokes2dMovingLidSquareCavityFlow.m'));

    runData_all{i} = runData;

    %% Extract diagnostics
    dxvec(i)       = runData.numerics.dx;
    steps(i)       = runData.numerics.step;
    dt_used(i)     = runData.numerics.dt;
    steadyFinal(i) = runData.history.steadyhist(end);
    divFinal(i)    = runData.history.cmchist(end);
    steadyMet(i)   = steadyFinal(i) < steadytol;

    %% Extract fields
    u = runData.fields.u;
    v = runData.fields.v;
    P = runData.fields.P;

    [dx, Xu, Yu, Xv, Yv, Xp, Yp, Xi, Yi] = StaggeredMesh2dSquare(n);

    %% Reference pressure to cavity center
    ic = (n + 1) / 2;
    P  = P - P(ic, ic);

    %% Interpolate numerical solution to benchmark points
    xu = Xu(1, :);
    yu = Yu(:, 1);

    xv = Xv(1, :);
    yv = Yv(:, 1);

    xp = Xp(1, :);
    yp = Yp(:, 1);

    Fu = griddedInterpolant({yu, xu}, u, 'spline', 'spline');
    Fv = griddedInterpolant({yv, xv}, v, 'spline', 'spline');
    Fp = griddedInterpolant({yp, xp}, P, 'spline', 'spline');

    yb = vert(:, 1);
    xb = hor(:, 1);

    u_vert = Fu(yb, 0.5 * ones(size(yb)));
    p_vert = Fp(yb, 0.5 * ones(size(yb)));

    v_hor = Fv(0.5 * ones(size(xb)), xb);
    p_hor = Fp(0.5 * ones(size(xb)), xb);

    %% Compute max-norm errors
    ERROR(1, i) = norm(u_vert - vert(:, 2), inf);
    ERROR(2, i) = norm(v_hor  - hor(:, 2),  inf);
    ERROR(3, i) = norm(p_vert - vert(:, 3), inf);
    ERROR(4, i) = norm(p_hor  - hor(:, 3),  inf);

    %% Store profiles
    profileData(i).n      = n;
    profileData(i).u_vert = u_vert;
    profileData(i).v_hor  = v_hor;
    profileData(i).p_vert = p_vert;
    profileData(i).p_hor  = p_hor;

    %% Run summary
    fprintf('\n------------------------------------------------------------\n');
    fprintf('SUMMARY FOR n = %d\n', n);
    fprintf('------------------------------------------------------------\n');
    fprintf(' steps performed  : %d\n', steps(i));
    fprintf(' dx               : %.6e\n', dxvec(i));
    fprintf(' dt used          : %.6e\n', dt_used(i));
    fprintf(' steady(end)      : %.6e\n', steadyFinal(i));
    fprintf(' max|divU|(end)   : %.6e\n', divFinal(i));
    fprintf(' steady met       : %d\n', steadyMet(i));
    fprintf(' error u vertical : %.6e\n', ERROR(1, i));
    fprintf(' error v horizontal: %.6e\n', ERROR(2, i));
    fprintf(' error p vertical : %.6e\n', ERROR(3, i));
    fprintf(' error p horizontal: %.6e\n', ERROR(4, i));
    fprintf('============================================================\n');
end

%% Compute convergence rates using finest three grids
fitIdx = max(1, nRuns-2):nRuns;

ROC = zeros(4, 1);
TC  = zeros(4, nRuns);

for k = 1:4
    pfit = polyfit(log10(dxvec(fitIdx)), log10(ERROR(k, fitIdx).'), 1);
    ROC(k) = pfit(1);
    TC(k, :) = 10.^polyval(pfit, log10(dxvec));
end

%% Final table
re1000Table = table( ...
    Nvec(:), ...
    Nunknowns, ...
    dxvec, ...
    dt_used, ...
    steps, ...
    steadyFinal, ...
    divFinal, ...
    steadyMet, ...
    ERROR(1, :).', ...
    ERROR(2, :).', ...
    ERROR(3, :).', ...
    ERROR(4, :).', ...
    'VariableNames', { ...
    'n', ...
    'Nunknowns', ...
    'dx', ...
    'dt_used', ...
    'steps', ...
    'steady_final', ...
    'divergence_final', ...
    'steady_met', ...
    'error_u_vertical', ...
    'error_v_horizontal', ...
    'error_p_vertical', ...
    'error_p_horizontal'});

disp(re1000Table)

%% Final summary log
fprintf('\n============================================================\n');
fprintf('TASK 8 — Re = 1000 CONVERGENCE SUMMARY\n');
fprintf('------------------------------------------------------------\n');
fprintf('Estimated convergence rates using finest three grids:\n');
fprintf(' u vertical centerline      : %.3f\n', ROC(1));
fprintf(' v horizontal centerline    : %.3f\n', ROC(2));
fprintf(' p vertical centerline      : %.3f\n', ROC(3));
fprintf(' p horizontal centerline    : %.3f\n', ROC(4));
fprintf('------------------------------------------------------------\n');
fprintf('Finest grid n              : %d\n', Nvec(end));
fprintf('Finest grid steady(end)    : %.6e\n', steadyFinal(end));
fprintf('Finest grid max|divU|(end) : %.6e\n', divFinal(end));
fprintf('------------------------------------------------------------\n');
fprintf('All runs reached steadytol : %d\n', all(steadyMet));
fprintf('Finest grid errors         : Eu=%.3e | Ev=%.3e | Epv=%.3e | Eph=%.3e\n', ...
        ERROR(1,end), ERROR(2,end), ERROR(3,end), ERROR(4,end));
fprintf('============================================================\n');

%% Save results
if saveRe1000Results
    save(fullfile(re1000_results_dir, ...
        'NS2d_Re1000_convergence_analysis.mat'), ...
        're1000Table', ...
        'runData_all', ...
        'profileData', ...
        'Nvec', ...
        'Re', ...
        'Ulid', ...
        'dxvec', ...
        'ERROR', ...
        'ROC', ...
        'TC', ...
        'vert', ...
        'hor');

    writetable(re1000Table, ...
        fullfile(re1000_results_dir, ...
        'NS2d_Re1000_convergence_analysis.csv'));
end

%% Plot 1A: velocity centerline profiles

fig1a = figure('Name', 'Re1000VelocityCenterlineBenchmark', 'NumberTitle', 'off');
clf
colors = winter(nRuns); 

tl = tiledlayout(fig1a, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

% --- Tile 1: Vertical ---
ax1 = nexttile; hold on

hSim1 = zeros(nRuns, 1);
for i = 1:nRuns
    hSim1(i) = plot(profileData(i).u_vert, vert(:, 1), '-', 'LineWidth', 1.5, 'Color', colors(i,:));
end

hBench1 = plot(vert(:, 2), vert(:, 1), 'ko--', 'LineWidth', 1.0, ...
    'MarkerFaceColor', 'w', 'MarkerSize', 5);

hold off

xlabel('u(x=0.5,y)'); ylabel('y');
title('Vertical centerline velocity')
box on; axis square;

% --- Tile 2: Horizontal ---
ax2 = nexttile; hold on

hSim2 = zeros(nRuns, 1);
for i = 1:nRuns
    hSim2(i) = plot(hor(:, 1), profileData(i).v_hor, '-', 'LineWidth', 1.5, 'Color', colors(i,:));
end

hBench2 = plot(hor(:, 1), hor(:, 2), 'ko--', 'LineWidth', 1.0, ...
    'MarkerFaceColor', 'w', 'MarkerSize', 5);

hold off

xlabel('x'); ylabel('v(x,y=0.5)');
title('Horizontal centerline velocity')
ylim([-0.5 0.5]);  box on; axis square;

legendObjects = [hBench2; hSim2]; 
legendLabels = cell(nRuns + 1, 1);
legendLabels{1} = 'Benchmark';
for i = 1:nRuns
    legendLabels{i+1} = sprintf('n = %d', Nvec(i));
end

lgd = legend(ax2, legendObjects, legendLabels, ...
    'Orientation', 'horizontal');
lgd.Layout.Tile = 'south';
lgd.Box = 'on';

set(lgd, 'ItemTokenSize', [30, 18]); 

set(findall(fig1a, '-property', 'TickLabelInterpreter'), 'TickLabelInterpreter', 'latex');
set(findall(fig1a, '-property', 'FontSize'), 'FontSize', 10);

if saveRe1000Figures
    PlotToFileColorPDF(fig1a, ...
        fullfile(re1000_figures_dir, 'Re1000_velocity_centerline_benchmark'), 16, 8);
end

%% Plot 1B: pressure centerline profiles
fig1b = figure('Name', 'Re1000PressureCenterlineBenchmark', 'NumberTitle', 'off');
clf

colors = winter(nRuns); 

tl = tiledlayout(fig1b, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

% --- Tile 1: Vertical pressure ---
ax1 = nexttile; hold on

hSimP1 = zeros(nRuns, 1);
for i = 1:nRuns

    hSimP1(i) = plot(profileData(i).p_vert, vert(:, 1), '-', 'LineWidth', 1.5, 'Color', colors(i,:));
end

hBenchP1 = plot(vert(:, 3), vert(:, 1), 'ko--', 'LineWidth', 1.0, ...
    'MarkerFaceColor', 'w', 'MarkerSize', 5);

hold off

xlabel('p(x=0.5,y)-p(0.5,0.5)')
ylabel('y')
title('Vertical centerline pressure')
box on; axis square;

% --- Tile 2: Horizontal pressure ---
ax2 = nexttile; hold on

hSimP2 = zeros(nRuns, 1);
for i = 1:nRuns
    hSimP2(i) = plot(hor(:, 1), profileData(i).p_hor, '-', 'LineWidth', 1.5, 'Color', colors(i,:));
end

hBenchP2 = plot(hor(:, 1), hor(:, 3), 'ko--', 'LineWidth', 1.0, ...
    'MarkerFaceColor', 'w', 'MarkerSize', 5);
hold off

xlabel('x')
ylabel('p(x,0.5)-p(0.5,0.5)')
title('Horizontal centerline pressure')
box on; axis square;

legendObjects = [hBenchP2; hSimP2]; 

legendLabels = cell(nRuns + 1, 1);
legendLabels{1} = 'Benchmark';
for i = 1:nRuns
    legendLabels{i+1} = sprintf('n = %d', Nvec(i));
end

lgd = legend(ax2, legendObjects, legendLabels, ...
    'Orientation', 'horizontal');
lgd.Layout.Tile = 'south';
lgd.Box = 'on'; 

set(lgd, 'ItemTokenSize', [30, 18]); 

set(findall(fig1b, '-property', 'TickLabelInterpreter'), 'TickLabelInterpreter', 'latex');
set(findall(fig1b, '-property', 'FontSize'), 'FontSize', 10);

if saveRe1000Figures
    PlotToFileColorPDF(fig1b, ...
        fullfile(re1000_figures_dir, 'Re1000_pressure_centerline_benchmark'), 16, 8);
end

%% Plot 2A: velocity error convergence
fig2a = figure('Name','Re1000VelocityError','NumberTitle','off');
clf

tl = tiledlayout(1,1,'TileSpacing','compact','Padding','compact');
ax = nexttile;

loglog(dxvec, ERROR(1,:), 'bo-', 'LineWidth', 1.5); hold on
loglog(dxvec, ERROR(2,:), 'rs-', 'LineWidth', 1.5)

loglog(dxvec, TC(1,:), '--', 'LineWidth', 1.0)
loglog(dxvec, TC(2,:), '--', 'LineWidth', 1.0, 'Color', [0.1333 0.5451 0.1333])
hold off

xlabel('\Deltax = 1/n', 'Interpreter','tex')
ylabel('||e||_{\infty}', 'Interpreter','tex')
title('Velocity error convergence, Re = 1000')

[dxTicks, idxTicks] = sort(dxvec(:), 'ascend');
nTicks = Nvec(idxTicks);

xticks(dxTicks)
xticklabels(arrayfun(@(n) sprintf('$1/%d$', n), nTicks, ...
    'UniformOutput', false))

set(ax, 'TickLabelInterpreter','latex')

lgd = legend( ...
    'u vertical', ...
    'v horizontal', ...
    sprintf('u fit: \\Deltax^{%.2f}', ROC(1)), ...
    sprintf('v fit: \\Deltax^{%.2f}', ROC(2)), ...
    'Orientation','horizontal', ...
    'Interpreter','tex');

lgd.Layout.Tile = 'south';
lgd.Box = 'on';

box on

grid on
grid minor
ax.GridAlpha = 0.10;
ax.MinorGridAlpha = 0.08;
ax.GridLineStyle = '-';
ax.MinorGridLineStyle = ':';

if saveRe1000Figures
    PlotToFileColorPDF(fig2a, ...
        fullfile(re1000_figures_dir, ...
        'Re1000_velocity_error_convergence'), 14, 8);
end

%% Plot 2B: pressure error convergence
fig2b = figure('Name','Re1000PressureError','NumberTitle','off');
clf

tl = tiledlayout(1,1,'TileSpacing','compact','Padding','compact');
ax = nexttile;

loglog(dxvec, ERROR(3,:), 'bd-', 'LineWidth', 1.5); hold on
loglog(dxvec, ERROR(4,:), 'r^-', 'LineWidth', 1.5)

loglog(dxvec, TC(3,:), '--', 'LineWidth', 1.0)
loglog(dxvec, TC(4,:), '--', 'LineWidth', 1.0, 'Color', [0.1333 0.5451 0.1333])
hold off

xlabel('\Deltax = 1/n', 'Interpreter','tex')
ylabel('||e||_{\infty}', 'Interpreter','tex')
title('Pressure error convergence, Re = 1000')

[dxTicks, idxTicks] = sort(dxvec(:), 'ascend');
nTicks = Nvec(idxTicks);

xticks(dxTicks)
xticklabels(arrayfun(@(n) sprintf('$1/%d$', n), nTicks, ...
    'UniformOutput', false))
set(ax, 'TickLabelInterpreter','latex')

lgd = legend( ...
    'p vertical', ...
    'p horizontal', ...
    sprintf('p_v fit: \\Deltax^{%.2f}', ROC(3)), ...
    sprintf('p_h fit: \\Deltax^{%.2f}', ROC(4)), ...
    'Orientation','horizontal', ...
    'Interpreter','tex');

lgd.Layout.Tile = 'south';
lgd.Box = 'on';

box on

grid on
grid minor
ax.GridAlpha = 0.10;
ax.MinorGridAlpha = 0.08;
ax.GridLineStyle = '-';
ax.MinorGridLineStyle = ':';

if saveRe1000Figures
    PlotToFileColorPDF(fig2b, ...
        fullfile(re1000_figures_dir, ...
        'Re1000_pressure_error_convergence'), 14, 8);
end

%% Plot 3: streamlines for coarse and fine grid
fig3 = figure('Name', 'Re1000StreamlinesComparison', ...
              'NumberTitle', 'off');
clf

plotIdx = [1 nRuns];

for jj = 1:2

    i = plotIdx(jj);
    rd = runData_all{i};

    n = rd.input.n;
    u = rd.fields.u;
    v = rd.fields.v;

    [dx, Xu, Yu, Xv, Yv, Xp, Yp, Xi, Yi] = StaggeredMesh2dSquare(n);

    uc = 0.5 * (u(2:n+1, 1:n)   + u(2:n+1, 2:n+1));
    vc = 0.5 * (v(1:n,   2:n+1) + v(2:n+1, 2:n+1));

    subplot(1, 2, jj)
    sl = streamslice(Xp, Yp, uc, vc);
    set(sl, 'Color', [0 0 1])
    axis equal tight
    xlim([0 1])
    ylim([0 1])
    xlabel('x')
    ylabel('y')
    title(sprintf('Streamlines, Re = 1000, n = %d', n))
    box on
end

if saveRe1000Figures
    PlotToFileColorPDF(fig3, ...
        fullfile(re1000_figures_dir, ...
        'Re1000_streamlines_comparison'), 16, 8);
end

%% Plot 4: pressure field on finest grid
fig4 = figure('Name', 'Re1000PressureFieldFinestGrid', ...
              'NumberTitle', 'off');
clf

rd = runData_all{end};

n = rd.input.n;
P = rd.fields.P;

[dx, Xu, Yu, Xv, Yv, Xp, Yp, Xi, Yi] = StaggeredMesh2dSquare(n);

ic = (n + 1) / 2;
P  = P - P(ic, ic);

% Extend the cell-centered pressure field to the physical boundaries
% for visualization only. The numerical pressure P remains unchanged.
xplot = [0, Xp(1,:), 1];
yplot = [0, Yp(:,1).', 1];

[Xplot, Yplot] = meshgrid(xplot, yplot);

Pplot = zeros(n+2, n+2);

Pplot(2:n+1, 2:n+1) = P;

% Homogeneous Neumann graphical extension
Pplot(2:n+1, 1)     = P(:,1);     % west boundary
Pplot(2:n+1, n+2)   = P(:,end);   % east boundary
Pplot(1, 2:n+1)     = P(1,:);     % south boundary
Pplot(n+2, 2:n+1)   = P(end,:);   % north boundary

% Corners
Pplot(1,1)       = P(1,1);
Pplot(1,n+2)     = P(1,end);
Pplot(n+2,1)     = P(end,1);
Pplot(n+2,n+2)   = P(end,end);

contourf(Xplot, Yplot, Pplot, 30, 'LineColor', 'none')
axis equal tight
xlim([0 1])
ylim([0 1])
xlabel('x')
ylabel('y')
title(sprintf('Pressure field, Re = 1000, n = %d', n))
colorbar
box on

if saveRe1000Figures
    PlotToFileColorPDF(fig4, ...
        fullfile(re1000_figures_dir, ...
        'Re1000_pressure_field_finest_grid'), 12, 8);
end
