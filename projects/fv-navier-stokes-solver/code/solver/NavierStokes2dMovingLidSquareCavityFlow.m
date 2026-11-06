%% ************************************************************************
% File: NavierStokes2dMovingLidSquareCavityFlow.m
%   Script for simulation of the translating lid-driven square cavity flow
%   governed by the nondimensional incompressible unsteady 2D Navier-Stokes
%   equations.
%
%   The numerical model is based on:
%     - Finite Volume Method (FVM)
%     - Uniform staggered Cartesian mesh
%     - Central Difference Scheme (CDS) for all spatial operators
%     - Explicit Euler time integration of the momentum equations
%     - Pressure computed from a Poisson equation obtained from the
%       divergence of the momentum equations
%
%   The basic solution strategy is:
%     1) compute H1 and H2 from the current velocity field
%     2) assemble the Poisson right-hand side from the discrete divergence of H
%     3) solve the pressure Poisson equation
%     4) compute velocity time derivatives
%     5) advance the velocity field with explicit Euler
%     6) apply boundary conditions
%     7) monitor mass conservation and steady-state convergence
%
%   The time integration is terminated when either:
%     - the maximum number of time steps is reached, or
%     - a steady-state criterion is satisfied, defined as
%           max(dumax,dvmax) < steadytol
%       where dumax and dvmax are the maximum rates of change of the
%       horizontal and vertical velocity fields, respectively.
%
%   Optional solver extensions:
%     - Reordered LU factorization of the time-invariant Poisson matrix
%     - Discrete continuity correction in the Poisson source term
%
% Input parameters:
%   n          : Number of cells along the x- and y-directions
%   Re         : Reynolds number
%   Ulid       : Lid velocity (+/-1), use Ulid = -1 for benchmark convention
%   maxstep    : Maximum number of explicit Euler time steps
%   dt_user    : User-prescribed time step
%   steadytol  : Steady-state tolerance on max(|du/dt|,|dv/dt|)
%   statstride : Stride for writing status information to screen
%
% Numerical options:
%   useLUfactorization      : Reuse reordered LU factors for pressure solve
%   useContinuityCorrection : Add discrete continuity correction to Poisson RHS
%   createPlots             : Generate post-processing figures
%   saveFigures             : Save generated figures to file
%   saveResults             : Save final run data to MAT-file
%
% Main computed quantities:
%   u          : Horizontal velocity field on u-grid, size (n+2) x (n+1)
%   v          : Vertical velocity field on v-grid, size (n+1) x (n+2)
%   P          : Pressure field on p-grid, size n x n
%   s          : Poisson equation source term on p-grid, size n x n
%   cmc        : Cell-wise mass conservation residual on p-grid, size n x n
%   gmchist    : Global mass conservation history, sum(cmc(:))
%   cmchist    : Maximum local mass conservation history, ||cmc||_inf
%   steadyhist : Maximum velocity rate-of-change history
%   thist      : Physical time history
%   pminhist   : Minimum pressure history
%   pmaxhist   : Maximum pressure history
%
% Saved output:
%   A single MAT-file containing a struct named "runData" with:
%     - metadata
%     - input parameters
%     - numerical options
%     - numerical quantities
%     - selected mesh information for post-processing
%     - final solution fields
%     - time histories
%
% Generated plots (optional):
%   1) Velocity streamlines
%   2) Pressure contours
%   3) Mass conservation history
%   4) Steady-state history
%   5) Final divergence field (cmc)
%   6) Velocity quiver plot
%
%   Author      : Giulio La Sala
%   Date        : Sunday 17/05/2026
%   Version     : Final
%**************************************************************************

%% Clear workspace
if ~exist('runConfig', 'var')
    clear
    close all
    clc
else
    close all
end

%% Setup project paths
% Add startup folder to path and initialize project directories.
this_file   = mfilename('fullpath');
current_dir = fileparts(this_file);
project_dir = fileparts(current_dir);
startup_dir = fullfile(project_dir, 'startup');

addpath(startup_dir);
paths = setupPaths();

