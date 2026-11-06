%% *****************************************************************************
% File: NS2dRunRe1NoCCvsCC.m
%   Driver script for Task 5 and Task 6.
%   It runs the Re = 1 lid-driven cavity case twice:
%     1) without Discrete Continuity Correction
%     2) with Discrete Continuity Correction
%
%   The same main solver is used in both cases by passing the runConfig
%   structure to NavierStokes2dMovingLidSquareCavityFlow.m.
%
%   Author      : Giulio La Sala
%   Date        : Sunday 17/05/2026
%   Version     : Final
%*******************************************************************************

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

%% Common run configuration
baseConfig = struct();

baseConfig.n    = 21;
baseConfig.Re   = 1;
baseConfig.Ulid = -1;

baseConfig.maxstep    = 50000;
baseConfig.dt_user    = 1e-2;
baseConfig.steadytol  = 1e-4;
baseConfig.statstride = 100;

baseConfig.useLUfactorization = false;

baseConfig.createPlots = true;
baseConfig.saveFigures = true;
baseConfig.saveResults = true;

%% Case 1: without Discrete Continuity Correction
fprintf('\n============================================================\n');
fprintf('TASK 5 RUN: Re = 1 without continuity correction\n');
fprintf('============================================================\n');

runConfig = baseConfig;
runConfig.useContinuityCorrection = false;
runConfig.results_subdir = fullfile('Re1', 'NoCC');
runConfig.figures_subdir = fullfile('Re1', 'NoCC');

run(fullfile(solver_dir, 'NavierStokes2dMovingLidSquareCavityFlow.m'));

runData_NoCC = runData;

%% Case 2: with Discrete Continuity Correction
fprintf('\n============================================================\n');
fprintf('TASK 6 RUN: Re = 1 with continuity correction\n');
fprintf('============================================================\n');

runConfig = baseConfig;
runConfig.useContinuityCorrection = true;
runConfig.results_subdir = fullfile('Re1', 'CC');
runConfig.figures_subdir = fullfile('Re1', 'CC');

run(fullfile(solver_dir, 'NavierStokes2dMovingLidSquareCavityFlow.m'));

runData_CC = runData;

%% Comparison quantities
cmc_NoCC = runData_NoCC.history.cmchist;
cmc_CC   = runData_CC.history.cmchist;

gmc_NoCC = runData_NoCC.history.gmchist;
gmc_CC   = runData_CC.history.gmchist;

steady_NoCC = runData_NoCC.history.steadyhist;
steady_CC   = runData_CC.history.steadyhist;

t_NoCC = runData_NoCC.history.thist;
t_CC   = runData_CC.history.thist;

steps_NoCC = runData_NoCC.numerics.step;
steps_CC   = runData_CC.numerics.step;

%% Comparison summary
fprintf('\n============================================================\n');
fprintf('COMPARISON SUMMARY (NoCC vs CC)\n');
fprintf('------------------------------------------------------------\n');
fprintf(' cmc(1)        NoCC : %.3e | CC : %.3e\n', cmc_NoCC(1), cmc_CC(1));

if numel(cmc_NoCC) >= 10 && numel(cmc_CC) >= 10
    fprintf(' cmc(10)       NoCC : %.3e | CC : %.3e\n', cmc_NoCC(10), cmc_CC(10));
end

fprintf(' cmc(end)      NoCC : %.3e | CC : %.3e\n', cmc_NoCC(end), cmc_CC(end));
fprintf(' gmchist(end)  NoCC : %.3e | CC : %.3e\n', gmc_NoCC(end), gmc_CC(end));
fprintf(' steps         NoCC : %d | CC : %d\n', steps_NoCC, steps_CC);
fprintf(' final time    NoCC : %.3e | CC : %.3e\n', t_NoCC(end), t_CC(end));
fprintf(' steady(end)   NoCC : %.3e | CC : %.3e\n', steady_NoCC(end), steady_CC(end));

if cmc_CC(end) ~= 0
    fprintf(' Improvement ratio NoCC/CC : %.3e\n', cmc_NoCC(end) / cmc_CC(end));
end

fprintf('============================================================\n');

%% Comparison output folders
comparison_results_dir = fullfile(paths.results, 'Re1', 'comparisons');
comparison_figures_dir = fullfile(paths.figures, 'Re1', 'comparisons');

