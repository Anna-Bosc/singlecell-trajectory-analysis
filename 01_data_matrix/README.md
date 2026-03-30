# Data matrix generation (TrackMate preprocessing)
This folder contains the MATLAB pipeline used to convert TrackMate outputs into a structured dataset suitable for downstream kinematic and MSD analysis.

## Overview
The script processes multiple experiments and videos automatically, extracting trajectory information from TrackMate output files and converting pixel-based data into physical units (µm and seconds).

## Folder structure
The input data must be organized as follows:
main_folder/
│
├── experiment_folder/
│ ├── video_folder/
│ │ └── TrackMate output file (_save.)


- `main_folder`: main directory containing all experiments  
- `experiment_folder`: folders grouping experimental conditions (name defined by the user)  
- `video_folder`: subfolders containing individual videos  
- TrackMate files: exported tracking files (e.g. `.xml`), containing a common keyword (e.g. `save`)

⚠️ **Important:**  
The user must define in the script:
- the path to `main_folder`
- the naming pattern for:
  - experiment folders  
  - video folders  
  - TrackMate files (e.g. common keyword like `save`)

---

## Required files
This folder includes:

- `Tracking_codeAUTO_conversionUDM.mlx` → main script (entry point)
- `convertUnits.m` → unit conversion function
- TrackMate helper functions (e.g. `trackmateSpots`, `trackmateEdges`)
⚠️ TrackMate helper functions are not original contributions of this repository and are included for compatibility with TrackMate outputs.

## Usage
1. Open MATLAB  
2. Run: Tracking_codeAUTO_conversionUDM.mlx
3. Provide the required inputs:

- `fps`: frame rate (frames per second)  
- `roiPixels`: number of pixels corresponding to **10 µm**

---
## Calibration (important)
The conversion from pixels to micrometers is handled by `convertUnits.m`.
- If your data is **not calibrated**:
  - insert the number of pixels corresponding to 10 µm
- If your data is **already calibrated in µm**:
  - set `roiPixels = 10`  
  → this results in a conversion factor of 1 (no change)

---
## Output

For each `video_folder`, the script generates:

- `all_edges.mat` → raw trajectory data  
- `converted_data.mat` → calibrated dataset (used for further analysis)  
- `tracking.fig` and `tracking.png` → trajectory visualization  

The file `converted_data.mat` is the output required for the subsequent analysis steps (folders `02_kinematic_analysis` and `03_msd_analysis`).

---

## Notes
- The script is designed for batch processing of multiple experiments and conditions  
- The workflow is modular and can be adapted to different datasets  
- Users should ensure consistency in folder naming and TrackMate export format  

---