%% Input parameters
% If the solver is launched from an external driver script, the structure
% runConfig can be used to overwrite the default parameters below.

if ~exist('runConfig', 'var')
    runConfig = struct();
end

% Physical parameters
if ~isfield(runConfig, 'n')
    runConfig.n = 7;
end

if ~isfield(runConfig, 'Re')
    runConfig.Re = 3;
end

if ~isfield(runConfig, 'Ulid')
    runConfig.Ulid = -1;
end

% Time integration and stopping criteria
if ~isfield(runConfig, 'maxstep')
    runConfig.maxstep = 2;
end

if ~isfield(runConfig, 'dt_user')
    runConfig.dt_user = 1e-2;
end

if ~isfield(runConfig, 'steadytol')
    runConfig.steadytol = 1e-4;
end

if ~isfield(runConfig, 'statstride')
    runConfig.statstride = 100;
end

% Solver options
if ~isfield(runConfig, 'useLUfactorization')
    runConfig.useLUfactorization = false;
end

if ~isfield(runConfig, 'useContinuityCorrection')
    runConfig.useContinuityCorrection = false;
end

if ~isfield(runConfig, 'createPlots')
    runConfig.createPlots = true;
end

if ~isfield(runConfig, 'saveFigures')
    runConfig.saveFigures = true;
end

if ~isfield(runConfig, 'saveResults')
    runConfig.saveResults = true;
end

% Copy configuration values to local variables used by the solver
n    = runConfig.n;
Re   = runConfig.Re;
Ulid = runConfig.Ulid;

maxstep    = runConfig.maxstep;
dt_user    = runConfig.dt_user;
steadytol  = runConfig.steadytol;
statstride = runConfig.statstride;

useLUfactorization      = runConfig.useLUfactorization;
useContinuityCorrection = runConfig.useContinuityCorrection;
createPlots             = runConfig.createPlots;
saveFigures             = runConfig.saveFigures;
saveResults             = runConfig.saveResults;

%% Run name and output folders
% Build a descriptive run name compatible with the benchmark style.
dt_tag = strrep(sprintf('%.0e', dt_user), 'e-0', 'e-');
dt_tag = strrep(dt_tag, 'e+0', 'e+');

run_name = sprintf('solution_n%d_Re%g_Ulid%g_step%d_dt%s', ...
                   n, Re, Ulid, maxstep, dt_tag);


% Results directory
if exist('runConfig','var') && isfield(runConfig,'results_subdir')
    results_solver_dir = fullfile(paths.results, runConfig.results_subdir);
else
    results_solver_dir = paths.results_solver;
end

% Figures directory
if exist('runConfig','var') && isfield(runConfig,'figures_subdir')
    figures_solver_dir = fullfile(paths.figures, runConfig.figures_subdir);
else
    figures_solver_dir = paths.figures_solver;
end

% Final run-specific folders
run_results_dir = fullfile(results_solver_dir, run_name);
run_figures_dir = fullfile(figures_solver_dir, run_name);

% Create directories if needed
if ~exist(run_results_dir, 'dir')
    mkdir(run_results_dir);
end

% Create directories if needed
if saveResults && ~exist(run_results_dir, 'dir')
    mkdir(run_results_dir);
end

if saveFigures && ~exist(run_figures_dir, 'dir')
    mkdir(run_figures_dir);
end

%% Assemble staggered mesh
[dx, Xu, Yu, Xv, Yv, Xp, Yp, Xi, Yi] = StaggeredMesh2dSquare(n);

%% Initialize solution fields
% Velocity fields are initialized to zero, except for the imposed lid motion.
u = zeros(n+2, n+1);   % horizontal velocity on u-grid
v = zeros(n+1, n+2);   % vertical velocity on v-grid
u(n+2, :) = Ulid;      % moving north lid

