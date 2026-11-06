%% *****************************************************************************
% File: NS2dValidatePoissonSolver.m
%   Validation script for the discrete pressure Poisson solver used in the
%   2D incompressible Navier-Stokes solver on a staggered Cartesian grid.
%
%   The script validates:
%     1) the assembly of the discrete Laplacian matrix with homogeneous
%        Neumann boundary conditions on all walls,
%     2) the assembly of the discrete right-hand side from the H1 and H2
%        source terms,
%     3) the accuracy of the computed pressure field under grid refinement.
%
%   The continuous validation problem is:
%
%       ∇²P = ∂H1/∂x + ∂H2/∂y
%
%   using the analytical functions
%
%       P  = cos(k*Xp).*cos(k*Yp)
%       H1 = -k*sin(k*Xu).*cos(k*Yu)
%       H2 = -k*cos(k*Xv).*sin(k*Yv)
%
%   defined on the staggered mesh at the appropriate control-volume centers.
%
%   Since the pressure Poisson problem with pure Neumann boundary conditions
%   is singular, the discrete solution is determined only up to an arbitrary
%   constant. The numerical pressure is normalized to have zero mean value 
%   before comparison with the exact solution. The exact pressure 
%   is also shifted to zero mean for consistency.
%
% Input   :
%   Nvec  : vector with number of cells in x,y,
%             e.g. Nvec = [11 21 41 81 161 321];
%   K     : wave number for H1, H2, and exact pressure
%
% Output  :
%   - convergence plot for pressure error
%   - field comparison plots for exact pressure, numerical pressure, and error
%   - plots of the H1 and H2 test fields
%
%   Author      : Giulio La Sala
%   Date        : Sunday 17/05/2025
%   Version     : Final
% =========================================================================

%% Clear workspace
clear
close all
clc

%% Setup project paths
this_file   = mfilename('fullpath');
current_dir = fileparts(this_file);
project_dir = fileparts(current_dir);
startup_dir = fullfile(project_dir,'startup');

addpath(startup_dir);
paths = setupPaths();

%% Input
Nvec = [11 21 41 81 161 321];         % number of cells in x,y
K    = 2*pi;                          % wave number for test functions

%% Function handles for H1, H2, and exact pressure
H1 = @(x,y,k) -k*sin(k*x).*cos(k*y);  % H1 test function
H2 = @(x,y,k) -k*cos(k*x).*sin(k*y);  % H2 test function
Pe = @(x,y,k)  cos(k*x).*cos(k*y);    % exact pressure field

%% Initialize arrays
n_cases   = length(Nvec);
DX        = zeros(1,n_cases);         % grid spacing
ERROR     = zeros(1,n_cases);         % pressure error in infinity norm
SUM_RHS   = zeros(1,n_cases);         % compatibility check for Neumann problem
SYM_ERR   = zeros(1,n_cases);         % symmetry defect of A
RANK_A    = NaN(1,n_cases);           % rank(A), only for smaller systems
MEAN_NUM  = zeros(1,n_cases);         % mean pressure after normalization
RES_INF   = zeros(1,n_cases);         % residual norm of modified linear system

%% Console header
fprintf('\n');
fprintf('==========================================================================================\n');
fprintf('NS2dValidatePoissonSolver\n');
fprintf('==========================================================================================\n');

