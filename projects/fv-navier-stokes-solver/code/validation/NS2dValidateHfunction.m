%% ************************************************************************
% File: NS2dValidateHfunction.m
%   Validation script for the implemented function NS2dHfunctions, used to
%   compute the H1- and H2-terms in the 2D incompressible Navier-Stokes
%   equations in nondimensional form.
%   Finite Volume Method on a staggered Cartesian mesh with uniform square
%   cells. Central Difference Scheme (CDS) applied to both convective and
%   diffusive fluxes.
%
%   H1- and H2-expressions:
%        H1 = 1/dx*(1/Re*dudx - u*u)|_w^e + 1/dx*(1/Re*dudy - u*v)|_s^n
%        H2 = 1/dx*(1/Re*dvdx - u*v)|_w^e + 1/dx*(1/Re*dvdy - v*v)|_s^n
%
%   Test functions for u,v:
%        u  = sin(k1*Xu).*sin(k2*Yu);
%        v  = sin(k3*Xv).*sin(k4*Yv);
%
%   These yield exact analytical expressions for H1 and H2, evaluated at the
%   velocity control-volume centers. The numerical and exact values are
%   compared through a grid refinement study to verify the expected
%   second-order convergence of the CDS discretization.
%
% Input   :
%   Nvec  :  Vector with number of cells in x,y,
%            e.g. Nvec = [11 21 41 81 161 321 641];
%   Re    :  Global Reynolds number
%   K     :  Vector of wave numbers for velocity test functions
%
% Output  :
%   - Convergence plots (log-log error vs grid size)
%   - Field comparison plots (numerical vs exact H1, H2)
%   - Absolute error maps for H1 and H2
%   - Estimated convergence rates printed to console
%
%   Author      : Giulio La Sala
%   Date        : Sunday 17/05/2025
%   Version     : Final
%**************************************************************************

%% Clear workspace
clear
close all
clc

%% Setup project paths
% Add startup folder to path and initialize project directories
this_file   = mfilename('fullpath');
current_dir = fileparts(this_file);
project_dir = fileparts(current_dir);
startup_dir = fullfile(project_dir,'startup');

addpath(startup_dir);
paths = setupPaths();

fig_dir = paths.figures_H_validation;

%% Input parameters
Nvec = [11 21 41 81 161 321 641];
Re   = 3;
K    = pi*(1:4);   % K = [k1 k2 k3 k4]

k1 = K(1);
k2 = K(2);
k3 = K(3);
k4 = K(4);

%% Test functions for velocity field
U = @(x,y,k1,k2) sin(k1*x).*sin(k2*y);
V = @(x,y,k3,k4) sin(k3*x).*sin(k4*y);

%% Exact continuous expressions for H1 and H2
% Continuous identities:
%   H1 = (1/Re)*(uxx + uyy) - d(u^2)/dx - d(uv)/dy
%   H2 = (1/Re)*(vxx + vyy) - d(uv)/dx - d(v^2)/dy

H1e = @(x,y,k1,k2,k3,k4,Re) ...
    -(k1^2 + k2^2)/Re .* sin(k1*x).*sin(k2*y) ...
    - 2*k1 .* sin(k1*x).*cos(k1*x).*sin(k2*y).^2 ...
    - k2 .* sin(k1*x).*cos(k2*y).*sin(k3*x).*sin(k4*y) ...
    - k4 .* sin(k1*x).*sin(k2*y).*sin(k3*x).*cos(k4*y);

H2e = @(x,y,k1,k2,k3,k4,Re) ...
    -(k3^2 + k4^2)/Re .* sin(k3*x).*sin(k4*y) ...
    - k1 .* cos(k1*x).*sin(k2*y).*sin(k3*x).*sin(k4*y) ...
    - k3 .* sin(k1*x).*sin(k2*y).*cos(k3*x).*sin(k4*y) ...
    - 2*k4 .* sin(k3*x).^2 .* sin(k4*y).*cos(k4*y);

%% Initialize storage arrays
n_cases = numel(Nvec);

DX    = zeros(1,n_cases);   % grid spacing
ERROR = zeros(2,n_cases);   % infinity-norm errors for H1 and H2
ROC   = zeros(2,1);         % estimated convergence rates
TL    = zeros(2,n_cases);   % trend lines from log-log fit

%% Choose one representative grid for field plots
n_plot = 81;

h1_plot   = [];
h2_plot   = [];
h1e_plot  = [];
h2e_plot  = [];
err1_plot = [];
err2_plot = [];

Xu_plot = [];
Yu_plot = [];
Xv_plot = [];
Yv_plot = [];

