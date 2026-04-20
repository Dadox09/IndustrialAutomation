# Industrial Automation - Assignment 1 (Group 20)

This directory contains the work for Assignment 1 of the Industrial Automation course. The project focuses on the mathematical modeling, simulation, and control of a thermal system representing an industrial storage chamber containing a mass of product.

## Project Overview

The main objective of this assignment is to model and simulate the thermodynamic operations of a storage chamber over a 24-hour horizon. The system simulates the dynamic behavior of:
- **Air Temperature** inside the chamber ($T_a$)
- **Product Temperature** ($T_p$)
- **Battery Energy Storage System** state of charge ($S_b$)

The model incorporates multiple physical parameters and environmental disturbances, such as external ambient temperature, dynamic thermal loads, and solar radiation, combined with available Photovoltaic (PV) power.

## Directory Contents

*   **`Assignment1-Report-Group20.pdf`**: The main report detailing the theoretical background, methodology, equations, design choices, and quantitative result analysis.
*   **`init.m`**: MATLAB script to initialize all thermal, electrical, disturbance, and simulation parameters required by the system.
*   **`task1.slx` to `task4.slx`**: Nonlinear Simulink models of the system implemented with various numerical characteristics and solvers.
*   **`task5_6.m`**: MATLAB script for identifying the Equilibrium Point, calculating the symbolic Jacobians to construct the state-space linearized system, and discretizing the resulting matrices.
*   **`task6.slx`**: Simulink model built for simulating the linearized and discretized system.
*   **`run_task7.m`**: A comprehensive batch-simulation script that compares the performance of the non-linear and linear models across multiple sampling times ($T_s$). It generates comparative plots for temperature tracking (RMSE), grid energy usage, PV energy utilization, and battery state of charge.

## How to Run

1. Open MATLAB and navigate to this folder.
2. If you want to load the base parameters to test individual Simulink models, run the initialization script:
   ```matlab
   init
   ```
3. To compute the equilibrium point, linearize the non-linear system, and discretize it, run:
   ```matlab
   task5_6
   ```
4. To run the full comparison batch simulation (which will automatically initialize variables, run multiple models varying $T_s$, and generate summary plots), execute:
   ```matlab
   run_task7
   ```
   *Note: This script will output several `.png` charts in the current directory, detailing the results of the performance comparison.*

## Dependencies

- **MATLAB** and **Simulink** installations.
- Symbolic Math Toolbox (for `task5_6.m` automatic jacobian computation).
- Control System Toolbox (for continuous-to-discrete conversion algorithms).
