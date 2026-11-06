# SNCR model for the SYSAV waste incinerator — MATLAB code

Kinetic plug-flow model of selective non-catalytic reduction (SNCR) with ammonia, used to choose the injection port and to design a temperature-dependent NH3/NO dosing law.
Project page: https://giuliolasala.github.io/projects/sncr-waste-incinerator/

Developed for DTU course 28244 Combustion and High Temperature Processes, autumn 2025.

## Files

| File | Content |
|---|---|
| `CE1_model.m` | Full study: flue-gas balance, residence-time study for four injection ports, parametric study on beta, temperature-binned analysis and optimisation of the piecewise beta(T) law |
| `model_validation.m` | Outlet NO against temperature for three NH3/NO ratios, compared with the reduction window of plug-flow reactor experiments |
| `testing_temperature.xlsx` | Measured furnace temperature time series used for the binned analysis |

## How to run

Open MATLAB in this folder and run `model_validation` or `CE1_model`. Figures are saved in `img/`, created on the first run.

## Credits

Two-step kinetic mechanism: Brouwer, Heap, Pershing and Smith (1996). The plant data and the temperature measurements were provided with DTU course 28244. Code written by Giulio La Sala.
