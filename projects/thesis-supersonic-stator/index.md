---
layout: project
title: Shape optimisation of supersonic stator blades for two-phase turbines
summary: An automated CFD shape-optimisation framework, assisted by machine learning, for a supersonic stator blade working with two-phase cyclopentane.
card: Automated CFD, Gaussian-process surrogates and Bayesian optimisation cut the residual loss of a two-phase supersonic stator by 15.7%.
context: Master's thesis · DTU Construct, Section of Thermal Energy
date_label: June 2026
team: Individual thesis, supervised by Prof. Fredrik Haglind, Andrea Cioffi and Roberto Agromayor
tools: [ANSYS Fluent, ANSYS Workbench, Python, Gaussian process regression, Bayesian optimisation, B-splines]
featured: true
order: 1
cover: images/cover-mach.png
math: true
---

## Problem

Two-phase turbines can recover the expansion work that is otherwise dissipated in the throttling valves of power and refrigeration systems. Designing them is hard: the expansion of a mostly liquid mixture combines phase change, non-ideal thermodynamics, a low speed of sound, choking and shock waves.

The stator is the most critical component. It takes the main pressure drop, sets the mass flow rate and the flow delivered to the rotor, and is very sensitive to small changes in blade shape. The thesis asked whether that shape could be improved automatically, with a limited number of CFD runs, while keeping the mass flow and the outlet flow angle at their baseline values. It was carried out in the Sustainable Thermal Power research group at DTU, within the Training42Phase project.

<figure>
  <img src="images/workflow.png" alt="Diagram of the thesis workflow from the problem definition to the final validated design">
  <figcaption>Overview of the workflow, from the baseline geometry to the CFD-validated optimum.</figcaption>
</figure>

## Method

- **Baseline blade**: a supersonic nozzle profile from the method of characteristics, turned into a closed periodic blade and rebuilt with a cubic B-spline.
- **Fluid model**: a homogeneous-equilibrium barotropic model of cyclopentane, with the fluid properties prescribed as functions of pressure. It gives a robust closure for many repeated steady RANS simulations.
- **Automated CFD**: geometry generation, meshing and RANS simulations in ANSYS Workbench and Fluent, scripted with journal files and run without manual steps.
- **Design space**: the normal displacements of 13 B-spline control points, with bounds scaled on the throat width.
- **Initial data**: a hybrid Latin hypercube design of experiments with 104 geometries, 103 of which passed the CFD acceptance criteria.
- **Surrogates**: three independent Gaussian process regression models for the isentropic efficiency indicator, the outlet angle ratio and the mass flow ratio. Together they form a penalised objective that rewards efficiency and penalises deviations from the baseline outlet angle and mass flow.
- **Optimisation**: because each prediction comes with an uncertainty, the models drive a Bayesian optimisation loop with a logarithmic expected-improvement acquisition. Over 50 iterations the most informative geometries are run in CFD and added to the training data.

<figure>
  <img src="images/parametrization.png" alt="Blade contour with fixed and active B-spline control points numbered along the profile">
  <figcaption>B-spline parametrisation: only the active control points (green) move during the optimisation.</figcaption>
</figure>

## Results

The best optimised design raised the isentropic efficiency indicator from 0.9700 for the baseline to 0.9747, a 15.7% reduction of the residual loss factor $$\zeta = 1 - \eta_{is}$$. The penalised objective improved from 0.9422 for the best design of experiments sample to 0.9500. The mass flow ratio stayed within 0.02% of its target and the outlet angle deviation below 0.03%.

<figure>
  <img src="images/geometry-comparison.png" alt="Baseline, best DOE and best optimised blade contours overlapped">
  <figcaption>Baseline, best sampled design and optimised blade: the changes are local and concentrated on the suction side.</figcaption>
</figure>

The optimised blade keeps the global flow topology. The gain comes from localised changes of the suction side, and the density-gradient field shows weaker shock reflections downstream of the trailing edge.

<figure>
  <img src="images/density-gradient-comparison.png" alt="Density-gradient fields around the blades for the baseline and the optimised design">
  <figcaption>Density gradient, a numerical schlieren image, for the baseline and the optimised blade.</figcaption>
</figure>

The surrogates also learned during the optimisation: the cross-validated R² of the efficiency and outlet-angle models rose from 0.66 and 0.76 to 0.92 and 0.91.

<figure>
  <img src="images/bo-convergence.png" alt="Best CFD objective found so far against Bayesian optimisation iteration, above the baseline and initial sampling lines">
  <figcaption>Best CFD-validated objective over the 50 Bayesian optimisation iterations, compared with the baseline and the best design of experiments sample.</figcaption>
</figure>

<figure>
  <img src="images/eta-parity.png" alt="Parity plot of efficiency predicted by the Gaussian process against CFD values, mostly within half a percent">
  <figcaption>Efficiency predicted by the Gaussian process model against CFD, with ±0.5% and ±1% bands.</figcaption>
</figure>

## My contribution

The baseline nozzle contour from the method of characteristics and the barotropic thermodynamic model were the starting point of the project. I developed the whole simulation and optimisation framework on top of them: the throat-scaled B-spline parametrisation of the blade, the automated ANSYS Workbench and Fluent pipeline for geometry, meshing and RANS simulations, the Gaussian process surrogates, and the sequential Bayesian optimisation loop with adaptive retraining.

## Limitations and next steps

The result is a CFD-validated local improvement under the chosen parametrisation and barotropic assumptions, not a global optimum. Natural extensions are other exit Mach numbers, trailing-edge thicknesses and working fluids, a larger design space with a minimum-thickness constraint, and constrained Bayesian optimisation.

<p class="note">The code and data of the thesis belong to the research project and are not published here.</p>
