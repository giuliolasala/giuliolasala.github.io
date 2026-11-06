%% *****************************************************************************
% File: NS2dTestHfunctionsBenchmark.m
%   Development test for NS2dHfunctions using the benchmark values
%   provided in the course template for n = 7 and Re = 3.
%
%   This script is intended for debugging and implementation checks only.
%
% Output:
%   - computed H1, H2
%   - benchmark H1, H2
%   - max absolute errors
%   - pass/fail message based on tolerance
%
%   Author      : Giulio La Sala
%   Date        : Sunday 17/05/2025
%   Version     : Final
%*******************************************************************************

%% Clear
clear
close all
clc

%% Setup project paths
this_file = mfilename('fullpath');
test_dir  = fileparts(this_file);
root_dir  = fileparts(test_dir);
startup_dir = fullfile(root_dir, 'startup');

addpath(startup_dir);
paths = setupPaths(); 

%% Benchmark case input
n  = 7;
Re = 3;

[dx,Xu,Yu,Xv,Yv,~,~,~,~] = StaggeredMesh2dSquare(n);

u = [zeros(1,n+1); Xu(2:n+1,:).*(1 - Xu(2:n+1,:)); ones(1,n+1)];
v = [zeros(n+1,1), Yv(:,2:n+1).*(1 - Yv(:,2:n+1)), zeros(n+1,1)];

%% Compute numerical H1, H2
[H1,H2] = NS2dHfunctions(n,dx,Re,u,v);

%% Benchmark values from template
H1_ref = [ ...
     0      -4.93200  -7.67440  -8.94360  -8.80950  -7.34210  -4.61130   0
     0      -0.89699  -0.94947  -0.87366  -0.73955  -0.61710  -0.57629   0
     0      -0.86200  -0.89116  -0.80369  -0.66958  -0.55879  -0.54130   0
     0      -0.82702  -0.83285  -0.73372  -0.59961  -0.50049  -0.50632   0
     0      -0.79203  -0.77454  -0.66375  -0.52964  -0.44218  -0.47133   0
     0      -0.75705  -0.71623  -0.59378  -0.45967  -0.38387  -0.43635   0
     0      27.94500  25.34200  24.14300  24.27700  25.67400  28.26500   0 ];

H2_ref = [ ...
     0         0         0         0         0         0         0
    -4.93200  -0.89699  -0.86200  -0.82702  -0.79203  -0.75705  -4.72210
    -7.67440  -0.94947  -0.89116  -0.83285  -0.77454  -0.71623  -7.32460
    -8.94360  -0.87366  -0.80369  -0.73372  -0.66375  -0.59378  -8.52380
    -8.80950  -0.73955  -0.66958  -0.59961  -0.52964  -0.45967  -8.38970
    -7.34210  -0.61710  -0.55879  -0.50049  -0.44218  -0.38387  -6.99220
    -4.61130  -0.57629  -0.54130  -0.50632  -0.47133  -0.43635  -4.40140
     0         0         0         0         0         0         0 ];

%% Error analysis
err_H1 = H1 - H1_ref;
err_H2 = H2 - H2_ref;

err_H1_max = norm(err_H1(:), inf);
err_H2_max = norm(err_H2(:), inf);

rel_H1_max = err_H1_max / max(1, norm(H1_ref(:), inf));
rel_H2_max = err_H2_max / max(1, norm(H2_ref(:), inf));

tol = 1e-3;

%% Print results
fprintf('\n');
fprintf('============================================================\n');
fprintf('NS2dHfunctions benchmark test\n');
fprintf('n  = %d\n', n);
fprintf('Re = %g\n', Re);
fprintf('------------------------------------------------------------\n');
fprintf('max abs error H1 = %.6e\n', err_H1_max);
fprintf('max abs error H2 = %.6e\n', err_H2_max);
fprintf('max rel error H1 = %.6e\n', rel_H1_max);
fprintf('max rel error H2 = %.6e\n', rel_H2_max);

if err_H1_max < tol && err_H2_max < tol
    fprintf('STATUS: PASS (tol = %.1e)\n', tol);
else
    fprintf('STATUS: FAIL (tol = %.1e)\n', tol);
end
fprintf('============================================================\n');

%% Optional detailed display
disp('Computed H1:')
disp(H1)

disp('Reference H1:')
disp(H1_ref)

disp('Computed H2:')
disp(H2)

disp('Reference H2:')
disp(H2_ref)