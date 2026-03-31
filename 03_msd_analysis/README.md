## MSD analysis (semi-automatic)

This step computes the Mean Squared Displacement (MSD) and performs advanced model fitting on selected trajectory datasets.

**Files**
calcoloMSD_completo_udm_AUTO.m → main script
draw_flash_areas.m → utility function for plotting flash intervals
Overview

The script:

scans multiple folders automatically
loads a selected dataset (e.g. converted_data.mat)
computes MSD over time intervals and evaluates:
- MSD evolution per interval
- average MSD per interval
- per-track MSD distributions
- performs multi-model fitting (linear, exponential, power-law, OU, etc.)
generates:
- plots (.fig, .png)
- structured .mat outputs
- .xlsx file with all results

**Input data**
The script expects as input a dataset with the same structure as converted_data, for example:
converted_data
sationary_data
motile_data.mat
round_data.mat
cluster_1_data.mat

⚠️ The variable name inside the file must match what is loaded in the script (e.g. converted_data, round_data, cluster_k_data etc...).

**Parameters to be set**
The main parameters (modifiable in the script) are:
1) main_folder
2) sample_folder (pattern used to identify experiment folders)
3) video_folder (pattern used to identify analysis folders)
4) input file pattern (e.g.*converted_data.mat, *cluster1_data.mat, etc...) and **variable name of the file** (e.g. converted_data, cluster_k_data.mat, etc...)
5) output folder (e.g. MSD_global, MSD_cluster1 etc...)

# Analysis parameters:

frame_intervals → number of frames per MSD interval
flash_intervals_frames → intervals where stimulation occurs

## Output

Results are saved in output folder set.

Outputs include:
1) msd_complete_analysis.xlsx → all numerical results
2) fit_parameters_models.xlsx → fit parameters per model
3) .mat files:
msd_evolutions.mat
msd_per_alga_all.mat
fit_results.mat
param_struct.mat
4) plots:
MSD evolution
normalized MSD
model fits
parameter evolution
boxplots of MSD distributions

⚠️**Notes on usage (important)**

The script is semi-automatic:
  it automatically scans folders (sample_folder, video_folder)
  it processes multiple datasets in batch
However:
⚠️ Particular attention must be paid to file selection and variable names, as incorrect settings may lead to:
1) loading the wrong dataset
2) overwriting previous results

Critical lines to verify before running:
  file_struct = dir(fullfile(video_path, '*converted_data.mat'));
file selection:
  msd_path = fullfile(video_path, 'MSD_global');
variable loaded from .mat:
  converted_data = dataStruct.converted_data;
frame consistency:
  max_frames = max(converted_data.FRAME_SOURCE);

⚠️ If you change dataset type (e.g. from round_data to cluster_1_data), you must update both:
file pattern (*cluster_1_data.mat)
variable name (dataStruct.cluster_1_data)
**Best practice**
Always run the script on a copy of the dataset when testing
Keep naming conventions consistent across files
Avoid mixing datasets with different preprocessing or filtering steps
Verify that the correct dataset is loaded before batch execution
