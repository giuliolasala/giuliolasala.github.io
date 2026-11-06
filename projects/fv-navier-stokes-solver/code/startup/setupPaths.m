function paths = setupPaths()
%% ************************************************************************
% setupPaths
%   Configure project paths for CFD Report 2 MATLAB deliverables.
%   This function locates the project root from its own file location,
%   adds the relevant code folders to the MATLAB path, and returns a
%   structure containing the main directory paths used throughout
%   the project.
%
% Usage:
%   paths = setupPaths();
%
% Output:
%   paths : struct with fields
%       .root
%       .core
%       .validation
%       .solver
%       .analysis
%       .common_functions
%       .data
%       .benchmark
%       .results
%       .results_solver
%       .figures
%       .figures_solver
%       .figures_H_validation
%       .figures_Poisson_validation
%       .figures_Re1
%       .figures_Re1000
%       .figures_efficiency
%       .startup
%
%   Author      : Giulio La Sala
%   Date        : Sunday 17/05/2026
%   Version     : Final
% *************************************************************************

    %% Locate project root from this file location
    this_file   = mfilename('fullpath');
    startup_dir = fileparts(this_file);
    root_dir    = fileparts(startup_dir);

    %% Build path structure
    paths = struct();

    paths.root                       = root_dir;
    paths.core                       = fullfile(root_dir, 'core');
    paths.validation                 = fullfile(root_dir, 'validation');
    paths.test                       = fullfile(root_dir, 'test');
    paths.solver                     = fullfile(root_dir, 'solver');
    paths.analysis                   = fullfile(root_dir, 'analysis');
    paths.common_functions           = fullfile(root_dir, 'common_functions');

    paths.data                       = fullfile(root_dir, 'data');
    paths.benchmark                  = fullfile(paths.data, 'benchmark');
    paths.results                    = fullfile(paths.data, 'results');
    paths.results_solver             = fullfile(paths.results, 'solver');
    
    paths.results_Re1                 = fullfile(paths.results, 'Re1');
    paths.results_Re1_NoCC            = fullfile(paths.results_Re1, 'NoCC');
    paths.results_Re1_CC              = fullfile(paths.results_Re1, 'CC');
    paths.results_Re1_comparisons     = fullfile(paths.results_Re1, 'comparisons');

    paths.figures                    = fullfile(root_dir, 'figures');
    paths.figures_solver             = fullfile(paths.figures, 'solver');
    paths.figures_H_validation       = fullfile(paths.figures, 'H_validation');
    paths.figures_Poisson_validation = fullfile(paths.figures, 'Poisson_validation');
    paths.figures_Re1                = fullfile(paths.figures, 'Re1');
    paths.figures_Re1_NoCC            = fullfile(paths.figures_Re1, 'NoCC');
    paths.figures_Re1_CC              = fullfile(paths.figures_Re1, 'CC');
    paths.figures_Re1_comparisons     = fullfile(paths.figures_Re1, 'comparisons');
    paths.figures_Re1000             = fullfile(paths.figures, 'Re1000');
    paths.figures_efficiency         = fullfile(paths.figures, 'efficiency');

    paths.startup                    = startup_dir;

    %% Add code folders to MATLAB path
    folders_to_add = {
        paths.core
        paths.validation
        paths.test
        paths.solver
        paths.analysis
        paths.common_functions
        paths.startup
    };

    for i = 1:numel(folders_to_add)
        folder_i = folders_to_add{i};

        if exist(folder_i, 'dir') ~= 7
            error('setupPaths:MissingFolder', ...
                'Required folder not found:\n%s', folder_i);
        end

        if ~contains(path, [folder_i pathsep])
            addpath(folder_i);
        end
    end

    %% Create output folders if needed
    folders_to_create = {
        paths.data
        paths.benchmark
        paths.results
        paths.results_solver
        paths.results_Re1_NoCC
        paths.results_Re1_CC
        paths.results_Re1_comparisons
        paths.figures
        paths.figures_solver
        paths.figures_H_validation
        paths.figures_Poisson_validation
        paths.figures_Re1
        paths.results_Re1
        paths.figures_Re1_NoCC
        paths.figures_Re1_CC
        paths.figures_Re1_comparisons
        paths.figures_Re1000
        paths.figures_efficiency
    };

    for i = 1:numel(folders_to_create)
        folder_i = folders_to_create{i};
        if exist(folder_i, 'dir') ~= 7
            mkdir(folder_i);
        end
    end

end