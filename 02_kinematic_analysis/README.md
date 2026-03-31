# Kinematic analysis and clustering

This folder contains the MATLAB tools used to analyze the motility of single-cell trajectories and to identify kinematic subpopulations.

## Overview
The analysis is based on the `converted_data.mat` file generated in the previous step (`01_data_matrix`).
The workflow consists of two main stages:

1. **Kinematic analysis and classification**
2. **Extraction of subpopulations (clusters)**
3. **Kinematic analysis of clusters (optional)**

---
## Files

- `CollectiveMotionAnalyzer_udm_lightOnOff.m` → main analysis class  
- `CollectiveMotionAnalyzer_udm_lightOnOff_runner.m` → main script (entry point)  
- `Collective_splitting_runner.m` → script for extracting cluster-specific datasets  

---
## Input data

The script requires as input:

- `converted_data.mat`  
  (output of the preprocessing step in `01_data_matrix`)
⚠️ The user must specify the correct path to the data.
---

## Folder structure
The script operates on a single dataset at a time.
⚠️ The user must manually define:
- the path to `main_folder`
- the name of the `.mat` file ( like converted_data.mat)
main_folder/
│
└── converted_data.mat
---

## Usage
This script:

- loads `converted_data`
- computes kinematic parameters (speed, displacement, straightness)
- classifies trajectories into:
  - stationary (ferma)
  - circling/tortuous (tondo)
  - directional (direzionale)
- analyzes temporal evolution of motility
- performs clustering of directional trajectories
- generates plots and summary statistics
- saves results in `.mat` and `.xlsx` format

### Step 1 — Run kinematic analysis

### Parameters needs to be set

The main parameters (modifiable in the runner script) are:
1) mainfolder
2) name of the file like `converted_data`
3) results folder, like 'Collective_global'
- `minDisplacement` → threshold for distinguishing motile vs stationary cells (µm)  
- `minStraightness` → threshold for directional motion
- `hasLight` → set:
  - `true` if light stimulus is present  
  - `false` otherwise
- `lightDirection` → direction of illumination (vector) 
---
## Run:
CollectiveMotionAnalyzer_udm_lightOnOff_runner.m
## Output
Results are saved in a folder: Collective_global/
Outputs include:
- `risultati_video.mat` → summary tables  
- `risultati_media.xlsx` → global statistics  
- `risultati_cluster.xlsx` → cluster-specific statistics  
- `tracce_stats.xlsx` → per-track statistics  
- `risultati_temporali_*.xlsx` → temporal evolution data  

- plots are generated and optionally saved (`.fig`, `.png`)
## Notes
- The analysis is designed for population-level characterization of motility  
- Clustering is applied only to directional trajectories  
- Threshold selection (displacement and straightness) should be adapted to the dataset if necessary  
- The pipeline can be applied iteratively to subpopulations  

### Step 2 — Generate cluster datasets
This script:
- re-loads `converted_data`
- applies the same classification
- separates trajectories into:
  - `stationary_data.mat`
  - `round_data.mat`
  - `motile_data.mat`
- performs clustering on directional trajectories
- generates cluster-specific datasets:
  - `cluster_1_data.mat`
  - `cluster_2_data.mat`
  - ...
- saves all results in: `video_folder/Collective_splittingCluster/`
Additionally, a struct containing all clusters is saved (`cluster_struct_data.mat`)

### Parameters to be set
The main parameters (modifiable in the script) are:

1) `main_folder`  
2) `sample_folder` (pattern used to identify experiment folders)  
3) `video_folder` (pattern used to identify video folders)  
4) `matFileName` (set to `converted_data.mat`)  
5) `resultsFolder` (set to `Collective_splittingCluster`)  

Kinematic and analysis parameters:

- `minDisplacement` → threshold for distinguishing motile vs stationary cells (µm)  
- `minStraightness` → threshold for directional motion  
- `hasLight` → set:
  - `true` if light stimulus is present  
  - `false` otherwise  
- `lightDirection` → direction of illumination (vector)  
- `nClusters` → number of clusters used to divide the directional population  

---

### Notes on usage (important)

The script is **semi-automatic**:
- it automatically scans multiple folders (`sample_folder` and `video_folder`)
- it processes all datasets in batch
However:
⚠️ Cluster labels are not intrinsically comparable across datasets unless the **clustering configuration is consistent**.

- If different datasets require different numbers of clusters:
  - the script should be run **separately on individual folders/files**
  - `nClusters` must be adjusted accordingly before execution
This ensures consistency in the definition and interpretation of cluster populations across datasets.

## Re-analysis of subpopulations
Each cluster dataset (e.g. `cluster_1_data.mat`) has the same structure as `converted_data`.
This allows re-analysis after clustering, run: Collective_splitting_runner.m
It generates separate datasets:
  - `cluster_1_data.mat`
  - `cluster_2_data.mat`
  - ...

These files can be re-analyzed individually in the Step 3.

---

### Step 3 — Re-analysis of clusters (optional)
Cluster datasets can be reloaded into: CollectiveMotionAnalyzer_udm_lightOnOff_runner.m
⚠️ When analyzing a single cluster:
- set the number of clusters to **1**
- treat the dataset as a standalone population
- - change
1) mainfolder
2) name of the uploading file like `converted_data` into subpopulation file (staionary_data.mat, round_data.mat, cluster_1_data etc...)
3) name of the variable (converted_data into round_data, cluster_k_data etc...)
4) results folder, for expample new folder like 'Collective_cluster1'

5)You can also set all the parametrs in the **Step 2**