%% Grid refinement study
for m = 1:n_cases

    n = Nvec(m);

    % Build staggered grid
    [dx,Xu,Yu,Xv,Yv,~,~,~,~] = StaggeredMesh2dSquare(n);
    DX(m) = dx;

    % Evaluate analytical velocity test functions on staggered grids
    u = U(Xu,Yu,k1,k2);
    v = V(Xv,Yv,k3,k4);

    % Compute numerical H1 and H2
    [h1,h2] = NS2dHfunctions(n,dx,Re,u,v);

    % Evaluate exact H1 and H2 at the corresponding velocity CV centers
    h1e = H1e(Xu(2:n+1,:),Yu(2:n+1,:),k1,k2,k3,k4,Re);
    h2e = H2e(Xv(:,2:n+1),Yv(:,2:n+1),k1,k2,k3,k4,Re);

    % Compare only entries that are explicitly computed by NS2dHfunctions
    % H1 is computed for j = 2:n
    % H2 is computed for i = 2:n
    err1 = h1(:,2:n) - h1e(:,2:n);
    err2 = h2(2:n,:) - h2e(2:n,:);

    % Store infinity-norm errors
    ERROR(1,m) = norm(err1(:),inf);
    ERROR(2,m) = norm(err2(:),inf);

    % Store one representative solution for visualization
    if n == n_plot
        h1_plot   = h1(:,2:n);
        h2_plot   = h2(2:n,:);
        h1e_plot  = h1e(:,2:n);
        h2e_plot  = h2e(2:n,:);
        err1_plot = abs(err1);
        err2_plot = abs(err2);

        Xu_plot = Xu(2:n+1,2:n);
        Yu_plot = Yu(2:n+1,2:n);

        Xv_plot = Xv(2:n,2:n+1);
        Yv_plot = Yv(2:n,2:n+1);
    end
end

%% Estimate convergence rates from the finest grids
n_fit = min(4,n_cases);

for q = 1:2
    p = polyfit(log(DX(end-n_fit+1:end)), ...
                log(ERROR(q,end-n_fit+1:end)),1);
    ROC(q)  = p(1);
    TL(q,:) = exp(polyval(p,log(DX)));
end

%% Print summary to command window
fprintf('\n');
fprintf('===============================================================\n');
fprintf('NS2dValidateHfunction\n');
fprintf('---------------------------------------------------------------\n');
fprintf('Estimated convergence rate for H1: %.6f\n', ROC(1));
fprintf('Estimated convergence rate for H2: %.6f\n', ROC(2));
fprintf('Fit based on last %d grids\n', n_fit);
fprintf('===============================================================\n');

fprintf('\n');
fprintf('===============================================================\n');
fprintf('   n           dx             err_H1           err_H2\n');
fprintf('---------------------------------------------------------------\n');
for m = 1:n_cases
    fprintf('%4d   %12.4e   %12.4e   %12.4e\n', ...
        Nvec(m), DX(m), ERROR(1,m), ERROR(2,m));
end
fprintf('===============================================================\n');

%% Plot 1: convergence history
figure(201)
clf

loglog(DX,ERROR(1,:),'bo-','LineWidth',1.5,'MarkerSize',8);
hold on
loglog(DX,ERROR(2,:),'rs-','LineWidth',1.5,'MarkerSize',8);
loglog(DX,TL(1,:),'--','LineWidth',1.2);
loglog(DX,TL(2,:),'--','LineWidth',1.2, 'Color', [0.1333 0.5451 0.1333]);

ax = gca;
grid on
ax.GridAlpha = 0.10;
ax.MinorGridAlpha = 0.08;
ax.GridLineStyle = '-';
ax.MinorGridLineStyle = ':';

xlabel('\Deltax', 'Interpreter','tex')
ylabel('Max error')
title('Convergence of H_1 and H_2')
legend( ...
    sprintf('H_1 error, rate = %.3f',ROC(1)), ...
    sprintf('H_2 error, rate = %.3f',ROC(2)), ...
    'Location','southEast');

PlotToFileColorPDF(gcf,fullfile(fig_dir,'H_convergence'),12,8);

%% Plot 2: numerical and exact fields
if ~isempty(h1_plot)

    figure(202)
    clf

    subplot(2,2,1)
    surf(Xu_plot,Yu_plot,h1_plot)
    shading interp
    view(2)
    colorbar
    axis equal tight
    xlabel('x')
    ylabel('y')
    title(sprintf('Numerical H_1, n = %d',n_plot))

    subplot(2,2,2)
    surf(Xu_plot,Yu_plot,h1e_plot)
    shading interp
    view(2)
    colorbar
    axis equal tight
    xlabel('x')
    ylabel('y')
    title(sprintf('Exact H_1, n = %d',n_plot))

    subplot(2,2,3)
    surf(Xv_plot,Yv_plot,h2_plot)
    shading interp
    view(2)
    colorbar
    axis equal tight
    xlabel('x')
    ylabel('y')
    title(sprintf('Numerical H_2, n = %d',n_plot))

    subplot(2,2,4)
    surf(Xv_plot,Yv_plot,h2e_plot)
    shading interp
    view(2)
    colorbar
    axis equal tight
    xlabel('x')
    ylabel('y')
    title(sprintf('Exact H_2, n = %d',n_plot))

    PlotToFileColorPDF(gcf, ...
        fullfile(fig_dir,'H_fields_comparison'), 18, 12);
end

%% Plot 3: absolute error maps
if ~isempty(err1_plot)

    figure(203)
    clf

    subplot(1,2,1)
    surf(Xu_plot,Yu_plot,err1_plot)
    shading interp
    view(2)
    colorbar
    axis equal tight
    xlabel('x')
    ylabel('y')
    title(sprintf('|H_1 - H_{1,e}|, n = %d',n_plot))

    subplot(1,2,2)
    surf(Xv_plot,Yv_plot,err2_plot)
    shading interp
    view(2)
    colorbar
    axis equal tight
    xlabel('x')
    ylabel('y')
    title(sprintf('|H_2 - H_{2,e}|, n = %d',n_plot))
    PlotToFileColorPDF(gcf, ...
        fullfile(fig_dir,'H_error_maps'), 16, 12);
end

