%% *****************************************************************************
% File: NS2dEfficiencyAnalysis.m
%   Driver script for Task 7.
%   Compares the computational efficiency of two Poisson-solver strategies:
%     1) Direct backslash solve at each time step
%     2) Reordered LU factorization performed once before time stepping
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

%% Efficiency analysis parameters
Nvec = [21 31 41 61 81];

Re   = 1;
Ulid = -1;

maxstep    = 2000;
dt_user    = 1e-2;
steadytol  = 0;      % force all runs to perform maxstep steps
statstride = 250;    % print solver status every 250 iterations

useContinuityCorrection = true;

saveEfficiencyFigures = true;
saveEfficiencyResults = true;

%% Output folders
comparison_results_dir = fullfile(paths.results, 'efficiency');
comparison_figures_dir = fullfile(paths.figures, 'efficiency');

if ~exist(comparison_results_dir, 'dir')
    mkdir(comparison_results_dir);
end

if ~exist(comparison_figures_dir, 'dir')
    mkdir(comparison_figures_dir);
end

%% Initialize storage arrays
nRuns = length(Nvec);

Nunknowns = zeros(nRuns, 1);

time_NoLU = zeros(nRuns, 1);
time_LU   = zeros(nRuns, 1);

timeStep_NoLU = zeros(nRuns, 1);
timeStep_LU   = zeros(nRuns, 1);

steps_NoLU = zeros(nRuns, 1);
steps_LU   = zeros(nRuns, 1);

speedup = zeros(nRuns, 1);

runData_NoLU_all = cell(nRuns, 1);
runData_LU_all   = cell(nRuns, 1);

%% Main loop over grid sizes
for i = 1:nRuns

    n = Nvec(i);
    Nunknowns(i) = n^2;

    fprintf('\n============================================================\n');
    fprintf('EFFICIENCY ANALYSIS: n = %d, N = n^2 = %d\n', ...
            n, Nunknowns(i));
    fprintf('============================================================\n');

    %% Common configuration
    baseConfig = struct();

    baseConfig.n    = n;
    baseConfig.Re   = Re;
    baseConfig.Ulid = Ulid;

    baseConfig.maxstep    = maxstep;
    baseConfig.dt_user    = dt_user;
    baseConfig.steadytol  = steadytol;
    baseConfig.statstride = statstride;

    baseConfig.useContinuityCorrection = useContinuityCorrection;

    % Internal solver plots are disabled during timing.
    % Per-run figures could be generated later from runData.
    baseConfig.createPlots = false;
    baseConfig.saveFigures = false;
    baseConfig.saveResults = true;

    %% Case 1: direct backslash solve at each time step
    fprintf('\n------------------------------------------------------------\n');
    fprintf('Running NoLU case\n');
    fprintf('------------------------------------------------------------\n');

    runConfig = baseConfig;
    runConfig.useLUfactorization = false;
    runConfig.results_subdir = fullfile('efficiency', 'NoLU');
    runConfig.figures_subdir = fullfile('efficiency', 'NoLU');

    tic
    run(fullfile(solver_dir, 'NavierStokes2dMovingLidSquareCavityFlow.m'));
    time_NoLU(i) = toc;

    runData_NoLU = runData;
    runData_NoLU_all{i} = runData_NoLU;

    steps_NoLU(i) = runData_NoLU.numerics.step;
    timeStep_NoLU(i) = time_NoLU(i) / steps_NoLU(i);

    %% Case 2: reordered LU factorization reused at each time step
    fprintf('\n------------------------------------------------------------\n');
    fprintf('Running LU case\n');
    fprintf('------------------------------------------------------------\n');

    runConfig = baseConfig;
    runConfig.useLUfactorization = true;
    runConfig.results_subdir = fullfile('efficiency', 'LU');
    runConfig.figures_subdir = fullfile('efficiency', 'LU');

    tic
    run(fullfile(solver_dir, 'NavierStokes2dMovingLidSquareCavityFlow.m'));
    time_LU(i) = toc;

    runData_LU = runData;
    runData_LU_all{i} = runData_LU;

    steps_LU(i) = runData_LU.numerics.step;
    timeStep_LU(i) = time_LU(i) / steps_LU(i);

    %% Speedup
    speedup(i) = time_NoLU(i) / time_LU(i);

    %% Run summary
    fprintf('\n------------------------------------------------------------\n');
    fprintf('SUMMARY FOR n = %d\n', n);
    fprintf('------------------------------------------------------------\n');
    fprintf(' NoLU total time      : %.6e s\n', time_NoLU(i));
    fprintf(' LU total time        : %.6e s\n', time_LU(i));
    fprintf(' NoLU time per step   : %.6e s/step\n', timeStep_NoLU(i));
    fprintf(' LU time per step     : %.6e s/step\n', timeStep_LU(i));
    fprintf(' Speedup NoLU/LU      : %.6e\n', speedup(i));
    fprintf('============================================================\n');