% Pressure and diagnostic arrays
P          = zeros(n, n);        % pressure field on p-grid
s          = zeros(n, n);        % Poisson rhs
cmc        = zeros(n, n);        % cell-wise mass conservation residual
gmchist    = zeros(1, maxstep);  % global mass conservation history
cmchist    = zeros(1, maxstep);  % maximum local mass conservation history
steadyhist = zeros(1, maxstep);  % max velocity rate-of-change history
thist      = zeros(1, maxstep);  % physical time history
pminhist   = zeros(1, maxstep);  % minimum pressure history
pmaxhist   = zeros(1, maxstep);  % maximum pressure history

%% Stability limits for explicit Euler time stepping
% The time step is restricted by:
%   (i) diffusive stability limit (derived from linear stability analysis)
%   (ii) convective CFL condition (practical constraint for nonlinear NS)

% Velocity scale for CFL condition
Uscale = max([abs(Ulid); abs(u(:)); abs(v(:)); eps]);

% Diffusive stability limit
dt_diff = Re * dx^2 / 4;

% Convective stability limit (CFL condition)
CFL = 0.5;   % safety factor (0 < CFL <= 1)
dt_conv = CFL * dx / Uscale;

% Final time step
dt = min([dt_user, dt_diff, dt_conv]);

%% Write run information to screen
fprintf('============================================================\n');
fprintf('Navier-Stokes 2D lid-driven cavity solver\n');
fprintf('------------------------------------------------------------\n');
fprintf('Run name               : %s\n', run_name);
fprintf('n                      : %d\n', n);
fprintf('dx                     : %.6e\n', dx);
fprintf('Re                     : %.6e\n', Re);
fprintf('Ulid                   : %.6e\n', Ulid);
fprintf('dt_user                : %.6e\n', dt_user);
fprintf('dt_diff                : %.6e\n', dt_diff);
fprintf('dt_conv (initial)      : %.6e\n', dt_conv);
fprintf('dt_used                : %.6e\n', dt);
fprintf('steadytol              : %.6e\n', steadytol);
fprintf('maxstep                : %d\n', maxstep);
fprintf('useLUfactorization     : %d\n', useLUfactorization);
fprintf('useContinuityCorrection: %d\n', useContinuityCorrection);
fprintf('saveResults            : %d\n', saveResults);
fprintf('createPlots            : %d\n', createPlots);
fprintf('saveFigures            : %d\n', saveFigures);
fprintf('============================================================\n');

%% Assemble and optionally factorize Laplacian operator matrix
A = NS2dLaplaceMatrix(n);

% Fix one pressure degree of freedom to remove singularity of the pure
% Neumann problem.
Afix = A;
Afix(1, :) = 0;
Afix(1, 1) = 1;

if useLUfactorization
    q = colamd(Afix);
    [L, U, pperm] = lu(Afix(q, q), 'vector');
else
    q     = [];
    L     = [];
    U     = [];
    pperm = [];
end

