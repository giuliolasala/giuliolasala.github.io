%% *****************************************************************************
% File: NS2dCompareRunToBenchmark.m
%   Development / debugging test for comparing a computed Navier-Stokes run
%   against a benchmark .mat file from the template package.
%
%   This script:
%     - loads one benchmark solution
%     - loads one computed run solution
%     - computes H1,H2 from u,v for both datasets
%     - compares u, v, p, H1, H2
%     - prints absolute and relative max-norm errors
%     - gives PASS / FAIL messages based on user-defined tolerances
%
%   Intended for debugging and implementation checks only.
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
this_file   = mfilename('fullpath');
test_dir    = fileparts(this_file);
root_dir    = fileparts(test_dir);
startup_dir = fullfile(root_dir,'startup');

addpath(startup_dir);
paths = setupPaths();

%% User input
% -------------------------------------------------------------------------
% Benchmark file from template package
benchmark_file = fullfile(paths.benchmark, ...
    'TestBenchmark_n7_Re3_Ulid-1_step2_dt1e-2.mat');

% Your run file to compare
run_file = fullfile(paths.results_solver, ...
    'solution_n7_Re3_Ulid-1_step2_dt1e-2', ...
    'solution_n7_Re3_Ulid-1_step2_dt1e-2.mat');

% Tolerances for PASS / FAIL
tol_u  = 1e-10;
tol_v  = 1e-10;
tol_P  = 1e-10;
tol_H1 = 1e-10;
tol_H2 = 1e-10;

displayArrays = true;   % set true to display benchmark and solver arrays
% -------------------------------------------------------------------------

%% Check files exist
if exist(benchmark_file,'file') ~= 2
    error('Benchmark file not found:\n%s', benchmark_file);
end

if exist(run_file,'file') ~= 2
    error('Run file not found:\n%s', run_file);
end

%% Load files
B = load(benchmark_file);
R = load(run_file);

%% Check benchmark required fields
required_fields_B = {'n','Re','u','v','P'};

for k = 1:numel(required_fields_B)
    if ~isfield(B, required_fields_B{k})
        error('Benchmark file missing field "%s".', required_fields_B{k});
    end
end

%% Check runData structure
if ~isfield(R, 'runData')
    error('Run file must contain a struct named "runData".');
end

if ~isfield(R.runData, 'input') || ~isfield(R.runData, 'fields')
    error('runData must contain fields "input" and "fields".');
end

%% Extract benchmark variables
n_b  = B.n;
Re_b = B.Re;
u_b  = B.u;
v_b  = B.v;
p_b  = B.P;

%% Extract run variables
n_r  = R.runData.input.n;
Re_r = R.runData.input.Re;
u_r  = R.runData.fields.u;
v_r  = R.runData.fields.v;
p_r  = R.runData.fields.P;

%% Basic consistency checks
if n_b ~= n_r
    error('Mismatch in n: benchmark has n=%d, run has n=%d.', n_b, n_r);
end

if abs(Re_b - Re_r) > 10*eps(max(1,max(abs([Re_b,Re_r]))))
    error('Mismatch in Re: benchmark has Re=%g, run has Re=%g.', Re_b, Re_r);
end

n  = n_b;
Re = Re_b;

%% Build mesh and compute H1,H2 for both datasets
[dx,~,~,~,~,~,~,~,~] = StaggeredMesh2dSquare(n);

[H1_b,H2_b] = NS2dHfunctions(n,dx,Re,u_b,v_b);
[H1_r,H2_r] = NS2dHfunctions(n,dx,Re,u_r,v_r);

%% Normalize pressure fields consistently
% Pressure in this problem is defined up to an additive constant, so compare
% normalized pressures to avoid false differences due only to pressure level.
p_b = p_b - mean(p_b(:));
p_r = p_r - mean(p_r(:));

%% Error fields
err_u  = u_r  - u_b;
err_v  = v_r  - v_b;
err_p  = p_r  - p_b;
err_H1 = H1_r - H1_b;
err_H2 = H2_r - H2_b;

%% Max absolute errors
err_u_max  = norm(err_u(:),  inf);
err_v_max  = norm(err_v(:),  inf);
err_p_max  = norm(err_p(:),  inf);
err_H1_max = norm(err_H1(:), inf);
err_H2_max = norm(err_H2(:), inf);

%% Max relative errors
rel_u_max  = err_u_max  / max(1, norm(u_b(:),  inf));
rel_v_max  = err_v_max  / max(1, norm(v_b(:),  inf));
rel_p_max  = err_p_max  / max(1, norm(p_b(:),  inf));
rel_H1_max = err_H1_max / max(1, norm(H1_b(:), inf));
rel_H2_max = err_H2_max / max(1, norm(H2_b(:), inf));

%% Pass / Fail
pass_u  = err_u_max  < tol_u;
pass_v  = err_v_max  < tol_v;
pass_p  = err_p_max  < tol_P;
pass_H1 = err_H1_max < tol_H1;
pass_H2 = err_H2_max < tol_H2;

pass_all = pass_u && pass_v && pass_p && pass_H1 && pass_H2;

%% Print summary
fprintf('\n');
fprintf('===============================================================================================\n');
fprintf('NS2d benchmark comparison test\n');
fprintf('-----------------------------------------------------------------------------------------------\n');
fprintf('n              = %d\n', n);
fprintf('Re             = %g\n', Re);
fprintf('dx             = %.6e\n', dx);
fprintf('-----------------------------------------------------------------------------------------------\n');

fprintf('u   : max abs err = %.6e | max rel err = %.6e | %s\n', ...
    err_u_max,  rel_u_max,  localPassFail(pass_u));
fprintf('v   : max abs err = %.6e | max rel err = %.6e | %s\n', ...
    err_v_max,  rel_v_max,  localPassFail(pass_v));
fprintf('p   : max abs err = %.6e | max rel err = %.6e | %s\n', ...
    err_p_max,  rel_p_max,  localPassFail(pass_p));
fprintf('H1  : max abs err = %.6e | max rel err = %.6e | %s\n', ...
    err_H1_max, rel_H1_max, localPassFail(pass_H1));
fprintf('H2  : max abs err = %.6e | max rel err = %.6e | %s\n', ...
    err_H2_max, rel_H2_max, localPassFail(pass_H2));

fprintf('-----------------------------------------------------------------------------------------------\n');
if pass_all
    fprintf('STATUS: PASS\n');
else
    fprintf('STATUS: FAIL\n');
end
fprintf('===============================================================================================\n');

%% Optional detailed display
if displayArrays
    disp(' ')
    disp('============================================== u ==============================================')
    disp('u benchmark:')
    disp(u_b)
    disp('u solver:')
    disp(u_r)

    disp(' ')
    disp('============================================== v ==============================================')
    disp('v benchmark:')
    disp(v_b)
    disp('v solver:')
    disp(v_r)

    disp(' ')
    disp('============================================== p ==============================================')
    disp('p benchmark (zero-mean):')
    disp(p_b)
    disp('p solver (zero-mean):')
    disp(p_r)

    disp(' ')
    disp('============================================= H1 ==============================================')
    disp('H1 benchmark:')
    disp(H1_b)
    disp('H1 solver:')
    disp(H1_r)

    disp(' ')
    disp('============================================= H2 ==============================================')
    disp('H2 benchmark:')
    disp(H2_b)
    disp('H2 solver:')
    disp(H2_r)
end

%% Local helper function
function txt = localPassFail(flag)
    if flag
        txt = 'PASS';
    else
        txt = 'FAIL';
    end
end