end

%% Scaling analysis
p_total_NoLU = polyfit(log10(Nunknowns), log10(time_NoLU), 1);
p_total_LU   = polyfit(log10(Nunknowns), log10(time_LU), 1);

p_step_NoLU = polyfit(log10(Nunknowns), log10(timeStep_NoLU), 1);
p_step_LU   = polyfit(log10(Nunknowns), log10(timeStep_LU), 1);

fit_total_NoLU = 10.^polyval(p_total_NoLU, log10(Nunknowns));
fit_total_LU   = 10.^polyval(p_total_LU, log10(Nunknowns));

fit_step_NoLU = 10.^polyval(p_step_NoLU, log10(Nunknowns));
fit_step_LU   = 10.^polyval(p_step_LU, log10(Nunknowns));

%% Final comparison table
efficiencyTable = table( ...
    Nvec(:), ...
    Nunknowns, ...
    steps_NoLU, ...
    steps_LU, ...
    time_NoLU, ...
    time_LU, ...
    timeStep_NoLU, ...
    timeStep_LU, ...
    speedup, ...
    'VariableNames', { ...
    'n', ...
    'Nunknowns', ...
    'steps_NoLU', ...
    'steps_LU', ...
    'time_NoLU', ...
    'time_LU', ...
    'timePerStep_NoLU', ...
    'timePerStep_LU', ...
    'speedup_NoLU_over_LU'});

disp(efficiencyTable)

%% Final summary log
fprintf('\n============================================================\n');
fprintf('EFFICIENCY SCALING SUMMARY\n');
fprintf('------------------------------------------------------------\n');
fprintf('Total time scaling NoLU : time ~ N^{%.3f}\n', p_total_NoLU(1));
fprintf('Total time scaling LU   : time ~ N^{%.3f}\n', p_total_LU(1));
fprintf('Step time scaling NoLU  : time ~ N^{%.3f}\n', p_step_NoLU(1));
fprintf('Step time scaling LU    : time ~ N^{%.3f}\n', p_step_LU(1));
fprintf('Final speedup at n=%d   : %.3e\n', Nvec(end), speedup(end));
fprintf('============================================================\n');

fprintf('\n------------------------------------------------------------\n');
fprintf('EFFICIENCY PERFORMANCE SUMMARY\n');
fprintf('------------------------------------------------------------\n');
fprintf('Minimum speedup NoLU/LU : %.3e\n', min(speedup));
fprintf('Maximum speedup NoLU/LU : %.3e\n', max(speedup));
fprintf('Mean speedup NoLU/LU    : %.3e\n', mean(speedup));
fprintf('Speedup at finest grid  : %.3e\n', speedup(end));
fprintf('NoLU time finest grid   : %.3e s\n', time_NoLU(end));
fprintf('LU time finest grid     : %.3e s\n', time_LU(end));
fprintf('NoLU step time finest   : %.3e s/step\n', timeStep_NoLU(end));
fprintf('LU step time finest     : %.3e s/step\n', timeStep_LU(end));
fprintf('============================================================\n');

%% Save comparison data
if saveEfficiencyResults
    save(fullfile(comparison_results_dir, ...
        'NS2d_efficiency_comparison.mat'), ...
        'efficiencyTable', ...
        'runData_NoLU_all', ...
        'runData_LU_all', ...
        'Nvec', ...
        'Nunknowns', ...
        'time_NoLU', ...
        'time_LU', ...
        'timeStep_NoLU', ...
        'timeStep_LU', ...
        'speedup', ...
        'p_total_NoLU', ...
        'p_total_LU', ...
        'p_step_NoLU', ...
        'p_step_LU');

    writetable(efficiencyTable, ...
        fullfile(comparison_results_dir, ...
        'NS2d_efficiency_comparison.csv'));