%% Time integration loop
for step = 1:maxstep

    % Store previous velocity fields for steady-state monitoring.
    u_old = u;
    v_old = v;

    %% Compute H1 and H2
    [H1, H2] = NS2dHfunctions(n, dx, Re, u, v);

    %% Assemble Poisson source term
    % H1 size: n x (n+1)
    % H2 size: (n+1) x n
    % s  size: n x n
    s = NS2dBuildPoissonRHS(n, dx, H1, H2);

    % Optional discrete continuity correction.
     if useContinuityCorrection
        divU = ((u(2:n+1, 2:n+1) - u(2:n+1, 1:n)) + ...
                (v(2:n+1, 2:n+1) - v(1:n, 2:n+1))) / dx;
        
        s = s + (dx^2 / dt) * divU;
    end
    
    %% Solve Poisson equation for pressure
    rhs    = s(:);
    rhs(1) = 0;   

    if useLUfactorization
        rhs_q    = rhs(q);
        y        = L \ rhs_q(pperm);
        p_q      = U \ y;

        p_vec    = zeros(n^2, 1);
        p_vec(q) = p_q;
        P        = reshape(p_vec, n, n);
    else
        P = reshape(Afix \ rhs, n, n);
    end

    % Normalize pressure to zero mean
    P = P - mean(P(:));

    %% Compute velocity time derivatives
    dpdx_u = (P(:, 2:n) - P(:, 1:n-1)) / dx;   % size n x (n-1)
    dpdy_v = (P(2:n, :) - P(1:n-1, :)) / dx;   % size (n-1) x n

    dudt = H1(:, 2:n) - dpdx_u;   % size n x (n-1)
    dvdt = H2(2:n, :) - dpdy_v;   % size (n-1) x n

    %% Advance velocity field one step with explicit Euler
    u(2:n+1, 2:n)   = u(2:n+1, 2:n)   + dt * dudt;
    v(2:n,   2:n+1) = v(2:n,   2:n+1) + dt * dvdt;

    %% Apply boundary conditions
    % u boundary conditions
    u(1, :)   = 0;      % south wall
    u(:, 1)   = 0;      % west wall
    u(:, n+1) = 0;      % east wall
    u(n+2, :) = Ulid;   % north moving lid

    % v boundary conditions
    v(:, 1)   = 0;      % west wall
    v(:, n+2) = 0;      % east wall
    v(1, :)   = 0;      % south wall
    v(n+1, :) = 0;      % north wall

    %% Compute cell-wise mass conservation residual
    cmc = (u(2:n+1, 2:n+1) - u(2:n+1, 1:n)) / dx + ...
          (v(2:n+1, 2:n+1) - v(1:n, 2:n+1)) / dx;

    gmchist(step) = sum(cmc(:));
    cmchist(step) = norm(cmc(:), inf);

    %% Compute steady-state history
    du = u - u_old;
    dv = v - v_old;

    dumax = norm(du(:), inf) / dt;
    dvmax = norm(dv(:), inf) / dt;

    steadyhist(step) = max(dumax, dvmax);
    thist(step)      = step * dt;
    pminhist(step)   = min(P(:));
    pmaxhist(step)   = max(P(:));

    %% Write status message
    if mod(step, statstride) == 0 || step == 1
        fprintf(['step = %8d | t = %12.5e | max(dU/dt) = %12.5e | ', ...
                 'max|divU| = %12.5e | sum(divU) = %12.5e | ', ...
                 'min(P) = %12.5e | max(P) = %12.5e\n'], ...
                 step, thist(step), steadyhist(step), ...
                 cmchist(step), gmchist(step), pminhist(step), pmaxhist(step));
    end

    %% Stop if steady-state criterion is reached
    if steadyhist(step) < steadytol
        fprintf('Steady-state criterion reached at step %d.\n', step);
        break
    end
end

%% Truncate histories to actual number of time steps performed
gmchist    = gmchist(1:step);
cmchist    = cmchist(1:step);
steadyhist = steadyhist(1:step);
thist      = thist(1:step);
pminhist   = pminhist(1:step);
pmaxhist   = pmaxhist(1:step);

%% Final summary log
fprintf('\n============================================================\n');
fprintf('FINAL SUMMARY\n');
fprintf('------------------------------------------------------------\n');
fprintf('Steps performed        : %d\n', step);
fprintf('Final time             : %.6e\n', thist(end));
fprintf('Steady criterion met   : %d\n', steadyhist(end) < steadytol);
fprintf('Final max(dU/dt)       : %.6e\n', steadyhist(end));
fprintf('Final max|divU|        : %.6e\n', cmchist(end));
fprintf('Final sum(divU)        : %.6e\n', gmchist(end));
fprintf('Pressure min/max       : [%.6e , %.6e]\n', min(P(:)), max(P(:)));
fprintf('dt used                : %.6e\n', dt);
fprintf('============================================================\n');