%% Loop over grid resolutions
for i_case = 1:n_cases

    n = Nvec(i_case);

    fprintf('------------------------------------------------------------------------------------------\n');
    fprintf('Case %i / %i   ÷   n = %i\n', i_case, n_cases, n);
    fprintf('------------------------------------------------------------------------------------------\n');

    %% Mesh arrays
    [dx,Xu,Yu,Xv,Yv,Xp,Yp,~,~] = StaggeredMesh2dSquare(n);
    DX(i_case) = dx;

    % Test fields on staggered grid
        % H1 : size (n, n+1), located at u-grid CV centers
        % H2 : size (n+1, n), located at v-grid CV centers
        % Pe : size (n, n),   located at p-grid CV centers
    h1 = H1(Xu(2:n+1,:), Yu(2:n+1,:), K);
    h2 = H2(Xv(:,2:n+1), Yv(:,2:n+1), K);
    pe = Pe(Xp, Yp, K);

    % Normalize exact pressure to zero mean for consistent comparison
    pe = pe - mean(pe(:));

    %% Build matrix and right-hand side
    A = NS2dLaplaceMatrix(n);
    s = NS2dBuildPoissonRHS(n,dx,h1,h2);

   %% Diagnostics on matrix and right-hand side
    SYM_ERR(i_case) = full(norm(A - A.', inf));
    SUM_RHS(i_case) = sum(s(:));

    fprintf('dx                          = %.6e\n', dx);
    fprintf('symmetry defect             = %.6e\n', SYM_ERR(i_case));

    if n <= 41
        RANK_A(i_case) = rank(full(A));
        fprintf('rank(A)                     = %i   (expected %i)\n', ...
            RANK_A(i_case), n^2 - 1);
    else
        fprintf('rank(A)                     = skipped for large n (expected %i)\n', ...
            n^2 - 1);
    end

    fprintf('sum(s(:))                   = %.6e\n', SUM_RHS(i_case));

    %% Solve singular Neumann problem
    % Replace one equation to obtain a nonsingular linear system, then
    % normalize the resulting pressure field to zero mean.
    Afix = A;
    bfix = s(:);

    k_ref = 1;                  % reference equation index
    Afix(k_ref,:)   = 0.0;
    Afix(k_ref,k_ref) = 1.0;
    bfix(k_ref)     = 0.0;

    p = reshape(Afix \ bfix, n, n);

    % Residual of the modified system
    RES_INF(i_case) = norm(Afix * p(:) - bfix, inf);

    % Normalize numerical pressure to zero mean
    p = p - mean(p(:));
    MEAN_NUM(i_case) = mean(p(:));

    fprintf('modified-system residual    = %.6e\n', RES_INF(i_case));
    fprintf('mean(p) after normalization = %.6e\n', MEAN_NUM(i_case));

    %% Compute pressure error
    err           = p - pe;
    ERROR(i_case) = norm(err(:), inf);

    fprintf('||p - pe||_inf              = %.6e\n\n', ERROR(i_case));

    %% Store one representative case for post-processing plots
    if i_case == min(4,n_cases)
        n_plot   = n;
        Xp_plot  = Xp;
        Yp_plot  = Yp;
        Xu_plot  = Xu(2:n+1,:);
        Yu_plot  = Yu(2:n+1,:);
        Xv_plot  = Xv(:,2:n+1);
        Yv_plot  = Yv(:,2:n+1);
        h1_plot  = h1;
        h2_plot  = h2;
        p_plot   = p;
        pe_plot  = pe;
        err_plot = err;
    end
end

%% Estimate asymptotic convergence rate
n_fit = min(4,n_cases);
idx   = n_cases-n_fit+1:n_cases;

Pfit = polyfit(log(DX(idx)), log(ERROR(idx)), 1);
ROC  = Pfit(1);
TL   = exp(polyval(Pfit, log(DX)));

%% Final console summary
fprintf('==========================================================================================\n');
fprintf('Summary\n');
fprintf('==========================================================================================\n');
fprintf('%6s %14s %18s %14s %14s %14s', ...
    'n', 'dx', 'err_inf', 'rank(A)', 'sym_err', 'sum_rhs');
fprintf('\n------------------------------------------------------------------------------------------\n');
for i_case = 1:n_cases
    if isnan(RANK_A(i_case))
        fprintf('%6i %14.6e %18.6e %14s %14.3e %14.3e\n', ...
            Nvec(i_case), DX(i_case), ERROR(i_case), 'skipped', ...
            SYM_ERR(i_case), SUM_RHS(i_case));
    else
        fprintf('%6i %14.6e %18.6e %14i %14.3e %14.3e\n', ...
            Nvec(i_case), DX(i_case), ERROR(i_case), RANK_A(i_case), ...
            SYM_ERR(i_case), SUM_RHS(i_case));
    end
end
fprintf('------------------------------------------------------------------------------------------\n');
fprintf('\nEstimated asymptotic convergence rate = %.6f\n', ROC);
fprintf('==========================================================================================\n\n');

%% Plot 1: convergence of pressure error
figure(301)
clf
loglog(DX, ERROR, 'bo-', 'LineWidth', 1.5, 'MarkerSize', 7)
hold on
loglog(DX, TL, 'r--', 'LineWidth', 1.2)
xlabel('\Deltax', 'Interpreter','tex')
ylabel('||p - p_e||_\infty', 'Interpreter','tex')

ax = gca;
grid on
ax.GridAlpha = 0.10;
ax.MinorGridAlpha = 0.08;
ax.GridLineStyle = '-';
ax.MinorGridLineStyle = ':';

title('Pressure Poisson Solver Validation')
legend('Numerical error', sprintf('Fit slope = %.3f', ROC), ...
    'Location', 'northwest')

PlotToFileColorPDF(gcf, ...
    fullfile(paths.figures_Poisson_validation, ...
    'Poisson_pressure_convergence'), 12, 8);

%% Plot 2: exact pressure, numerical pressure, and error
figure(302)
clf

subplot(2,2,1)
surf(Xp_plot, Yp_plot, pe_plot)
shading interp
view(2)
axis equal tight
colorbar
xlabel('x')
ylabel('y')
title(sprintf('Exact pressure, n = %i', n_plot))

subplot(2,2,2)
surf(Xp_plot, Yp_plot, p_plot)
shading interp
view(2)
axis equal tight
colorbar
xlabel('x')
ylabel('y')
title(sprintf('Numerical pressure, n = %i', n_plot))

subplot(2,2,3)
surf(Xp_plot, Yp_plot, abs(err_plot))
shading interp
view(2)
axis equal tight
colorbar
xlabel('x')
ylabel('y')
title('|p - p_e|')

subplot(2,2,4)
contourf(Xp_plot, Yp_plot, err_plot, 20, 'LineColor', 'none')
axis equal tight
colorbar
xlabel('x')
ylabel('y')
title('Pressure error contours')

PlotToFileColorPDF(gcf, ...
    fullfile(paths.figures_Poisson_validation, ...
    'Poisson_pressure_fields'), 18, 12);

%% Plot 3: H1 and H2 test fields
figure(303)
clf

subplot(1,2,1)
surf(Xu_plot, Yu_plot, h1_plot)
shading interp
view(2)
axis equal tight
colorbar
xlabel('x')
ylabel('y')
title(sprintf('H1 test field, n = %i', n_plot))

subplot(1,2,2)
surf(Xv_plot, Yv_plot, h2_plot)
shading interp
view(2)
axis equal tight
colorbar
xlabel('x')
ylabel('y')
title(sprintf('H2 test field, n = %i', n_plot))

PlotToFileColorPDF(gcf, ...
    fullfile(paths.figures_Poisson_validation, ...
    'Poisson_H1_H2_test_fields'), 16, 12);