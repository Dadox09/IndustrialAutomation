# Assignment 2 — Sustainable Offshore Wind Installation
**Industrial Automation** · Group 20 · Davide Rizzo & Marta Nasso · April 2026

---

## Problem

Schedule a Heavy-Lift Vessel (HLV) to install 4 offshore wind structures (Monopile, Jacket, Nacelle) minimising total fuel consumption. The objective balances two competing costs:

- **Setup fuel** — transit cost between consecutive structure types (sequence-dependent)
- **Tardiness penalty** — weighted delay past each task's Weather Window deadline, plus a fixed 100-unit remobilisation fee per late task

## Repository Structure

```
.
├── scripts/
│   ├── main.m               # entry point — runs all phases in order
│   ├── setup_database.m     # creates offshore_wind.db (SQLite)
│   ├── solve_milp.m         # Approach A: MILP (exact)
│   ├── solve_dp.m           # Approach B: Dynamic Programming (exact)
│   ├── nearest_neighbor.m   # greedy heuristic baseline
│   ├── sustainability_report.m  # comparative analysis + bar chart
│   └── offshore_wind.db     # SQLite database (auto-generated)
├── results/
│   ├── milpGantt.png        # Gantt chart — MILP optimal schedule
│   ├── dpGantt.png          # Gantt chart — DP optimal schedule
│   ├── graphDP.jpeg         # DP staged graph (state-space lattice)
│   └── sustainability_plot.png  # stacked bar: setup vs. penalty comparison
├── report.tex               # full LaTeX report
└── part2_20.pdf             # assignment specification
```

## Requirements

- **MATLAB** R2021a or later
- **Optimization Toolbox** (for `optimproblem` / `solve` in MILP)
- **Database Toolbox** (for `sqlite` connector)
- No external Python or server dependencies — SQLite runs embedded

## How to Run

```matlab
cd scripts
main
```

`main.m` executes all four phases sequentially:
1. Creates/resets the SQLite database
2. Solves the MILP (global optimum)
3. Solves via Dynamic Programming (global optimum)
4. Runs the Nearest-Neighbour heuristic and generates the sustainability report

All output figures are saved to `results/`.

## Results Summary

| Method | Sequence | Total Fuel Cost |
|--------|----------|----------------|
| MILP (exact) | T3 → T1 → T4 → T2 | **1,677** |
| DP (exact)   | T3 → T1 → T4 → T2 | **1,677** |
| Nearest Neighbour (heuristic) | T1 → T4 → T3 → T2 | 2,006 |

Both exact methods converge to the same optimal sequence. The greedy heuristic is **16.4% worse** (329 extra fuel units), despite having lower setup costs — its greedy transitions defer the Nacelle task past its weather window, generating a larger tardiness penalty.

## Report

`report.tex` is the full academic report. Compile locally:

```bash
pdflatex report.tex
pdflatex report.tex   # run twice for cross-references
```

Or import the repository directly into [Overleaf](https://overleaf.com) — GitHub sync is supported under *New Project → Import from GitHub*.

Required LaTeX packages (all standard in TeX Live / MiKTeX):
`amsmath`, `graphicx`, `booktabs`, `float`, `placeins`, `listings`, `xcolor`, `array`, `caption`

## Authors

- Davide Rizzo
- Marta Nasso
