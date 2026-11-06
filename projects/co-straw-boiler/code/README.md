# CO formation and burnout in the Masnedø straw-fired boiler — MATLAB code

One-dimensional freeboard model combining particle entrainment, shrinking-particle char oxidation and Dryer–Glassman gas-phase CO oxidation.
Project page: https://giuliolasala.github.io/projects/co-straw-boiler/

Developed for DTU course 28244 Combustion and High Temperature Processes, autumn 2025.

## Files

| File | Content |
|---|---|
| `CE2_model.m` | Stoichiometric balance, residence time, entrainment limits, char burnout, gas-phase CO oxidation and sensitivity studies |
| `csv/` | Measured O2 and temperature along the freeboard (the `_clean` files are written by the script from the raw ones) |

## How to run

Open MATLAB in this folder and run `CE2_model`. Figures are saved in `img/`, created on the first run.

## Credits

The boiler data and measurements were provided with DTU course 28244. Code written by Giulio La Sala.
