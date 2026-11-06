# Finite-volume solver for the 2D lid-driven cavity — MATLAB code

MATLAB implementation of a 2D incompressible Navier–Stokes solver on a uniform staggered grid
(finite volumes, central differencing, explicit Euler, pressure Poisson equation with reusable LU factorisation).
Project page: https://giuliolasala.github.io/projects/fv-navier-stokes-solver/

Developed for the course 41317 Computational Fluid Dynamics at the Technical University of Denmark (DTU), spring 2026.

## Structure

| Folder | Content |
|---|---|
| `startup/` | `setupPaths.m`: adds the folders to the MATLAB path and creates the output folders |
| `core/` | Discrete H-functions, Laplacian matrix and right-hand side of the pressure Poisson equation |
| `validation/` | Grid-refinement verification of the H-functions and of the Poisson solver against manufactured solutions |
| `solver/` | `NavierStokes2dMovingLidSquareCavityFlow.m`: the full time-dependent solver |
| `analysis/` | Re = 1 case with and without continuity correction, LU-reuse efficiency study, Re = 1000 grid-convergence study |
| `test/` | Short regression tests against a reference solution |
| `common_functions/` | Helper functions provided by the course (see below) |
| `data/benchmark/` | Small reference solution used by the tests, provided by the course |

## How to run

From the `code/` folder in MATLAB:

```matlab
addpath('startup'); paths = setupPaths();
NS2dValidateHfunction        % verification of the H-functions
NS2dValidatePoissonSolver    % verification of the pressure Poisson solver
NavierStokes2dMovingLidSquareCavityFlow   % short default run
NS2dRe1000ConvergenceAnalysis             % Re = 1000 study (long: up to 321 x 321 cells)
```

Results and figures are written to `data/results/` and `figures/`, which are created on the first run and are not part of the repository.

## Credits

The files in `common_functions/` (`StaggeredMesh2dSquare.m`, `WLSpolyfit.m`, `MYpolyval.m`, `PlotToFileColorPDF.m`)
and the reference solution in `data/benchmark/` were provided by Prof. Harry B. Bingham (DTU) for course 41317 and are included only so that the code runs.
All other files were written by Giulio La Sala.

The Re = 1000 benchmark values are taken from C.-H. Bruneau and M. Saad, "The 2D lid-driven cavity problem revisited", *Computers & Fluids*, 2006.