end

%% Comparative plot 1: total CPU time
fig1 = figure('Name', 'EfficiencyTotalCPUTime', ...
              'NumberTitle', 'off');
clf
loglog(Nunknowns, time_NoLU, 'bo-', 'LineWidth', 1.5)
hold on
loglog(Nunknowns, time_LU, 'rs-', 'LineWidth', 1.5)
loglog(Nunknowns, fit_total_NoLU, '--', 'LineWidth', 1.2)
loglog(Nunknowns, fit_total_LU, '--', 'LineWidth', 1.2, 'Color', [0.1333 0.5451 0.1333])
hold off

ax = gca;
grid on
ax.GridAlpha = 0.10;
ax.MinorGridAlpha = 0.08;
ax.GridLineStyle = '-';
ax.MinorGridLineStyle = ':';

xlabel('N = n^2', 'Interpreter', 'tex')
ylabel('Total CPU time [s]')
title('Total CPU time comparison')
legend( ...
    'No LU', ...
    'LU reuse', ...
    sprintf('No LU fit: N^{%.2f}', p_total_NoLU(1)), ...
    sprintf('LU fit: N^{%.2f}', p_total_LU(1)), ...
    'Location', 'southoutside', ...
    'Interpreter', 'tex', ...
    'NumColumns', 4)

box on

set(fig1, 'Units', 'centimeters');
set(fig1, 'Position', [2 2 16 12]);
    
drawnow
    
if saveEfficiencyFigures
    exportgraphics(fig1, ...
    fullfile(comparison_figures_dir, 'efficiency_total_cpu_time.pdf'), ...
    'ContentType', 'vector');
end

%% Comparative plot 2: CPU time per timestep
fig2 = figure('Name', 'EfficiencyCPUTimePerStep', ...
              'NumberTitle', 'off');
clf
loglog(Nunknowns, timeStep_NoLU, 'bo-', 'LineWidth', 1.5)
hold on
loglog(Nunknowns, timeStep_LU, 'rs-', 'LineWidth', 1.5)
loglog(Nunknowns, fit_step_NoLU, '--', 'LineWidth', 1.2)
loglog(Nunknowns, fit_step_LU, '--', 'LineWidth', 1.2, 'Color', [0.1333 0.5451 0.1333])
hold off

ax = gca;
grid on
ax.GridAlpha = 0.10;
ax.MinorGridAlpha = 0.08;
ax.GridLineStyle = '-';
ax.MinorGridLineStyle = ':';

xlabel('N = n^2', 'Interpreter', 'tex')
ylabel('CPU time per timestep [s/step]')
title('CPU time per timestep comparison')
legend(...
    'No LU', ...
    'LU reuse', ...
    sprintf('No LU fit: N^{%.2f}', p_step_NoLU(1)), ...
    sprintf('LU fit: N^{%.2f}', p_step_LU(1)), ...
    'Location', 'southoutside', ...
    'Interpreter', 'tex', ...
    'NumColumns', 4)

box on

all_data = [timeStep_NoLU(:); timeStep_LU(:); fit_step_NoLU(:); fit_step_LU(:)];
y_min = min(all_data);
y_max = max(all_data);

ylim([y_min * 0.8, y_max * 1.2]);

set(fig2, 'Units', 'centimeters');
set(fig2, 'Position', [2 2 16 12]);
    
drawnow
    
if saveEfficiencyFigures
    exportgraphics(fig2, ...
    fullfile(comparison_figures_dir, 'efficiency_cpu_time_per_step.pdf'), ...
    'ContentType', 'vector');
end

%% Comparative plot 3: speedup
fig3 = figure('Name', 'EfficiencySpeedup', ...
              'NumberTitle', 'off');
clf
plot(Nunknowns, speedup, 'bo-', 'LineWidth', 1.5)
xlabel('N = n^2', 'Interpreter', 'tex')
ylabel('Speedup NoLU / LU')
title('Speedup obtained by LU reuse')

box on

if saveEfficiencyFigures
    PlotToFileColorPDF(fig3, ...
        fullfile(comparison_figures_dir, ...
        'efficiency_speedup'), 12, 8);
end