%% Save results to MAT file in a structured format
if saveResults
    results_file = fullfile(run_results_dir, [run_name '.mat']);

    runData = struct();

    % Metadata
    runData.metadata = struct( ...
        'run_name',    run_name, ...
        'script_name', mfilename, ...
        'author',      'Giulio La Sala', ...
        'date',        'Sunday 17/05/2026', ...
        'version',     'Final');

    % Input parameters
    runData.input = struct( ...
        'n',          n, ...
        'Re',         Re, ...
        'Ulid',       Ulid, ...
        'maxstep',    maxstep, ...
        'dt_user',    dt_user, ...
        'steadytol',  steadytol, ...
        'statstride', statstride);

    % Numerical options
    runData.options = struct( ...
        'useLUfactorization',      useLUfactorization, ...
        'useContinuityCorrection', useContinuityCorrection, ...
        'createPlots',             createPlots, ...
        'saveFigures',             saveFigures, ...
        'saveResults',             saveResults);

    % Numerical quantities
    runData.numerics = struct( ...
        'dx',      dx, ...
        'dt',      dt, ...
        'dt_diff', dt_diff, ...
        'dt_conv', dt_conv, ...
        'step',    step);

    % Mesh information for direct plotting/post-processing
    runData.mesh = struct( ...
        'Xp', Xp, ...
        'Yp', Yp);

    % Final solution fields
    runData.fields = struct( ...
        'u',   u, ...
        'v',   v, ...
        'P',   P, ...
        's',   s, ...
        'cmc', cmc);

    % Time histories
    runData.history = struct( ...
        'thist',      thist, ...
        'gmchist',    gmchist, ...
        'cmchist',    cmchist, ...
        'steadyhist', steadyhist, ...
        'pminhist',   pminhist, ...
        'pmaxhist',   pmaxhist);

    save(results_file, 'runData');
end