if ~exist(comparison_results_dir, 'dir')
    mkdir(comparison_results_dir);
end

if ~exist(comparison_figures_dir, 'dir')
    mkdir(comparison_figures_dir);
end

%% Save comparison data
comparison_file = fullfile(comparison_results_dir, ...
    'comparison_Re1_NoCC_vs_CC.mat');

save(comparison_file, 'runData_NoCC', 'runData_CC');

%% Plot 1: local mass conservation comparison
fig1 = figure('Name', 'Re1MassConservationNoCCvsCC', ...
              'NumberTitle', 'off');
clf
semilogy(t_NoCC, cmc_NoCC, 'b-', 'LineWidth', 1.5)
hold on
semilogy(t_CC, cmc_CC, 'LineWidth', 1.5, 'Color',[0.1333 0.5451 0.1333])
hold off
xlabel('t')
ylabel('||cmc||_{\infty}', 'Interpreter', 'tex')
title('Local mass conservation, Re = 1')
legend('No correction', 'With correction', 'Location', 'best')

box on

ax = gca;
grid on
ax.GridAlpha = 0.10;
ax.MinorGridAlpha = 0.08;
ax.GridLineStyle = '-';
ax.MinorGridLineStyle = ':';

set(fig1, 'Units', 'centimeters');
set(fig1, 'Position', [2 2 12 8]);
    
drawnow
    
if baseConfig.saveFigures
    exportgraphics(fig1, ...
    fullfile(comparison_figures_dir, 'Re1_mass_conservation_NoCC_vs_CC.pdf'), ...
    'ContentType', 'vector');
end

%% Plot 2: global mass conservation comparison
fig2 = figure('Name', 'Re1GlobalMassConservationNoCCvsCC', ...
              'NumberTitle', 'off');
clf
semilogy(t_NoCC, abs(gmc_NoCC), 'b-', 'LineWidth', 1.5)
hold on
semilogy(t_CC, abs(gmc_CC), 'LineWidth', 1.5, 'Color', [0.1333 0.5451 0.1333])
hold off
xlabel('t')
ylabel('|sum(cmc)|', 'Interpreter', 'tex')
title('Global mass conservation, Re = 1')
legend('No correction', 'With correction', 'Location', 'best')

box on

ax = gca;
grid on
ax.GridAlpha = 0.10;
ax.MinorGridAlpha = 0.08;
ax.GridLineStyle = '-';
ax.MinorGridLineStyle = ':';

set(fig2, 'Units', 'centimeters');
set(fig2, 'Position', [2 2 12 8]);
    
drawnow
    
if baseConfig.saveFigures
    exportgraphics(fig2, ...
    fullfile(comparison_figures_dir, 'Re1_global_mass_conservation_NoCC_vs_CC.pdf'), ...
    'ContentType', 'vector');
end

%% Plot 3: steady-state convergence comparison
fig3 = figure('Name', 'Re1SteadyNoCCvsCC', ...
              'NumberTitle', 'off');
clf
semilogy(t_NoCC, steady_NoCC, 'b-', 'LineWidth', 1.5)
hold on
semilogy(t_CC, steady_CC, 'LineStyle', '--', 'LineWidth', 1.5, 'Color',[0.1333 0.5451 0.1333])
yline(baseConfig.steadytol, 'r--', 'LineWidth', 1.5)
hold off
xlabel('t')
ylabel('$\max\left(\frac{|\Delta U|}{\Delta t}\right)$', 'Interpreter', 'latex')
title('Steady-state convergence, Re = 1')
legend('No correction', 'With correction', 'steadytol', ...
       'Location', 'best')

box on

ax = gca;
grid on
ax.GridAlpha = 0.10;
ax.MinorGridAlpha = 0.08;
ax.GridLineStyle = '-';
ax.MinorGridLineStyle = ':';

set(fig3, 'Units', 'centimeters');
set(fig3, 'Position', [2 2 12 8]);
    
drawnow
    
if baseConfig.saveFigures
    exportgraphics(fig3, ...
    fullfile(comparison_figures_dir, 'Re1_steady_history_NoCC_vs_CC.pdf'), ...
    'ContentType', 'vector');
end