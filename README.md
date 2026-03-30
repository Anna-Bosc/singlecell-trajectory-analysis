# singlecell-trajectory-analysis
MATLAB pipeline for the analysis of single-cell trajectories in Chlamydomonas reinhardtii. The workflow includes preprocessing of tracking data, kinematic classification of trajectories into behavioral subpopulations, and quantitative analysis using mean square displacement (MSD) and related metrics.


## Overview

The workflow is divided into three main stages:

1. **Data matrix generation**
   - Conversion of TrackMate output into a structured dataset
   - Unit calibration (pixel to micron, frame to second)

2. **Kinematic analysis**
   - Classification of trajectories into behavioral subpopulations
   - kinematic analysis of global and subpopulation

3. **MSD analysis**
   - Computation and analysis of mean square displacement (MSD) of global and subpopulation

## Requirements

- MATLAB
- TrackMate output files (ImageJ/FIJI tracking export)
- TrackMate helper functions (01_data_matrix\trackmate_required_functions)

## Usage

### 1. Data matrix generation

Run the live script: 
  01_data_matrix/Tracking_codeAUTO_conversionUDM.mlx


This script:
- imports TrackMate tracking data
- uses auxiliary TrackMate functions (included in `trackmate_required_functions`)
- applies unit conversion via `converte_units.m`
- generates the dataset used in subsequent analyses

### 2. Kinematic analysis

Run scripts in the folder:
  02_kinematic_analysis/


### 3. MSD analysis

Run scripts in:
  03_msd_analysis/


## Notes

- The TrackMate helper functions included in this repository are not original contributions and are distributed for compatibility purposes.
- The pipeline is modular and can be adapted to different datasets.

## License

MIT License