%% Plots
if createPlots

    %% Prepare cell-centered velocity field for visualization
    uc = 0.5 * (u(2:n+1, 1:n)   + u(2:n+1, 2:n+1));
    vc = 0.5 * (v(1:n,   2:n+1) + v(2:n+1, 2:n+1));
    
    %% Figures
    % Plot 1: streamlines
    fig1 = figure('Name', 'Streamlines', 'NumberTitle', 'off');
    clf
    sl = streamslice(Xp, Yp, uc, vc);
    set(sl, 'Color', [0 0 1])   
    axis equal tight
    xlim([0 1])
    ylim([0 1])
    xlabel('x')
    ylabel('y')
    title(sprintf('Streamlines, Re = %-3.2e, n = %i, step = %i, dt = %-4.3e', Re, n, step, dt))
    box on
    if saveFigures
        PlotToFileColorPDF(fig1, fullfile(run_figures_dir, 'streamlines'), 12, 8);
    end

    % Plot 2: pressure contours
    fig2 = figure('Name', 'PressureField', 'NumberTitle', 'off');
    clf
    
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
    
    contourf(Xplot, Yplot, Pplot, 20, 'LineColor', 'none')
    axis equal tight
    xlim([0 1])
    ylim([0 1])
    xlabel('x')
    ylabel('y')

    title(sprintf('Pressure field, Re = %-3.2e, n = %i, step = %i, dt = %-4.3e', Re, n, step, dt))
    colorbar
    box on
    
    if saveFigures
        PlotToFileColorPDF(fig2, ...
            fullfile(run_figures_dir, 'pressure_contours'), 16, 12);
    end

    % Plot 3: mass conservation history
    fig3 = figure('Name', 'MassConservationHistory', 'NumberTitle', 'off');
    clf
    
    semilogy(thist, cmchist, 'r-', 'LineWidth', 1.5)
    hold on
    semilogy(thist, abs(gmchist), 'b-', 'LineWidth', 1.5)
    hold off
    
    xlabel('t')
    ylabel('Magnitude')
    title(sprintf('Mass conservation history, Re = %-3.2e, n = %i, step = %i, dt = %-4.3e', Re, n, step, dt))
    
    legend('||cmc||_{\infty}', '|sum(cmc)|', ...
           'Location', 'best', 'Interpreter', 'tex')
    
    box on
    
    ax = gca;
    grid on
    grid minor
    ax.GridAlpha = 0.10;
    ax.MinorGridAlpha = 0.05;
    ax.GridLineStyle = '-';
    ax.MinorGridLineStyle = ':';
    
    set(fig3, 'Units', 'centimeters');
    set(fig3, 'Position', [2 2 12 8]);
    
    drawnow
    
    if saveFigures
        exportgraphics(fig3, ...
            fullfile(run_figures_dir, 'mass_conservation_history.pdf'), ...
            'ContentType', 'vector');
    end

    % Plot 4: steady-state history
    fig4 = figure('Name', 'SteadyStateHistory', 'NumberTitle', 'off');
    clf
    
    semilogy(thist, steadyhist, ...
        'LineWidth', 1.5, ...
        'Color', [0.1333 0.5451 0.1333])
    
    hold on
    yline(steadytol, 'r--', 'LineWidth', 1.5)
    hold off
    
    xlabel('t')
    ylabel('$\max\left(|\Delta U|/\Delta t\right)$', 'Interpreter', 'latex')
    
    title(sprintf('Steady-state history, Re = %-3.2e, n = %i, step = %i, dt = %-4.3e', Re, n, step, dt))
    
    legend('steady history', 'steady tolerance', 'Location', 'east')
    
    box on
    
    ax = gca;
    grid on
    grid minor
    ax.GridAlpha = 0.10;
    ax.MinorGridAlpha = 0.05;
    ax.GridLineStyle = '-';
    ax.MinorGridLineStyle = ':';
    
    set(fig4, 'Units', 'centimeters');
    set(fig4, 'Position', [2 2 12 8]);
    
    drawnow
    
    if saveFigures
        exportgraphics(fig4, ...
            fullfile(run_figures_dir, 'steady_history.pdf'), ...
            'ContentType', 'vector');
    end

    % Plot 5: final divergence field
    fig5 = figure('Name', 'DivergenceField', 'NumberTitle', 'off');
    clf
    
    % Extend the cell-centered divergence field to the physical boundaries
    % for visualization only. The numerical cmc field remains unchanged.
    xplot = [0, Xp(1,:), 1];
    yplot = [0, Yp(:,1).', 1];
    
    [Xplot, Yplot] = meshgrid(xplot, yplot);
    
    cmcplot = zeros(n+2, n+2);
    
    cmcplot(2:n+1, 2:n+1) = cmc;
    
    % Graphical extension to the boundaries
    cmcplot(2:n+1, 1)     = cmc(:,1);     % west boundary
    cmcplot(2:n+1, n+2)   = cmc(:,end);   % east boundary
    cmcplot(1, 2:n+1)     = cmc(1,:);     % south boundary
    cmcplot(n+2, 2:n+1)   = cmc(end,:);   % north boundary
    
    % Corners
    cmcplot(1,1)       = cmc(1,1);
    cmcplot(1,n+2)     = cmc(1,end);
    cmcplot(n+2,1)     = cmc(end,1);
    cmcplot(n+2,n+2)   = cmc(end,end);
    
    contourf(Xplot, Yplot, cmcplot, 20, 'LineColor', 'none')
    axis equal tight
    xlim([0 1])
    ylim([0 1])
    xlabel('x')
    ylabel('y')
    title(sprintf('Final cell-wise mass conservation residual, Re = %-3.2e, n = %i', Re, n))
    colorbar
    box on
    
    if saveFigures
        PlotToFileColorPDF(fig5, ...
            fullfile(run_figures_dir, 'divergence_field'), 16, 12);
    end

    % Plot 6: velocity quiver plot
    fig6 = figure('Name', 'VelocityQuiver', 'NumberTitle', 'off');
    clf
    q = quiver(Xp, Yp, uc, vc);
    set(q, 'Color', [0 0 1])   
    axis equal tight
    xlim([0 1])
    ylim([0 1])
    xlabel('x')
    ylabel('y')
    title(sprintf('Velocity vector field, Re = %-3.2e, n = %i, step = %i, dt = %-4.3e', Re, n, step, dt))
    box on
    if saveFigures
        PlotToFileColorPDF(fig6, fullfile(run_figures_dir, 'velocity_quiver'), 12, 8);
    end

end