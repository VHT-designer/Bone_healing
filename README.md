# Sensors Bone Fracture
This repository provides the computational models, simulation scripts, and numerical datasets supporting the study of surface bioimpedance for assessing simulated bone-fracture healing. The materials are organized into three directories: `Code` contains the MATLAB scripts and simulation configurations, `Data` contains the numerical datasets in CSV format, and `Comsol_3D` contains the COMSOL Multiphysics models. This README describes the individual files, computational requirements, and procedures for executing the simulation workflows.

## Structure

```text
V:/Journal/Sensor/
  Read_me.md
  Code/
    sensor_setup.m
    Start_COMSOL.ps1
    COMSOL/
    Common/
    A4_Electrode_Sweep/
    Workers/
  Comsol_3D/
    Wenner/
    Schlumberger/
    Dipole/
  Data/
    01_COMSOL_Raw/
    02_Paper_Tables/
    03_Electrode_1kHz/
    Runs/revised_models/
```

The project uses three top-level folders directly inside `V:/Journal/Sensor`: `Code` for MATLAB sweep code and configuration, `Data` for supplied CSV files and generated results, and `Comsol_3D` for the 15 current user-edited models. Production and A4 configurations load these models. Keep the folder names and their relative positions as shown above. This README stays directly in the Sensor folder.

## Requirements and startup

Use COMSOL 6.4 with AC/DC and LiveLink for MATLAB. Local configs use `C:/Program Files/COMSOL/COMSOL64/Multiphysics/mli`.

Start a server from PowerShell:

```powershell
& 'V:\Journal\Sensor\Code\Start_COMSOL.ps1' -Port 2045 -Cores 8
```

In MATLAB:

```matlab
addpath('V:/Journal/Sensor/Code');
S = sensor_setup(2045);
cfg = fullfile(S.projectDir,'Code','COMSOL','config_newrun.json');
port = S.cfg.comsol.server_port;
```

Use the code under `V:/Journal/Sensor/Code` for the commands in this README. The local configurations use paths rooted at `V:/Journal/Sensor`.

## Model inventory and conventions

For each configuration, the Cole Normal model represents S5 and the Cole Fracture model represents S0–S4 after applying the configured state. Use the `_mesh3` Normal versions for Wenner and Schlumberger and the `_mixfix` Schlumberger Fracture version. Sensitivity pairs are used by A4 at 1 kHz.

| Array | Re (mm) | b (mm) | n | Exported impedance |
|---|---:|---:|---:|---|
| Wenner | 2 | 3 | 2 | `(bnd2-bnd3)/I` |
| Schlumberger | 2 | 3 | 2 | `(bnd2-bnd3)/I` |
| Dipole | 2 | 6 | 1 | `-(bnd3-bnd4)/I` |

Electrodes E1–E4 follow increasing axial z. Wenner/Schlumberger inject through E1/E4 and sense E2/E3. Dipole injects through E1/E2 and senses E3/E4. Terminal current is 0.005 A.

The six Cole studies use `10^{range(0,0.02,5)}` Hz: 251 logarithmic points from 1 Hz to 100 kHz. Production, anatomy, conductivity, contact and new mesh sweeps use the configured 251-point grid. Smoke runs use 1, 1000 and 100000 Hz. A4/Sensitivity remains at 1000 Hz in both frequency steps.

Fracture starting settings are c=0 and blood properties. Runners set c=0,0.5,1,1.5,2 and the appropriate dielectric state for S0–S4. Saved baseline settings are not a substitute for applying each state.

The supplied models retain target marrow radius 6 mm, adjacent cortical outer radius 5 mm and transverse fracture semi-axes `15-2*c`. These differ from manuscript Table 1/Section 2.5. The code preserves those model definitions; existing spectra/tables have not been regenerated after the model revisions.

The three `Sensitivity_Depth` files disable bone/marrow geometry and materials. They are background depth-sensitivity models, not intact S5 bone models. For bone-position variation use `BFH_run_anat` on the Cole model.

## Run simulations

```matlab
BFH_run_newdata(cfg,'smoke',{'Wenner'},'both_linear','none');
BFH_run_newdata(cfg,'cole',{'Wenner','Schlumberger','Dipole'},'both_linear','none');
BFH_run_newdata(cfg,'cole',{'Wenner'},'geom_only','none');
BFH_run_newdata(cfg,'cole',{'Wenner'},'diel_linear','none');
BFH_run_newdata(cfg,'cole',{'Wenner'},'both_log','none');
BFH_run_anat(cfg,'Wenner',port,[],'','',{'S0','S4'});
BFH_run_sens(cfg,'Wenner',port,[],'S2','');
BFH_run_mesh(cfg,'Wenner',port,{'S0','S1','S2','S3','S4','S5'},{'finer','xfine'},'');
BFH_run_contact(cfg,'Wenner',port,{'S0','S1','S2','S3','S4','S5'}, ...
    {'ideal','const1k','const10k','zc_inf'},'','');
A4_sweep_volume_metrics('','smoke','Wenner');
A4_sweep_volume_metrics('','prod','Dipole');
```

Run the desired command, not necessarily every line. Worker scripts retain their own ports; start matching COMSOL 6.4 servers before using them.

## Outputs and resume

New results go to `Data/Runs/revised_models/`, divided into `comsol_new`, `anat`, `sens`, `mesh`, `contact` and `A4`. CSV spectra contain `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` and metadata sidecars record applied settings.

Runners skip existing output files or A4 geometry rows. To repeat a simulation after changing a model, use a new output directory or archive the previous output files first. Check final failure counts and finite CSV values. Do not assume a returned MATLAB prompt means every case succeeded.

`Data/01_COMSOL_Raw` contains 169 historical spectra: 145 with 251 frequencies and 24 mesh spectra with 61 frequencies. They remain unchanged. Corrected A4 Dipole output and new 251-point mesh runs must not be confused with those historical datasets. Numerical tables are under `Data/02_Paper_Tables`; electrode CSV exports are under `Data/03_Electrode_1kHz`.

No fitting, plotting or Monte Carlo code is included in this sweep package. Full production results have not been regenerated after the revisions.

## Local batch preparation

The direct BFH runner commands above are the recommended starting points. Workers are optional, machine-specific batch partitions, not a required execution order. Several worker filenames describe historical reruns; the exact calls are listed below. Avoid launching workers that write the same outputs simultaneously. Before using a worker that writes temporary configurations, create its configuration directory:

```matlab
configDir = 'V:/Journal/Sensor/Data/Runs/configs';
if ~isfolder(configDir), mkdir(configDir); end
```

`Data/04_Models` currently contains no model files and is not the current model location. The legacy `bfh_c_mapping_check.m` still points there and needs path updates before use. `Data/Runs` is a generated-results location; it may be empty before running. The main runners create their result directories.


## File-by-file reference

Paths below are relative to this README. Each supplied file is listed individually. Code helpers are called by the runners; they do not need to be executed one by one. Row counts exclude CSV headers.

### Reading the CSV files

For spectra, `freq_Hz` is frequency in Hz; `ReZ_Ohm` and `ImZ_Ohm` are the real and imaginary transfer impedance in ohms. Keep the stored imaginary sign. S0-S4 are fractured states; S5 is intact. For electrode outputs, `_N` and `_F` refer to intact and fractured models; `Re_mm` is electrode radius, `a_mm` spacing, and `n` the array factor. R2 is a circuit resistance; alpha2 (or n in the circuit-fit tables) is the constant-phase exponent. This n is distinct from the electrode geometry factor. AUC is dimensionless. Columns ending in `_pct` are percentages; `_mm` denotes millimetres.

Table files are supplied analysis results, not inputs to the COMSOL sweeps. Listing a table here does not certify that every stored column is identical to the final manuscript. In particular, earlier numerical-uncertainty columns must not be substituted for final mesh251 results.

### Code/A4_Electrode_Sweep

| File | Purpose and use | Rows / columns |
|---|---|---|
| [A4_sweep_volume_metrics.m](Code/A4_Electrode_Sweep/A4_sweep_volume_metrics.m) | Run the electrode geometry sweep on both sensitivity models at 1 kHz. Reads config_A4.json and the state table; exports A4_sweep_<family>.csv with sensitivity integrals and complex impedance. Existing geometry rows can be skipped. | Not a CSV. |
| [config_A4.json](Code/A4_Electrode_Sweep/config_A4.json) | A4 configuration: intact/fractured sensitivity model pairs, geometry ranges, 1 kHz evaluation, state input and sweep output paths. Read by A4_sweep_volume_metrics. | Not a CSV. |

### Code/Common/data

| File | Purpose and use | Rows / columns |
|---|---|---|
| [states_table_S0S5.csv](Code/Common/data/states_table_S0S5.csv) | Simulation input defining S0-S5, geometry values, blood fraction and whether the fracture region is present. Consumed by the state/material helpers; keep the original column names. | 6 rows; `state`, `k`, `dl_mm`, `a_mm`, `b_mm`, `w_blood`, `region_present`, `Mix_sigma_expr`, `Mix_epsilonr_expr` |

### Code/Common/matlab

| File | Purpose and use | Rows / columns |
|---|---|---|
| [bfh_apply_state.m](Code/Common/matlab/bfh_apply_state.m) | Internal state helper. Applies one state-table row to the loaded model geometry/material parameters. | Not a CSV. |
| [bfh_c_mapping_check.m](Code/Common/matlab/bfh_c_mapping_check.m) | Legacy diagnostic for geometry control c. Not ready to run from the current layout: it still references Data/04_Models, a COMSOL 6.2 interface and an obsolete state-table location. Use the current production runner for normal sweeps. | Not a CSV. |
| [bfh_connect.m](Code/Common/matlab/bfh_connect.m) | Internal connection helper. Adds the specified LiveLink directory and calls mphstart on the requested port. | Not a CSV. |
| [bfh_discover_model.m](Code/Common/matlab/bfh_discover_model.m) | Optional inspection utility. Loads an MPH and prints component/study/model structure information for identifying COMSOL tags. | Not a CSV. |
| [bfh_export_Z.m](Code/Common/matlab/bfh_export_Z.m) | Internal export helper. Reads frequency and complex impedance from a solved dataset, sorts by frequency and writes the spectrum and metadata using the export conventions. | Not a CSV. |
| [bfh_find_boundaries_by_box.m](Code/Common/matlab/bfh_find_boundaries_by_box.m) | Internal selection utility. Uses a coordinate box to find COMSOL boundary IDs and warns if none are found. | Not a CSV. |
| [bfh_first_study_tag.m](Code/Common/matlab/bfh_first_study_tag.m) | Internal study helper. Chooses the requested study tag when present, otherwise the first available study. | Not a CSV. |
| [bfh_pick_solved_dataset.m](Code/Common/matlab/bfh_pick_solved_dataset.m) | Internal result helper. Selects a dataset with an accessible solved frequency result for export. | Not a CSV. |
| [bfh_preflight_seat.m](Code/Common/matlab/bfh_preflight_seat.m) | Optional license helper. Checks external license availability when configured by the calling workflow; it does not perform a simulation. | Not a CSV. |
| [bfh_probe_details.m](Code/Common/matlab/bfh_probe_details.m) | Optional inspection utility. Loads an MPH and prints geometry/probe details used to inspect model selections. | Not a CSV. |
| [bfh_read_config.m](Code/Common/matlab/bfh_read_config.m) | Internal A4/configuration helper. Reads JSON, records the configuration directory and removes auxiliary x_ fields except the path-resolution field. | Not a CSV. |
| [bfh_read_states_table.m](Code/Common/matlab/bfh_read_states_table.m) | Internal input helper. Reads the state CSV and validates the required state, geometry, blood-fraction and region-presence columns. | Not a CSV. |
| [bfh_reduced_freq_plist.m](Code/Common/matlab/bfh_reduced_freq_plist.m) | Frequency utility. Returns a logarithmic frequency vector and COMSOL list; its default 12 points per decade gives 61 frequencies. Current production/mesh runners use the main configured grid. | Not a CSV. |
| [bfh_resolve_path.m](Code/Common/matlab/bfh_resolve_path.m) | Internal path helper. Preserves absolute paths and resolves relative paths against the configuration directory. | Not a CSV. |
| [bfh_set_freq_list.m](Code/Common/matlab/bfh_set_freq_list.m) | Internal study helper. Writes a frequency-list string to the specified COMSOL frequency-domain study feature. | Not a CSV. |
| [bfh_set_mesh_level.m](Code/Common/matlab/bfh_set_mesh_level.m) | Internal mesh helper. Sets automatic mesh size, rebuilds the mesh and returns its element count when available. | Not a CSV. |
| [bfh_write_csv.m](Code/Common/matlab/bfh_write_csv.m) | Internal output helper. Writes supplied numeric rows and headers as a CSV file. | Not a CSV. |
| [bfh_write_meta.m](Code/Common/matlab/bfh_write_meta.m) | Internal output helper. Writes export settings as a text metadata sidecar. Such runtime sidecars are separate from the supplied CSV-only data collection. | Not a CSV. |

### Code/COMSOL

| File | Purpose and use | Rows / columns |
|---|---|---|
| [BFH_apply_geom.m](Code/COMSOL/BFH_apply_geom.m) | Internal model helper. Applies the selected family geometry parameters to existing COMSOL parameters in memory. | Not a CSV. |
| [BFH_apply_override.m](Code/COMSOL/BFH_apply_override.m) | Internal material helper. Applies a named material override from the main configuration and returns descriptive metadata. | Not a CSV. |
| [BFH_apply_survey.m](Code/COMSOL/BFH_apply_survey.m) | Internal state/survey helper. Applies geometry control and dielectric mixing for both_linear, geom_only, diel_linear or both_log, using configuration and the state table. | Not a CSV. |
| [BFH_connect_any.m](Code/COMSOL/BFH_connect_any.m) | Internal connection helper. Reuses an available LiveLink session or attempts a connection using configured MATLAB interface paths and server settings. | Not a CSV. |
| [BFH_drop.m](Code/COMSOL/BFH_drop.m) | Internal cleanup helper. Removes a loaded model tag from the current COMSOL server session. | Not a CSV. |
| [BFH_force_mesh.m](Code/COMSOL/BFH_force_mesh.m) | Internal mesh helper. Applies configured mesh_hauto, rebuilds the mesh and checks that the element count is positive. | Not a CSV. |
| [BFH_grid_str.m](Code/COMSOL/BFH_grid_str.m) | Internal display helper. Formats the configured frequency range and sampling information for logs. | Not a CSV. |
| [BFH_hold_check.m](Code/COMSOL/BFH_hold_check.m) | Internal queue guard. Stops a new case when HOLD_QUEUE exists beside the COMSOL runner files. Remove that marker to resume. | Not a CSV. |
| [BFH_paths.m](Code/COMSOL/BFH_paths.m) | Internal path/configuration helper. Reads JSON, resolves project/state/helper locations, adds helpers and creates output, discovery and log directories; returns S. | Not a CSV. |
| [BFH_plist_from_cfg.m](Code/COMSOL/BFH_plist_from_cfg.m) | Internal frequency helper. Converts the configured logarithmic or file-based grid into a COMSOL frequency-list string and numeric vector. | Not a CSV. |
| [BFH_repair_mix.m](Code/COMSOL/BFH_repair_mix.m) | Internal material helper. Sets the canonical linear-mixture dielectric expressions in a loaded model; does not save a replacement MPH by itself. | Not a CSV. |
| [BFH_run_anat.m](Code/COMSOL/BFH_run_anat.m) | Anatomical/depth sweep entry point. Loads the Cole model, applies selected anatomy variants and states, and writes spectra under runs/revised_models/anat. Call with --list to inspect variant names without solving. | Not a CSV. |
| [BFH_run_contact.m](Code/COMSOL/BFH_run_contact.m) | Contact sweep entry point. Solves selected states for ideal, const1k, const10k or zc_inf contact and exports spectra under runs/revised_models/contact. | Not a CSV. |
| [BFH_run_mesh.m](Code/COMSOL/BFH_run_mesh.m) | Mesh sweep entry point. Solves selected states at the requested mesh levels and exports spectra under runs/revised_models/mesh. New sweeps use the configured 251-point grid. | Not a CSV. |
| [BFH_run_newdata.m](Code/COMSOL/BFH_run_newdata.m) | Main frequency sweep entry point. Reads the main configuration and state table, loads the selected Cole models, applies the survey/state, solves and exports Z_<family>_<state> CSV spectra plus metadata. Supports smoke and cole modes. | Not a CSV. |
| [BFH_run_sens.m](Code/COMSOL/BFH_run_sens.m) | Conductivity sweep entry point. Applies the baseline and tissue conductivity perturbations (normally S2, plus/minus 20%) and exports spectra under runs/revised_models/sens. | Not a CSV. |
| [BFH_stamp_env.m](Code/COMSOL/BFH_stamp_env.m) | Internal metadata helper. Adds COMSOL/runtime information and processor-count information to the export metadata. | Not a CSV. |
| [config_newrun.json](Code/COMSOL/config_newrun.json) | Main sweep configuration: frequency grid, selected states, model paths, array geometry, impedance expressions/signs, material mixing rules, mesh settings, server connection and output paths. Read by the BFH runners. | Not a CSV. |

### Code

| File | Purpose and use | Rows / columns |
|---|---|---|
| [sensor_setup.m](Code/sensor_setup.m) | Session entry point: adds the MATLAB helper and LiveLink paths, connects to COMSOL, and returns the project path/configuration structure S. Use the startup command above. | Not a CSV. |
| [Start_COMSOL.ps1](Code/Start_COMSOL.ps1) | Windows server launcher. Accepts a port and core count, checks the port, starts a hidden COMSOL server, and writes stdout/stderr logs under the runs directory. Start this before sensor_setup. | Not a CSV. |
| [test_sensor_paths.m](Code/test_sensor_paths.m) | Local validation entry point. Checks MATLAB code, configuration paths and the 251-point grid, then actually runs a three-frequency Wenner S0 COMSOL smoke solve on port 2055. Writes under Data/Tests/revised_models; this is not a static-only check. | Not a CSV. |

### Code/Workers

| File | Purpose and use | Rows / columns |
|---|---|---|
| [AN_W1.m](Code/Workers/AN_W1.m) | Optional local batch script on port 2046. Executes: `BFH_run_anat('V:\Journal\Sensor\Code\COMSOL\config_newrun.json', 'Wenner', 2046, [1 2 3 4])`. Requires the local absolute paths and matching server. Batch selection is encoded in this file. | Not a CSV. |
| [AN_W2.m](Code/Workers/AN_W2.m) | Optional local batch script on port 2047. Executes: `BFH_run_anat('V:\Journal\Sensor\Code\COMSOL\config_newrun.json', 'Wenner', 2047, [5 6 7 8])`. Requires the local absolute paths and matching server. Batch selection is encoded in this file. | Not a CSV. |
| [AN_W3.m](Code/Workers/AN_W3.m) | Optional local batch script on port 2048. Executes: `BFH_run_anat('V:\Journal\Sensor\Code\COMSOL\config_newrun.json', 'Wenner', 2048, [9 10 11 12])`. Requires the local absolute paths and matching server. Batch selection is encoded in this file. | Not a CSV. |
| [CG_DIP.m](Code/Workers/CG_DIP.m) | Optional local batch script on port 2048. Executes: `BFH_run_newdata(tmp, 'cole', {'Dipole'}, 'geom_only', 'none')`; `BFH_run_newdata(tmp, 'cole', {'Dipole'}, 'diel_linear', 'none')`. Requires the local absolute paths and matching server. Batch selection is encoded in this file. | Not a CSV. |
| [CG_FIX_DIP.m](Code/Workers/CG_FIX_DIP.m) | Optional local batch script on port 2048. Executes: `BFH_run_newdata(tmp, 'cole', {'Dipole'}, 'both_linear', 'none')`. Requires the local absolute paths and matching server. Batch selection is encoded in this file. | Not a CSV. |
| [CG_FIX_WEN.m](Code/Workers/CG_FIX_WEN.m) | Optional local batch script on port 2046. Executes: `BFH_run_newdata(tmp, 'cole', {'Wenner'}, 'both_linear', 'none')`. Requires the local absolute paths and matching server. Batch selection is encoded in this file. | Not a CSV. |
| [CG_SCH.m](Code/Workers/CG_SCH.m) | Optional local batch script on port 2047. Executes: `BFH_run_newdata(tmp, 'cole', {'Schlumberger'}, 'geom_only', 'none')`; `BFH_run_newdata(tmp, 'cole', {'Schlumberger'}, 'diel_linear', 'none')`. Requires the local absolute paths and matching server. Batch selection is encoded in this file. | Not a CSV. |
| [CG_WEN.m](Code/Workers/CG_WEN.m) | Optional local batch script on port 2046. Executes: `BFH_run_newdata(tmp, 'cole', {'Wenner'}, 'geom_only', 'none')`; `BFH_run_newdata(tmp, 'cole', {'Wenner'}, 'diel_linear', 'none')`. Requires the local absolute paths and matching server. Batch selection is encoded in this file. | Not a CSV. |
| [CT_W1.m](Code/Workers/CT_W1.m) | Optional local batch script on port 2046. Executes: `BFH_run_contact(cfg, 'Wenner', 2046, {'S0','S1'}, {'ideal','const1k','const10k','zc_inf'}, '', '')`. Requires the local absolute paths and matching server. Batch selection is encoded in this file. | Not a CSV. |
| [CT_W2.m](Code/Workers/CT_W2.m) | Optional local batch script on port 2047. Executes: `BFH_run_contact(cfg, 'Wenner', 2047, {'S2','S3'}, {'ideal','const1k','const10k','zc_inf'}, '', '')`. Requires the local absolute paths and matching server. Batch selection is encoded in this file. | Not a CSV. |
| [CT_W3.m](Code/Workers/CT_W3.m) | Optional local batch script on port 2048. Executes: `BFH_run_contact(cfg, 'Wenner', 2048, {'S4','S5'}, {'ideal','const1k','const10k','zc_inf'}, '', '')`. Requires the local absolute paths and matching server. Batch selection is encoded in this file. | Not a CSV. |
| [DP_W1.m](Code/Workers/DP_W1.m) | Optional local batch script on port 2046. Executes: `BFH_run_anat(cfg, 'Wenner', 2046, 21, '1 1000 100000', '_SMOKE', {'S0'})`; `BFH_run_anat(cfg, 'Wenner', 2046, 21, '', '', {'S0','S1','S2','S3','S4'})`; `BFH_run_anat(cfg, 'Wenner', 2046, 4, '', '', {'S1','S2'})`. Requires the local absolute paths and matching server. Batch selection is encoded in this file. | Not a CSV. |
| [DP_W2.m](Code/Workers/DP_W2.m) | Optional local batch script on port 2047. Executes: `BFH_run_anat(cfg, 'Wenner', 2047, 22, '1 1000 100000', '_SMOKE', {'S0'})`; `BFH_run_anat(cfg, 'Wenner', 2047, 22, '', '', {'S0','S1','S2','S3','S4'})`; `BFH_run_anat(cfg, 'Wenner', 2047, 5, '', '', {'S1','S2'})`. Requires the local absolute paths and matching server. Batch selection is encoded in this file. | Not a CSV. |
| [DP_W3.m](Code/Workers/DP_W3.m) | Optional local batch script on port 2048. Executes: `BFH_run_anat(cfg, 'Wenner', 2048, 23, '1 1000 100000', '_SMOKE', {'S0'})`; `BFH_run_anat(cfg, 'Wenner', 2048, 23, '', '', {'S0','S1','S2','S3','S4'})`; `BFH_run_anat(cfg, 'Wenner', 2048, 4, '', '', {'S3'})`; `BFH_run_anat(cfg, 'Wenner', 2048, 5, '', '', {'S3'})`. Requires the local absolute paths and matching server. Batch selection is encoded in this file. | Not a CSV. |
| [LG_DIP.m](Code/Workers/LG_DIP.m) | Optional local batch script on port 2048. Executes: `BFH_run_newdata(tmp, 'cole', {'Dipole'}, 'both_log', 'none')`. Requires the local absolute paths and matching server. Batch selection is encoded in this file. | Not a CSV. |
| [LG_SCH.m](Code/Workers/LG_SCH.m) | Optional local batch script on port 2047. Executes: `BFH_run_newdata(tmp, 'cole', {'Schlumberger'}, 'both_log', 'none')`. Requires the local absolute paths and matching server. Batch selection is encoded in this file. | Not a CSV. |
| [LG_WEN.m](Code/Workers/LG_WEN.m) | Optional local batch script on port 2046. Executes: `BFH_run_newdata(tmp, 'cole', {'Wenner'}, 'both_log', 'none')`. Requires the local absolute paths and matching server. Batch selection is encoded in this file. | Not a CSV. |
| [MS_D.m](Code/Workers/MS_D.m) | Optional local batch script on port 2047. Executes: `BFH_run_mesh(cfg, 'Dipole', 2047, {'S1'}, {'finer','xfine'}, '_SMOKE')`; `BFH_run_mesh(cfg, 'Dipole', 2047, {'S0','S3','S4','S5','S1','S2'}, {'finer','xfine'}, '')`. Requires the local absolute paths and matching server. Batch selection is encoded in this file. | Not a CSV. |
| [MS_W.m](Code/Workers/MS_W.m) | Optional local batch script on port 2046. Executes: `BFH_run_mesh(cfg, 'Wenner', 2046, {'S1'}, {'finer','xfine'}, '_SMOKE')`; `BFH_run_mesh(cfg, 'Wenner', 2046, {'S1','S2','S0','S3','S4','S5'}, {'finer','xfine'}, '')`. Requires the local absolute paths and matching server. Batch selection is encoded in this file. | Not a CSV. |
| [R2_DIP.m](Code/Workers/R2_DIP.m) | Optional local batch script on port 2048. Executes: `BFH_run_newdata(tmp, 'cole', {'Dipole'}, 'diel_linear', 'none')`; `BFH_run_newdata(tmp, 'cole', {'Dipole'}, 'both_linear', 'none')`. Requires the local absolute paths and matching server. Batch selection is encoded in this file. | Not a CSV. |
| [R2_SCH.m](Code/Workers/R2_SCH.m) | Optional local batch script on port 2047. Executes: `BFH_run_newdata(tmp, 'cole', {'Schlumberger'}, 'diel_linear', 'none')`; `BFH_run_newdata(tmp, 'cole', {'Wenner'}, 'both_linear', 'none')`. Requires the local absolute paths and matching server. Batch selection is encoded in this file. | Not a CSV. |
| [R2_WEN.m](Code/Workers/R2_WEN.m) | Optional local batch script on port 2046. Executes: `BFH_run_newdata(tmp, 'cole', {'Wenner'}, 'diel_linear', 'none')`; `BFH_run_newdata(tmp, 'cole', {'Wenner'}, 'both_linear', 'none')`. Requires the local absolute paths and matching server. Batch selection is encoded in this file. | Not a CSV. |
| [SN_W1.m](Code/Workers/SN_W1.m) | Optional local batch script on port 2046. Executes: `BFH_run_sens('V:\Journal\Sensor\Code\COMSOL\config_newrun.json', 'Wenner', 2046, [1 2 3 4 5], 'S2', '')`. Requires the local absolute paths and matching server. Batch selection is encoded in this file. | Not a CSV. |
| [SN_W2.m](Code/Workers/SN_W2.m) | Optional local batch script on port 2047. Executes: `BFH_run_sens('V:\Journal\Sensor\Code\COMSOL\config_newrun.json', 'Wenner', 2047, [6 7 8 9], 'S2', '')`. Requires the local absolute paths and matching server. Batch selection is encoded in this file. | Not a CSV. |
| [SN_W3.m](Code/Workers/SN_W3.m) | Optional local batch script on port 2048. Executes: `BFH_run_sens('V:\Journal\Sensor\Code\COMSOL\config_newrun.json', 'Wenner', 2048, [10 11 12 13], 'S2', '')`. Requires the local absolute paths and matching server. Batch selection is encoded in this file. | Not a CSV. |

### Comsol_3D/Dipole/Dipole_Cole

| File | Purpose and use | Rows / columns |
|---|---|---|
| [LEG3D_Fracture_Dipole_Cole.mph](Comsol_3D/Dipole/Dipole_Cole/LEG3D_Fracture_Dipole_Cole.mph) | Dipole fractured S0-S4, with state applied at runtime. Loaded by the frequency-domain BFH runners for impedance spectra. | Not a CSV. |
| [LEG3D_Normal_Dipole_Cole.mph](Comsol_3D/Dipole/Dipole_Cole/LEG3D_Normal_Dipole_Cole.mph) | Dipole intact S5. Loaded by the frequency-domain BFH runners for impedance spectra. | Not a CSV. |

### Comsol_3D/Dipole/Dipole_Sensitivity

| File | Purpose and use | Rows / columns |
|---|---|---|
| [LEG3D_Fracture_Dipole_Sensitivity.mph](Comsol_3D/Dipole/Dipole_Sensitivity/LEG3D_Fracture_Dipole_Sensitivity.mph) | Dipole fractured S0-S4, with state applied at runtime. Loaded by A4_sweep_volume_metrics for 1 kHz volume sensitivity and impedance. | Not a CSV. |
| [LEG3D_Normal_Dipole_Sensitivity.mph](Comsol_3D/Dipole/Dipole_Sensitivity/LEG3D_Normal_Dipole_Sensitivity.mph) | Dipole intact S5. Loaded by A4_sweep_volume_metrics for 1 kHz volume sensitivity and impedance. | Not a CSV. |

### Comsol_3D/Dipole

| File | Purpose and use | Rows / columns |
|---|---|---|
| [LEG3D_Normal_Dipole_Sensitivity_Depth.mph](Comsol_3D/Dipole/LEG3D_Normal_Dipole_Sensitivity_Depth.mph) | Dipole background depth-sensitivity model; bone/marrow disabled. Inspect its internal sweep in COMSOL; not an S5 replacement and not the BFH_run_anat model. | Not a CSV. |

### Comsol_3D/Schlumberger

| File | Purpose and use | Rows / columns |
|---|---|---|
| [LEG3D_Normal_Schulumberger_Sensitivity_Depth.mph](Comsol_3D/Schlumberger/LEG3D_Normal_Schulumberger_Sensitivity_Depth.mph) | Schlumberger background depth-sensitivity model; bone/marrow disabled. Inspect its internal sweep in COMSOL; not an S5 replacement and not the BFH_run_anat model. | Not a CSV. |

### Comsol_3D/Schlumberger/Schulumberger_Cole

| File | Purpose and use | Rows / columns |
|---|---|---|
| [LEG3D_Fracture_Schulumberger_Cole_mixfix.mph](Comsol_3D/Schlumberger/Schulumberger_Cole/LEG3D_Fracture_Schulumberger_Cole_mixfix.mph) | Schlumberger fractured S0-S4, with state applied at runtime. Loaded by the frequency-domain BFH runners for impedance spectra. | Not a CSV. |
| [LEG3D_Normal_Schulumberger_Cole_mesh3.mph](Comsol_3D/Schlumberger/Schulumberger_Cole/LEG3D_Normal_Schulumberger_Cole_mesh3.mph) | Schlumberger intact S5. Loaded by the frequency-domain BFH runners for impedance spectra. | Not a CSV. |

### Comsol_3D/Schlumberger/Schulumberger_Sensitivity

| File | Purpose and use | Rows / columns |
|---|---|---|
| [LEG3D_Fracture_Schulumberger_Sensitivity.mph](Comsol_3D/Schlumberger/Schulumberger_Sensitivity/LEG3D_Fracture_Schulumberger_Sensitivity.mph) | Schlumberger fractured S0-S4, with state applied at runtime. Loaded by A4_sweep_volume_metrics for 1 kHz volume sensitivity and impedance. | Not a CSV. |
| [LEG3D_Normal_Schulumberger_Sensitivity.mph](Comsol_3D/Schlumberger/Schulumberger_Sensitivity/LEG3D_Normal_Schulumberger_Sensitivity.mph) | Schlumberger intact S5. Loaded by A4_sweep_volume_metrics for 1 kHz volume sensitivity and impedance. | Not a CSV. |

### Comsol_3D/Wenner

| File | Purpose and use | Rows / columns |
|---|---|---|
| [LEG3D_Normal_Wenner_Sensitivity_Depth.mph](Comsol_3D/Wenner/LEG3D_Normal_Wenner_Sensitivity_Depth.mph) | Wenner background depth-sensitivity model; bone/marrow disabled. Inspect its internal sweep in COMSOL; not an S5 replacement and not the BFH_run_anat model. | Not a CSV. |

### Comsol_3D/Wenner/Wenner_Cole

| File | Purpose and use | Rows / columns |
|---|---|---|
| [LEG3D_Fracture_Wenner_Cole.mph](Comsol_3D/Wenner/Wenner_Cole/LEG3D_Fracture_Wenner_Cole.mph) | Wenner fractured S0-S4, with state applied at runtime. Loaded by the frequency-domain BFH runners for impedance spectra. | Not a CSV. |
| [LEG3D_Normal_Wenner_Cole_mesh3.mph](Comsol_3D/Wenner/Wenner_Cole/LEG3D_Normal_Wenner_Cole_mesh3.mph) | Wenner intact S5. Loaded by the frequency-domain BFH runners for impedance spectra. | Not a CSV. |

### Comsol_3D/Wenner/Wenner_Sensitivity

| File | Purpose and use | Rows / columns |
|---|---|---|
| [LEG3D_Fracture_Wenner_Sensitivity.mph](Comsol_3D/Wenner/Wenner_Sensitivity/LEG3D_Fracture_Wenner_Sensitivity.mph) | Wenner fractured S0-S4, with state applied at runtime. Loaded by A4_sweep_volume_metrics for 1 kHz volume sensitivity and impedance. | Not a CSV. |
| [LEG3D_Normal_Wenner_Sensitivity.mph](Comsol_3D/Wenner/Wenner_Sensitivity/LEG3D_Normal_Wenner_Sensitivity.mph) | Wenner intact S5. Loaded by A4_sweep_volume_metrics for 1 kHz volume sensitivity and impedance. | Not a CSV. |

### Data/01_COMSOL_Raw/anat

| File | Purpose and use | Rows / columns |
|---|---|---|
| [Z_Wenner_base_S0.csv](Data/01_COMSOL_Raw/anat/Z_Wenner_base_S0.csv) | Wenner, S0: anatomy variant base; baseline anatomy. Historical spectrum; not regenerated from the revised MPH set. | 251 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Wenner_base_S4.csv](Data/01_COMSOL_Raw/anat/Z_Wenner_base_S4.csv) | Wenner, S4: anatomy variant base; baseline anatomy. Historical spectrum; not regenerated from the revised MPH set. | 251 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Wenner_cort2_S0.csv](Data/01_COMSOL_Raw/anat/Z_Wenner_cort2_S0.csv) | Wenner, S0: anatomy variant cort2; cortical thickness 2 mm. Historical spectrum; not regenerated from the revised MPH set. | 251 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Wenner_cort2_S4.csv](Data/01_COMSOL_Raw/anat/Z_Wenner_cort2_S4.csv) | Wenner, S4: anatomy variant cort2; cortical thickness 2 mm. Historical spectrum; not regenerated from the revised MPH set. | 251 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Wenner_cort3_S0.csv](Data/01_COMSOL_Raw/anat/Z_Wenner_cort3_S0.csv) | Wenner, S0: anatomy variant cort3; cortical thickness 3 mm. Historical spectrum; not regenerated from the revised MPH set. | 251 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Wenner_cort3_S4.csv](Data/01_COMSOL_Raw/anat/Z_Wenner_cort3_S4.csv) | Wenner, S4: anatomy variant cort3; cortical thickness 3 mm. Historical spectrum; not regenerated from the revised MPH set. | 251 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Wenner_cort5_S0.csv](Data/01_COMSOL_Raw/anat/Z_Wenner_cort5_S0.csv) | Wenner, S0: anatomy variant cort5; cortical thickness 5 mm. Historical spectrum; not regenerated from the revised MPH set. | 251 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Wenner_cort5_S4.csv](Data/01_COMSOL_Raw/anat/Z_Wenner_cort5_S4.csv) | Wenner, S4: anatomy variant cort5; cortical thickness 5 mm. Historical spectrum; not regenerated from the revised MPH set. | 251 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Wenner_cort6_S0.csv](Data/01_COMSOL_Raw/anat/Z_Wenner_cort6_S0.csv) | Wenner, S0: anatomy variant cort6; cortical thickness 6 mm. Historical spectrum; not regenerated from the revised MPH set. | 251 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Wenner_cort6_S4.csv](Data/01_COMSOL_Raw/anat/Z_Wenner_cort6_S4.csv) | Wenner, S4: anatomy variant cort6; cortical thickness 6 mm. Historical spectrum; not regenerated from the revised MPH set. | 251 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Wenner_depth07_S0.csv](Data/01_COMSOL_Raw/anat/Z_Wenner_depth07_S0.csv) | Wenner, S0: anatomy variant depth07; cortical depth 7 mm. Historical spectrum; not regenerated from the revised MPH set. | 251 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Wenner_depth07_S4.csv](Data/01_COMSOL_Raw/anat/Z_Wenner_depth07_S4.csv) | Wenner, S4: anatomy variant depth07; cortical depth 7 mm. Historical spectrum; not regenerated from the revised MPH set. | 251 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Wenner_depth09_S0.csv](Data/01_COMSOL_Raw/anat/Z_Wenner_depth09_S0.csv) | Wenner, S0: anatomy variant depth09; cortical depth 9 mm. Historical spectrum; not regenerated from the revised MPH set. | 251 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Wenner_depth09_S4.csv](Data/01_COMSOL_Raw/anat/Z_Wenner_depth09_S4.csv) | Wenner, S4: anatomy variant depth09; cortical depth 9 mm. Historical spectrum; not regenerated from the revised MPH set. | 251 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Wenner_depth13_S0.csv](Data/01_COMSOL_Raw/anat/Z_Wenner_depth13_S0.csv) | Wenner, S0: anatomy variant depth13; cortical depth 13 mm. Historical spectrum; not regenerated from the revised MPH set. | 251 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Wenner_depth13_S1.csv](Data/01_COMSOL_Raw/anat/Z_Wenner_depth13_S1.csv) | Wenner, S1: anatomy variant depth13; cortical depth 13 mm. Historical spectrum; not regenerated from the revised MPH set. | 251 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Wenner_depth13_S2.csv](Data/01_COMSOL_Raw/anat/Z_Wenner_depth13_S2.csv) | Wenner, S2: anatomy variant depth13; cortical depth 13 mm. Historical spectrum; not regenerated from the revised MPH set. | 251 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Wenner_depth13_S3.csv](Data/01_COMSOL_Raw/anat/Z_Wenner_depth13_S3.csv) | Wenner, S3: anatomy variant depth13; cortical depth 13 mm. Historical spectrum; not regenerated from the revised MPH set. | 251 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Wenner_depth13_S4.csv](Data/01_COMSOL_Raw/anat/Z_Wenner_depth13_S4.csv) | Wenner, S4: anatomy variant depth13; cortical depth 13 mm. Historical spectrum; not regenerated from the revised MPH set. | 251 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Wenner_depth15_S0.csv](Data/01_COMSOL_Raw/anat/Z_Wenner_depth15_S0.csv) | Wenner, S0: anatomy variant depth15; cortical depth 15 mm. Historical spectrum; not regenerated from the revised MPH set. | 251 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Wenner_depth15_S1.csv](Data/01_COMSOL_Raw/anat/Z_Wenner_depth15_S1.csv) | Wenner, S1: anatomy variant depth15; cortical depth 15 mm. Historical spectrum; not regenerated from the revised MPH set. | 251 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Wenner_depth15_S2.csv](Data/01_COMSOL_Raw/anat/Z_Wenner_depth15_S2.csv) | Wenner, S2: anatomy variant depth15; cortical depth 15 mm. Historical spectrum; not regenerated from the revised MPH set. | 251 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Wenner_depth15_S3.csv](Data/01_COMSOL_Raw/anat/Z_Wenner_depth15_S3.csv) | Wenner, S3: anatomy variant depth15; cortical depth 15 mm. Historical spectrum; not regenerated from the revised MPH set. | 251 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Wenner_depth15_S4.csv](Data/01_COMSOL_Raw/anat/Z_Wenner_depth15_S4.csv) | Wenner, S4: anatomy variant depth15; cortical depth 15 mm. Historical spectrum; not regenerated from the revised MPH set. | 251 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Wenner_depth17_S0.csv](Data/01_COMSOL_Raw/anat/Z_Wenner_depth17_S0.csv) | Wenner, S0: anatomy variant depth17; cortical depth 17 mm. Historical spectrum; not regenerated from the revised MPH set. | 251 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Wenner_depth17_S1.csv](Data/01_COMSOL_Raw/anat/Z_Wenner_depth17_S1.csv) | Wenner, S1: anatomy variant depth17; cortical depth 17 mm. Historical spectrum; not regenerated from the revised MPH set. | 251 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Wenner_depth17_S2.csv](Data/01_COMSOL_Raw/anat/Z_Wenner_depth17_S2.csv) | Wenner, S2: anatomy variant depth17; cortical depth 17 mm. Historical spectrum; not regenerated from the revised MPH set. | 251 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Wenner_depth17_S3.csv](Data/01_COMSOL_Raw/anat/Z_Wenner_depth17_S3.csv) | Wenner, S3: anatomy variant depth17; cortical depth 17 mm. Historical spectrum; not regenerated from the revised MPH set. | 251 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Wenner_depth17_S4.csv](Data/01_COMSOL_Raw/anat/Z_Wenner_depth17_S4.csv) | Wenner, S4: anatomy variant depth17; cortical depth 17 mm. Historical spectrum; not regenerated from the revised MPH set. | 251 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Wenner_depth19_S0.csv](Data/01_COMSOL_Raw/anat/Z_Wenner_depth19_S0.csv) | Wenner, S0: anatomy variant depth19; cortical depth 19 mm. Historical spectrum; not regenerated from the revised MPH set. | 251 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Wenner_depth19_S1.csv](Data/01_COMSOL_Raw/anat/Z_Wenner_depth19_S1.csv) | Wenner, S1: anatomy variant depth19; cortical depth 19 mm. Historical spectrum; not regenerated from the revised MPH set. | 251 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Wenner_depth19_S2.csv](Data/01_COMSOL_Raw/anat/Z_Wenner_depth19_S2.csv) | Wenner, S2: anatomy variant depth19; cortical depth 19 mm. Historical spectrum; not regenerated from the revised MPH set. | 251 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Wenner_depth19_S3.csv](Data/01_COMSOL_Raw/anat/Z_Wenner_depth19_S3.csv) | Wenner, S3: anatomy variant depth19; cortical depth 19 mm. Historical spectrum; not regenerated from the revised MPH set. | 251 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Wenner_depth19_S4.csv](Data/01_COMSOL_Raw/anat/Z_Wenner_depth19_S4.csv) | Wenner, S4: anatomy variant depth19; cortical depth 19 mm. Historical spectrum; not regenerated from the revised MPH set. | 251 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Wenner_depth21_S0.csv](Data/01_COMSOL_Raw/anat/Z_Wenner_depth21_S0.csv) | Wenner, S0: anatomy variant depth21; cortical depth 21 mm. Historical spectrum; not regenerated from the revised MPH set. | 251 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Wenner_depth21_S1.csv](Data/01_COMSOL_Raw/anat/Z_Wenner_depth21_S1.csv) | Wenner, S1: anatomy variant depth21; cortical depth 21 mm. Historical spectrum; not regenerated from the revised MPH set. | 251 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Wenner_depth21_S2.csv](Data/01_COMSOL_Raw/anat/Z_Wenner_depth21_S2.csv) | Wenner, S2: anatomy variant depth21; cortical depth 21 mm. Historical spectrum; not regenerated from the revised MPH set. | 251 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Wenner_depth21_S3.csv](Data/01_COMSOL_Raw/anat/Z_Wenner_depth21_S3.csv) | Wenner, S3: anatomy variant depth21; cortical depth 21 mm. Historical spectrum; not regenerated from the revised MPH set. | 251 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Wenner_depth21_S4.csv](Data/01_COMSOL_Raw/anat/Z_Wenner_depth21_S4.csv) | Wenner, S4: anatomy variant depth21; cortical depth 21 mm. Historical spectrum; not regenerated from the revised MPH set. | 251 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Wenner_skin1_S0.csv](Data/01_COMSOL_Raw/anat/Z_Wenner_skin1_S0.csv) | Wenner, S0: anatomy variant skin1; skin thickness 1 mm. Historical spectrum; not regenerated from the revised MPH set. | 251 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Wenner_skin1_S4.csv](Data/01_COMSOL_Raw/anat/Z_Wenner_skin1_S4.csv) | Wenner, S4: anatomy variant skin1; skin thickness 1 mm. Historical spectrum; not regenerated from the revised MPH set. | 251 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Wenner_skin3_S0.csv](Data/01_COMSOL_Raw/anat/Z_Wenner_skin3_S0.csv) | Wenner, S0: anatomy variant skin3; skin thickness 3 mm. Historical spectrum; not regenerated from the revised MPH set. | 251 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Wenner_skin3_S4.csv](Data/01_COMSOL_Raw/anat/Z_Wenner_skin3_S4.csv) | Wenner, S4: anatomy variant skin3; skin thickness 3 mm. Historical spectrum; not regenerated from the revised MPH set. | 251 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Wenner_skin4_S0.csv](Data/01_COMSOL_Raw/anat/Z_Wenner_skin4_S0.csv) | Wenner, S0: anatomy variant skin4; skin thickness 4 mm. Historical spectrum; not regenerated from the revised MPH set. | 251 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Wenner_skin4_S4.csv](Data/01_COMSOL_Raw/anat/Z_Wenner_skin4_S4.csv) | Wenner, S4: anatomy variant skin4; skin thickness 4 mm. Historical spectrum; not regenerated from the revised MPH set. | 251 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |

### Data/01_COMSOL_Raw/comsol_new

| File | Purpose and use | Rows / columns |
|---|---|---|
| [Z_Dipole_S0.csv](Data/01_COMSOL_Raw/comsol_new/Z_Dipole_S0.csv) | Dipole, S0: main combined geometry and linear-mixing spectrum. Historical spectrum; not regenerated from the revised MPH set. | 251 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Dipole_S0_both_log.csv](Data/01_COMSOL_Raw/comsol_new/Z_Dipole_S0_both_log.csv) | Dipole, S0: combined geometry and logarithmic mixing. Historical spectrum; not regenerated from the revised MPH set. | 251 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Dipole_S0_diel_linear.csv](Data/01_COMSOL_Raw/comsol_new/Z_Dipole_S0_diel_linear.csv) | Dipole, S0: dielectric-only linear mixing at fixed geometry. Historical spectrum; not regenerated from the revised MPH set. | 251 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Dipole_S0_geom_only.csv](Data/01_COMSOL_Raw/comsol_new/Z_Dipole_S0_geom_only.csv) | Dipole, S0: geometry-only variation. Historical spectrum; not regenerated from the revised MPH set. | 251 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Dipole_S1.csv](Data/01_COMSOL_Raw/comsol_new/Z_Dipole_S1.csv) | Dipole, S1: main combined geometry and linear-mixing spectrum. Historical spectrum; not regenerated from the revised MPH set. | 251 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Dipole_S1_both_log.csv](Data/01_COMSOL_Raw/comsol_new/Z_Dipole_S1_both_log.csv) | Dipole, S1: combined geometry and logarithmic mixing. Historical spectrum; not regenerated from the revised MPH set. | 251 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Dipole_S1_diel_linear.csv](Data/01_COMSOL_Raw/comsol_new/Z_Dipole_S1_diel_linear.csv) | Dipole, S1: dielectric-only linear mixing at fixed geometry. Historical spectrum; not regenerated from the revised MPH set. | 251 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Dipole_S1_geom_only.csv](Data/01_COMSOL_Raw/comsol_new/Z_Dipole_S1_geom_only.csv) | Dipole, S1: geometry-only variation. Historical spectrum; not regenerated from the revised MPH set. | 251 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Dipole_S2.csv](Data/01_COMSOL_Raw/comsol_new/Z_Dipole_S2.csv) | Dipole, S2: main combined geometry and linear-mixing spectrum. Historical spectrum; not regenerated from the revised MPH set. | 251 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Dipole_S2_both_log.csv](Data/01_COMSOL_Raw/comsol_new/Z_Dipole_S2_both_log.csv) | Dipole, S2: combined geometry and logarithmic mixing. Historical spectrum; not regenerated from the revised MPH set. | 251 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Dipole_S2_diel_linear.csv](Data/01_COMSOL_Raw/comsol_new/Z_Dipole_S2_diel_linear.csv) | Dipole, S2: dielectric-only linear mixing at fixed geometry. Historical spectrum; not regenerated from the revised MPH set. | 251 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Dipole_S2_geom_only.csv](Data/01_COMSOL_Raw/comsol_new/Z_Dipole_S2_geom_only.csv) | Dipole, S2: geometry-only variation. Historical spectrum; not regenerated from the revised MPH set. | 251 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Dipole_S3.csv](Data/01_COMSOL_Raw/comsol_new/Z_Dipole_S3.csv) | Dipole, S3: main combined geometry and linear-mixing spectrum. Historical spectrum; not regenerated from the revised MPH set. | 251 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Dipole_S3_both_log.csv](Data/01_COMSOL_Raw/comsol_new/Z_Dipole_S3_both_log.csv) | Dipole, S3: combined geometry and logarithmic mixing. Historical spectrum; not regenerated from the revised MPH set. | 251 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Dipole_S3_diel_linear.csv](Data/01_COMSOL_Raw/comsol_new/Z_Dipole_S3_diel_linear.csv) | Dipole, S3: dielectric-only linear mixing at fixed geometry. Historical spectrum; not regenerated from the revised MPH set. | 251 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Dipole_S3_geom_only.csv](Data/01_COMSOL_Raw/comsol_new/Z_Dipole_S3_geom_only.csv) | Dipole, S3: geometry-only variation. Historical spectrum; not regenerated from the revised MPH set. | 251 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Dipole_S4.csv](Data/01_COMSOL_Raw/comsol_new/Z_Dipole_S4.csv) | Dipole, S4: main combined geometry and linear-mixing spectrum. Historical spectrum; not regenerated from the revised MPH set. | 251 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Dipole_S4_both_log.csv](Data/01_COMSOL_Raw/comsol_new/Z_Dipole_S4_both_log.csv) | Dipole, S4: combined geometry and logarithmic mixing. Historical spectrum; not regenerated from the revised MPH set. | 251 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Dipole_S4_diel_linear.csv](Data/01_COMSOL_Raw/comsol_new/Z_Dipole_S4_diel_linear.csv) | Dipole, S4: dielectric-only linear mixing at fixed geometry. Historical spectrum; not regenerated from the revised MPH set. | 251 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Dipole_S4_geom_only.csv](Data/01_COMSOL_Raw/comsol_new/Z_Dipole_S4_geom_only.csv) | Dipole, S4: geometry-only variation. Historical spectrum; not regenerated from the revised MPH set. | 251 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Dipole_S5.csv](Data/01_COMSOL_Raw/comsol_new/Z_Dipole_S5.csv) | Dipole, S5: main combined geometry and linear-mixing spectrum. Historical spectrum; not regenerated from the revised MPH set. | 251 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Schlumberger_S0.csv](Data/01_COMSOL_Raw/comsol_new/Z_Schlumberger_S0.csv) | Schlumberger, S0: main combined geometry and linear-mixing spectrum. Historical spectrum; not regenerated from the revised MPH set. | 251 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Schlumberger_S0_both_log.csv](Data/01_COMSOL_Raw/comsol_new/Z_Schlumberger_S0_both_log.csv) | Schlumberger, S0: combined geometry and logarithmic mixing. Historical spectrum; not regenerated from the revised MPH set. | 251 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Schlumberger_S0_diel_linear.csv](Data/01_COMSOL_Raw/comsol_new/Z_Schlumberger_S0_diel_linear.csv) | Schlumberger, S0: dielectric-only linear mixing at fixed geometry. Historical spectrum; not regenerated from the revised MPH set. | 251 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Schlumberger_S0_geom_only.csv](Data/01_COMSOL_Raw/comsol_new/Z_Schlumberger_S0_geom_only.csv) | Schlumberger, S0: geometry-only variation. Historical spectrum; not regenerated from the revised MPH set. | 251 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Schlumberger_S1.csv](Data/01_COMSOL_Raw/comsol_new/Z_Schlumberger_S1.csv) | Schlumberger, S1: main combined geometry and linear-mixing spectrum. Historical spectrum; not regenerated from the revised MPH set. | 251 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Schlumberger_S1_both_log.csv](Data/01_COMSOL_Raw/comsol_new/Z_Schlumberger_S1_both_log.csv) | Schlumberger, S1: combined geometry and logarithmic mixing. Historical spectrum; not regenerated from the revised MPH set. | 251 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Schlumberger_S1_diel_linear.csv](Data/01_COMSOL_Raw/comsol_new/Z_Schlumberger_S1_diel_linear.csv) | Schlumberger, S1: dielectric-only linear mixing at fixed geometry. Historical spectrum; not regenerated from the revised MPH set. | 251 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Schlumberger_S1_geom_only.csv](Data/01_COMSOL_Raw/comsol_new/Z_Schlumberger_S1_geom_only.csv) | Schlumberger, S1: geometry-only variation. Historical spectrum; not regenerated from the revised MPH set. | 251 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Schlumberger_S2.csv](Data/01_COMSOL_Raw/comsol_new/Z_Schlumberger_S2.csv) | Schlumberger, S2: main combined geometry and linear-mixing spectrum. Historical spectrum; not regenerated from the revised MPH set. | 251 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Schlumberger_S2_both_log.csv](Data/01_COMSOL_Raw/comsol_new/Z_Schlumberger_S2_both_log.csv) | Schlumberger, S2: combined geometry and logarithmic mixing. Historical spectrum; not regenerated from the revised MPH set. | 251 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Schlumberger_S2_diel_linear.csv](Data/01_COMSOL_Raw/comsol_new/Z_Schlumberger_S2_diel_linear.csv) | Schlumberger, S2: dielectric-only linear mixing at fixed geometry. Historical spectrum; not regenerated from the revised MPH set. | 251 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Schlumberger_S2_geom_only.csv](Data/01_COMSOL_Raw/comsol_new/Z_Schlumberger_S2_geom_only.csv) | Schlumberger, S2: geometry-only variation. Historical spectrum; not regenerated from the revised MPH set. | 251 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Schlumberger_S3.csv](Data/01_COMSOL_Raw/comsol_new/Z_Schlumberger_S3.csv) | Schlumberger, S3: main combined geometry and linear-mixing spectrum. Historical spectrum; not regenerated from the revised MPH set. | 251 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Schlumberger_S3_both_log.csv](Data/01_COMSOL_Raw/comsol_new/Z_Schlumberger_S3_both_log.csv) | Schlumberger, S3: combined geometry and logarithmic mixing. Historical spectrum; not regenerated from the revised MPH set. | 251 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Schlumberger_S3_diel_linear.csv](Data/01_COMSOL_Raw/comsol_new/Z_Schlumberger_S3_diel_linear.csv) | Schlumberger, S3: dielectric-only linear mixing at fixed geometry. Historical spectrum; not regenerated from the revised MPH set. | 251 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Schlumberger_S3_geom_only.csv](Data/01_COMSOL_Raw/comsol_new/Z_Schlumberger_S3_geom_only.csv) | Schlumberger, S3: geometry-only variation. Historical spectrum; not regenerated from the revised MPH set. | 251 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Schlumberger_S4.csv](Data/01_COMSOL_Raw/comsol_new/Z_Schlumberger_S4.csv) | Schlumberger, S4: main combined geometry and linear-mixing spectrum. Historical spectrum; not regenerated from the revised MPH set. | 251 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Schlumberger_S4_both_log.csv](Data/01_COMSOL_Raw/comsol_new/Z_Schlumberger_S4_both_log.csv) | Schlumberger, S4: combined geometry and logarithmic mixing. Historical spectrum; not regenerated from the revised MPH set. | 251 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Schlumberger_S4_diel_linear.csv](Data/01_COMSOL_Raw/comsol_new/Z_Schlumberger_S4_diel_linear.csv) | Schlumberger, S4: dielectric-only linear mixing at fixed geometry. Historical spectrum; not regenerated from the revised MPH set. | 251 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Schlumberger_S4_geom_only.csv](Data/01_COMSOL_Raw/comsol_new/Z_Schlumberger_S4_geom_only.csv) | Schlumberger, S4: geometry-only variation. Historical spectrum; not regenerated from the revised MPH set. | 251 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Schlumberger_S5.csv](Data/01_COMSOL_Raw/comsol_new/Z_Schlumberger_S5.csv) | Schlumberger, S5: main combined geometry and linear-mixing spectrum. Historical spectrum; not regenerated from the revised MPH set. | 251 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Wenner_S0.csv](Data/01_COMSOL_Raw/comsol_new/Z_Wenner_S0.csv) | Wenner, S0: main combined geometry and linear-mixing spectrum. Historical spectrum; not regenerated from the revised MPH set. | 251 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Wenner_S0_both_log.csv](Data/01_COMSOL_Raw/comsol_new/Z_Wenner_S0_both_log.csv) | Wenner, S0: combined geometry and logarithmic mixing. Historical spectrum; not regenerated from the revised MPH set. | 251 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Wenner_S0_diel_linear.csv](Data/01_COMSOL_Raw/comsol_new/Z_Wenner_S0_diel_linear.csv) | Wenner, S0: dielectric-only linear mixing at fixed geometry. Historical spectrum; not regenerated from the revised MPH set. | 251 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Wenner_S0_geom_only.csv](Data/01_COMSOL_Raw/comsol_new/Z_Wenner_S0_geom_only.csv) | Wenner, S0: geometry-only variation. Historical spectrum; not regenerated from the revised MPH set. | 251 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Wenner_S1.csv](Data/01_COMSOL_Raw/comsol_new/Z_Wenner_S1.csv) | Wenner, S1: main combined geometry and linear-mixing spectrum. Historical spectrum; not regenerated from the revised MPH set. | 251 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Wenner_S1_both_log.csv](Data/01_COMSOL_Raw/comsol_new/Z_Wenner_S1_both_log.csv) | Wenner, S1: combined geometry and logarithmic mixing. Historical spectrum; not regenerated from the revised MPH set. | 251 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Wenner_S1_diel_linear.csv](Data/01_COMSOL_Raw/comsol_new/Z_Wenner_S1_diel_linear.csv) | Wenner, S1: dielectric-only linear mixing at fixed geometry. Historical spectrum; not regenerated from the revised MPH set. | 251 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Wenner_S1_geom_only.csv](Data/01_COMSOL_Raw/comsol_new/Z_Wenner_S1_geom_only.csv) | Wenner, S1: geometry-only variation. Historical spectrum; not regenerated from the revised MPH set. | 251 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Wenner_S2.csv](Data/01_COMSOL_Raw/comsol_new/Z_Wenner_S2.csv) | Wenner, S2: main combined geometry and linear-mixing spectrum. Historical spectrum; not regenerated from the revised MPH set. | 251 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Wenner_S2_both_log.csv](Data/01_COMSOL_Raw/comsol_new/Z_Wenner_S2_both_log.csv) | Wenner, S2: combined geometry and logarithmic mixing. Historical spectrum; not regenerated from the revised MPH set. | 251 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Wenner_S2_diel_linear.csv](Data/01_COMSOL_Raw/comsol_new/Z_Wenner_S2_diel_linear.csv) | Wenner, S2: dielectric-only linear mixing at fixed geometry. Historical spectrum; not regenerated from the revised MPH set. | 251 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Wenner_S2_geom_only.csv](Data/01_COMSOL_Raw/comsol_new/Z_Wenner_S2_geom_only.csv) | Wenner, S2: geometry-only variation. Historical spectrum; not regenerated from the revised MPH set. | 251 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Wenner_S3.csv](Data/01_COMSOL_Raw/comsol_new/Z_Wenner_S3.csv) | Wenner, S3: main combined geometry and linear-mixing spectrum. Historical spectrum; not regenerated from the revised MPH set. | 251 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Wenner_S3_both_log.csv](Data/01_COMSOL_Raw/comsol_new/Z_Wenner_S3_both_log.csv) | Wenner, S3: combined geometry and logarithmic mixing. Historical spectrum; not regenerated from the revised MPH set. | 251 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Wenner_S3_diel_linear.csv](Data/01_COMSOL_Raw/comsol_new/Z_Wenner_S3_diel_linear.csv) | Wenner, S3: dielectric-only linear mixing at fixed geometry. Historical spectrum; not regenerated from the revised MPH set. | 251 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Wenner_S3_geom_only.csv](Data/01_COMSOL_Raw/comsol_new/Z_Wenner_S3_geom_only.csv) | Wenner, S3: geometry-only variation. Historical spectrum; not regenerated from the revised MPH set. | 251 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Wenner_S4.csv](Data/01_COMSOL_Raw/comsol_new/Z_Wenner_S4.csv) | Wenner, S4: main combined geometry and linear-mixing spectrum. Historical spectrum; not regenerated from the revised MPH set. | 251 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Wenner_S4_both_log.csv](Data/01_COMSOL_Raw/comsol_new/Z_Wenner_S4_both_log.csv) | Wenner, S4: combined geometry and logarithmic mixing. Historical spectrum; not regenerated from the revised MPH set. | 251 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Wenner_S4_diel_linear.csv](Data/01_COMSOL_Raw/comsol_new/Z_Wenner_S4_diel_linear.csv) | Wenner, S4: dielectric-only linear mixing at fixed geometry. Historical spectrum; not regenerated from the revised MPH set. | 251 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Wenner_S4_geom_only.csv](Data/01_COMSOL_Raw/comsol_new/Z_Wenner_S4_geom_only.csv) | Wenner, S4: geometry-only variation. Historical spectrum; not regenerated from the revised MPH set. | 251 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Wenner_S5.csv](Data/01_COMSOL_Raw/comsol_new/Z_Wenner_S5.csv) | Wenner, S5: main combined geometry and linear-mixing spectrum. Historical spectrum; not regenerated from the revised MPH set. | 251 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |

### Data/01_COMSOL_Raw/contact

| File | Purpose and use | Rows / columns |
|---|---|---|
| [Z_Wenner_S0_const10k.csv](Data/01_COMSOL_Raw/contact/Z_Wenner_S0_const10k.csv) | Wenner, S0: contact condition const10k. Historical spectrum; not regenerated from the revised MPH set. | 251 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Wenner_S0_const1k.csv](Data/01_COMSOL_Raw/contact/Z_Wenner_S0_const1k.csv) | Wenner, S0: contact condition const1k. Historical spectrum; not regenerated from the revised MPH set. | 251 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Wenner_S0_ideal.csv](Data/01_COMSOL_Raw/contact/Z_Wenner_S0_ideal.csv) | Wenner, S0: contact condition ideal. Historical spectrum; not regenerated from the revised MPH set. | 251 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Wenner_S0_zc_inf.csv](Data/01_COMSOL_Raw/contact/Z_Wenner_S0_zc_inf.csv) | Wenner, S0: contact condition zc_inf. Historical spectrum; not regenerated from the revised MPH set. | 251 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Wenner_S1_const10k.csv](Data/01_COMSOL_Raw/contact/Z_Wenner_S1_const10k.csv) | Wenner, S1: contact condition const10k. Historical spectrum; not regenerated from the revised MPH set. | 251 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Wenner_S1_const1k.csv](Data/01_COMSOL_Raw/contact/Z_Wenner_S1_const1k.csv) | Wenner, S1: contact condition const1k. Historical spectrum; not regenerated from the revised MPH set. | 251 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Wenner_S1_ideal.csv](Data/01_COMSOL_Raw/contact/Z_Wenner_S1_ideal.csv) | Wenner, S1: contact condition ideal. Historical spectrum; not regenerated from the revised MPH set. | 251 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Wenner_S1_zc_inf.csv](Data/01_COMSOL_Raw/contact/Z_Wenner_S1_zc_inf.csv) | Wenner, S1: contact condition zc_inf. Historical spectrum; not regenerated from the revised MPH set. | 251 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Wenner_S2_const10k.csv](Data/01_COMSOL_Raw/contact/Z_Wenner_S2_const10k.csv) | Wenner, S2: contact condition const10k. Historical spectrum; not regenerated from the revised MPH set. | 251 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Wenner_S2_const1k.csv](Data/01_COMSOL_Raw/contact/Z_Wenner_S2_const1k.csv) | Wenner, S2: contact condition const1k. Historical spectrum; not regenerated from the revised MPH set. | 251 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Wenner_S2_ideal.csv](Data/01_COMSOL_Raw/contact/Z_Wenner_S2_ideal.csv) | Wenner, S2: contact condition ideal. Historical spectrum; not regenerated from the revised MPH set. | 251 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Wenner_S2_zc_inf.csv](Data/01_COMSOL_Raw/contact/Z_Wenner_S2_zc_inf.csv) | Wenner, S2: contact condition zc_inf. Historical spectrum; not regenerated from the revised MPH set. | 251 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Wenner_S3_const10k.csv](Data/01_COMSOL_Raw/contact/Z_Wenner_S3_const10k.csv) | Wenner, S3: contact condition const10k. Historical spectrum; not regenerated from the revised MPH set. | 251 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Wenner_S3_const1k.csv](Data/01_COMSOL_Raw/contact/Z_Wenner_S3_const1k.csv) | Wenner, S3: contact condition const1k. Historical spectrum; not regenerated from the revised MPH set. | 251 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Wenner_S3_ideal.csv](Data/01_COMSOL_Raw/contact/Z_Wenner_S3_ideal.csv) | Wenner, S3: contact condition ideal. Historical spectrum; not regenerated from the revised MPH set. | 251 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Wenner_S3_zc_inf.csv](Data/01_COMSOL_Raw/contact/Z_Wenner_S3_zc_inf.csv) | Wenner, S3: contact condition zc_inf. Historical spectrum; not regenerated from the revised MPH set. | 251 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Wenner_S4_const10k.csv](Data/01_COMSOL_Raw/contact/Z_Wenner_S4_const10k.csv) | Wenner, S4: contact condition const10k. Historical spectrum; not regenerated from the revised MPH set. | 251 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Wenner_S4_const1k.csv](Data/01_COMSOL_Raw/contact/Z_Wenner_S4_const1k.csv) | Wenner, S4: contact condition const1k. Historical spectrum; not regenerated from the revised MPH set. | 251 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Wenner_S4_ideal.csv](Data/01_COMSOL_Raw/contact/Z_Wenner_S4_ideal.csv) | Wenner, S4: contact condition ideal. Historical spectrum; not regenerated from the revised MPH set. | 251 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Wenner_S4_zc_inf.csv](Data/01_COMSOL_Raw/contact/Z_Wenner_S4_zc_inf.csv) | Wenner, S4: contact condition zc_inf. Historical spectrum; not regenerated from the revised MPH set. | 251 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Wenner_S5_const10k.csv](Data/01_COMSOL_Raw/contact/Z_Wenner_S5_const10k.csv) | Wenner, S5: contact condition const10k. Historical spectrum; not regenerated from the revised MPH set. | 251 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Wenner_S5_const1k.csv](Data/01_COMSOL_Raw/contact/Z_Wenner_S5_const1k.csv) | Wenner, S5: contact condition const1k. Historical spectrum; not regenerated from the revised MPH set. | 251 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Wenner_S5_ideal.csv](Data/01_COMSOL_Raw/contact/Z_Wenner_S5_ideal.csv) | Wenner, S5: contact condition ideal. Historical spectrum; not regenerated from the revised MPH set. | 251 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Wenner_S5_zc_inf.csv](Data/01_COMSOL_Raw/contact/Z_Wenner_S5_zc_inf.csv) | Wenner, S5: contact condition zc_inf. Historical spectrum; not regenerated from the revised MPH set. | 251 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |

### Data/01_COMSOL_Raw/mesh

| File | Purpose and use | Rows / columns |
|---|---|---|
| [Z_Dipole_S0_finer.csv](Data/01_COMSOL_Raw/mesh/Z_Dipole_S0_finer.csv) | Dipole, S0: mesh comparison at finer mesh. Historical spectrum; not regenerated from the revised MPH set. | 61 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Dipole_S0_xfine.csv](Data/01_COMSOL_Raw/mesh/Z_Dipole_S0_xfine.csv) | Dipole, S0: mesh comparison at extra-fine mesh. Historical spectrum; not regenerated from the revised MPH set. | 61 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Dipole_S1_finer.csv](Data/01_COMSOL_Raw/mesh/Z_Dipole_S1_finer.csv) | Dipole, S1: mesh comparison at finer mesh. Historical spectrum; not regenerated from the revised MPH set. | 61 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Dipole_S1_xfine.csv](Data/01_COMSOL_Raw/mesh/Z_Dipole_S1_xfine.csv) | Dipole, S1: mesh comparison at extra-fine mesh. Historical spectrum; not regenerated from the revised MPH set. | 61 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Dipole_S2_finer.csv](Data/01_COMSOL_Raw/mesh/Z_Dipole_S2_finer.csv) | Dipole, S2: mesh comparison at finer mesh. Historical spectrum; not regenerated from the revised MPH set. | 61 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Dipole_S2_xfine.csv](Data/01_COMSOL_Raw/mesh/Z_Dipole_S2_xfine.csv) | Dipole, S2: mesh comparison at extra-fine mesh. Historical spectrum; not regenerated from the revised MPH set. | 61 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Dipole_S3_finer.csv](Data/01_COMSOL_Raw/mesh/Z_Dipole_S3_finer.csv) | Dipole, S3: mesh comparison at finer mesh. Historical spectrum; not regenerated from the revised MPH set. | 61 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Dipole_S3_xfine.csv](Data/01_COMSOL_Raw/mesh/Z_Dipole_S3_xfine.csv) | Dipole, S3: mesh comparison at extra-fine mesh. Historical spectrum; not regenerated from the revised MPH set. | 61 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Dipole_S4_finer.csv](Data/01_COMSOL_Raw/mesh/Z_Dipole_S4_finer.csv) | Dipole, S4: mesh comparison at finer mesh. Historical spectrum; not regenerated from the revised MPH set. | 61 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Dipole_S4_xfine.csv](Data/01_COMSOL_Raw/mesh/Z_Dipole_S4_xfine.csv) | Dipole, S4: mesh comparison at extra-fine mesh. Historical spectrum; not regenerated from the revised MPH set. | 61 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Dipole_S5_finer.csv](Data/01_COMSOL_Raw/mesh/Z_Dipole_S5_finer.csv) | Dipole, S5: mesh comparison at finer mesh. Historical spectrum; not regenerated from the revised MPH set. | 61 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Dipole_S5_xfine.csv](Data/01_COMSOL_Raw/mesh/Z_Dipole_S5_xfine.csv) | Dipole, S5: mesh comparison at extra-fine mesh. Historical spectrum; not regenerated from the revised MPH set. | 61 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Wenner_S0_finer.csv](Data/01_COMSOL_Raw/mesh/Z_Wenner_S0_finer.csv) | Wenner, S0: mesh comparison at finer mesh. Historical spectrum; not regenerated from the revised MPH set. | 61 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Wenner_S0_xfine.csv](Data/01_COMSOL_Raw/mesh/Z_Wenner_S0_xfine.csv) | Wenner, S0: mesh comparison at extra-fine mesh. Historical spectrum; not regenerated from the revised MPH set. | 61 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Wenner_S1_finer.csv](Data/01_COMSOL_Raw/mesh/Z_Wenner_S1_finer.csv) | Wenner, S1: mesh comparison at finer mesh. Historical spectrum; not regenerated from the revised MPH set. | 61 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Wenner_S1_xfine.csv](Data/01_COMSOL_Raw/mesh/Z_Wenner_S1_xfine.csv) | Wenner, S1: mesh comparison at extra-fine mesh. Historical spectrum; not regenerated from the revised MPH set. | 61 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Wenner_S2_finer.csv](Data/01_COMSOL_Raw/mesh/Z_Wenner_S2_finer.csv) | Wenner, S2: mesh comparison at finer mesh. Historical spectrum; not regenerated from the revised MPH set. | 61 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Wenner_S2_xfine.csv](Data/01_COMSOL_Raw/mesh/Z_Wenner_S2_xfine.csv) | Wenner, S2: mesh comparison at extra-fine mesh. Historical spectrum; not regenerated from the revised MPH set. | 61 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Wenner_S3_finer.csv](Data/01_COMSOL_Raw/mesh/Z_Wenner_S3_finer.csv) | Wenner, S3: mesh comparison at finer mesh. Historical spectrum; not regenerated from the revised MPH set. | 61 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Wenner_S3_xfine.csv](Data/01_COMSOL_Raw/mesh/Z_Wenner_S3_xfine.csv) | Wenner, S3: mesh comparison at extra-fine mesh. Historical spectrum; not regenerated from the revised MPH set. | 61 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Wenner_S4_finer.csv](Data/01_COMSOL_Raw/mesh/Z_Wenner_S4_finer.csv) | Wenner, S4: mesh comparison at finer mesh. Historical spectrum; not regenerated from the revised MPH set. | 61 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Wenner_S4_xfine.csv](Data/01_COMSOL_Raw/mesh/Z_Wenner_S4_xfine.csv) | Wenner, S4: mesh comparison at extra-fine mesh. Historical spectrum; not regenerated from the revised MPH set. | 61 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Wenner_S5_finer.csv](Data/01_COMSOL_Raw/mesh/Z_Wenner_S5_finer.csv) | Wenner, S5: mesh comparison at finer mesh. Historical spectrum; not regenerated from the revised MPH set. | 61 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Wenner_S5_xfine.csv](Data/01_COMSOL_Raw/mesh/Z_Wenner_S5_xfine.csv) | Wenner, S5: mesh comparison at extra-fine mesh. Historical spectrum; not regenerated from the revised MPH set. | 61 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |

### Data/01_COMSOL_Raw/sens

| File | Purpose and use | Rows / columns |
|---|---|---|
| [Z_Wenner_S2_base.csv](Data/01_COMSOL_Raw/sens/Z_Wenner_S2_base.csv) | Wenner, S2: baseline conductivity. Historical spectrum; not regenerated from the revised MPH set. | 251 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Wenner_S2_cort_m20.csv](Data/01_COMSOL_Raw/sens/Z_Wenner_S2_cort_m20.csv) | Wenner, S2: cortical bone conductivity decreased by 20%. Historical spectrum; not regenerated from the revised MPH set. | 251 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Wenner_S2_cort_p20.csv](Data/01_COMSOL_Raw/sens/Z_Wenner_S2_cort_p20.csv) | Wenner, S2: cortical bone conductivity increased by 20%. Historical spectrum; not regenerated from the revised MPH set. | 251 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Wenner_S2_fat_m20.csv](Data/01_COMSOL_Raw/sens/Z_Wenner_S2_fat_m20.csv) | Wenner, S2: fat conductivity decreased by 20%. Historical spectrum; not regenerated from the revised MPH set. | 251 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Wenner_S2_fat_p20.csv](Data/01_COMSOL_Raw/sens/Z_Wenner_S2_fat_p20.csv) | Wenner, S2: fat conductivity increased by 20%. Historical spectrum; not regenerated from the revised MPH set. | 251 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Wenner_S2_frac_m20.csv](Data/01_COMSOL_Raw/sens/Z_Wenner_S2_frac_m20.csv) | Wenner, S2: fracture region conductivity decreased by 20%. Historical spectrum; not regenerated from the revised MPH set. | 251 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Wenner_S2_frac_p20.csv](Data/01_COMSOL_Raw/sens/Z_Wenner_S2_frac_p20.csv) | Wenner, S2: fracture region conductivity increased by 20%. Historical spectrum; not regenerated from the revised MPH set. | 251 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Wenner_S2_marr_m20.csv](Data/01_COMSOL_Raw/sens/Z_Wenner_S2_marr_m20.csv) | Wenner, S2: marrow conductivity decreased by 20%. Historical spectrum; not regenerated from the revised MPH set. | 251 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Wenner_S2_marr_p20.csv](Data/01_COMSOL_Raw/sens/Z_Wenner_S2_marr_p20.csv) | Wenner, S2: marrow conductivity increased by 20%. Historical spectrum; not regenerated from the revised MPH set. | 251 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Wenner_S2_musc_m20.csv](Data/01_COMSOL_Raw/sens/Z_Wenner_S2_musc_m20.csv) | Wenner, S2: muscle conductivity decreased by 20%. Historical spectrum; not regenerated from the revised MPH set. | 251 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Wenner_S2_musc_p20.csv](Data/01_COMSOL_Raw/sens/Z_Wenner_S2_musc_p20.csv) | Wenner, S2: muscle conductivity increased by 20%. Historical spectrum; not regenerated from the revised MPH set. | 251 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Wenner_S2_skin_m20.csv](Data/01_COMSOL_Raw/sens/Z_Wenner_S2_skin_m20.csv) | Wenner, S2: skin conductivity decreased by 20%. Historical spectrum; not regenerated from the revised MPH set. | 251 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |
| [Z_Wenner_S2_skin_p20.csv](Data/01_COMSOL_Raw/sens/Z_Wenner_S2_skin_p20.csv) | Wenner, S2: skin conductivity increased by 20%. Historical spectrum; not regenerated from the revised MPH set. | 251 rows; `freq_Hz`, `ReZ_Ohm`, `ImZ_Ohm` |

### Data/02_Paper_Tables/Results_tables

| File | Purpose and use | Rows / columns |
|---|---|---|
| [mesh_convergence.csv](Data/02_Paper_Tables/Results_tables/mesh_convergence.csv) | Mesh-level comparison of intact/fractured impedance, element counts and contrast at selected frequencies. | 21 rows; `freq`, `mesh`, `n_elem_normal`, `n_elem_fracture`, `absZ_Normal`, `absZ_Fracture`, `ReZ_Normal`, `ReZ_Fracture`, `d_absZ`, `d_ReZ`, `d_absZ_N_pct_vs_prev`, `d_absZ_F_pct_vs_prev`, `d_absZ_N_pct_vs_xfine`, `contrast_absZ`, `contrast_ReZ` |
| [NQ_confound_index.csv](Data/02_Paper_Tables/Results_tables/NQ_confound_index.csv) | Comparison of healing descriptor changes with skin, cortical and depth effects; includes the maximum confounding ratio. | 11 rows; `descriptor`, `healing_pct`, `skin`, `cortical`, `depth`, `max_confound_ratio` |
| [NQ_robust_anatomy.csv](Data/02_Paper_Tables/Results_tables/NQ_robust_anatomy.csv) | Anatomical-variant fitted descriptors and S0/S4 contrast, with numerical-floor and robustness indicators. | 12 rows; `variant`, `label`, `group`, `absZ_S0_1Hz`, `dabsZ_1Hz_pct`, `R2_S0`, `R2_S4`, `dR2_pct`, `dR2_pct_err`, `dR2_over_floor`, `verdict`, `n_S0`, `n_S4`, `rel_S0`, `rel_S4` |
| [NQ_sens_matrix.csv](Data/02_Paper_Tables/Results_tables/NQ_sens_matrix.csv) | Tissue-by-parameter sensitivity matrix, central/one-sided estimates, nonlinearity and resolution flags. | 36 rows; `layer`, `param`, `S_central`, `S_forward`, `S_backward`, `nonlinearity_pct`, `dparam_plus_pct`, `dparam_minus_pct`, `above_repro_floor`, `monotone_in_sign`, `resolved` |
| [NQ_sens_params.csv](Data/02_Paper_Tables/Results_tables/NQ_sens_params.csv) | Equivalent-circuit parameters and fit diagnostics for the baseline and conductivity perturbation cases. | 13 rows; `case`, `rel_rmse_pct`, `R2_weighted`, `cond_J`, `Rs`, `R1`, `C`, `R2`, `Q`, `n` |
| [NQ_svd.csv](Data/02_Paper_Tables/Results_tables/NQ_svd.csv) | Singular values and left/right vectors for the tissue sensitivity matrix. | 6 rows; `index`, `singular_value`, `v_Skin`, `v_Fat`, `v_Muscle`, `v_Cortical bone`, `v_Marrow`, `v_Fracture gap`, `u_Rs`, `u_R1`, `u_C`, `u_R2`, `u_Q`, `u_n` |
| [NQ_tolerance.csv](Data/02_Paper_Tables/Results_tables/NQ_tolerance.csv) | Anatomical tolerance estimates from descriptor slopes and the healing-signal magnitude. | 30 rows; `axis`, `descriptor`, `dln_per_mm`, `healing_signal_pct`, `tolerance_mm` |
| [sensitivity_cutline_profiles.csv](Data/02_Paper_Tables/Results_tables/sensitivity_cutline_profiles.csv) | Sensitivity samples along cutlines for each array and model state, including normalized position. | 738 rows; `config`, `state`, `x`, `sensitivity`, `x_norm` |
| [sensitivity_cutline_stats.csv](Data/02_Paper_Tables/Results_tables/sensitivity_cutline_stats.csv) | Cutline summaries: extrema, surface/depth values, cumulative-depth indicators and integrated absolute sensitivity. | 18 rows; `config`, `state`, `n_points`, `x_min`, `x_max`, `S_at_surface`, `S_max`, `S_median`, `x50_mm`, `x90_mm`, `S_at_25pct`, `S_at_50pct`, `S_at_75pct`, `total_abs` |
| [volume_criterion_by_L.csv](Data/02_Paper_Tables/Results_tables/volume_criterion_by_L.csv) | Volume/electrode criteria aggregated by array length across configurations. | 140 rows; `config`, `L_mm`, `n_geometries`, `S_zstar_N`, `S_frac_signed_N`, `S_frac_abs_N`, `S_frac_signed_F`, `abs_dZ`, `rel_dZ_pct` |
| [volume_criterion_optimum.csv](Data/02_Paper_Tables/Results_tables/volume_criterion_optimum.csv) | Optimum length, criterion maximum, manuscript-length value and 90-percent plateau bounds for each criterion/configuration. | 18 rows; `config`, `criterion`, `description`, `L_opt_mm`, `max_value`, `L_paper_mm`, `value_at_L_paper`, `value_at_L_paper_pct_of_max`, `min_value`, `plateau90_Lmin_mm`, `plateau90_Lmax_mm` |

### Data/02_Paper_Tables/VersionB/contact251

| File | Purpose and use | Rows / columns |
|---|---|---|
| [B_contact_mc_251.csv](Data/02_Paper_Tables/VersionB/contact251/B_contact_mc_251.csv) | Cross-validated AUC by noise level, contact scenario and state pair for the 251-point contact analysis. | 40 rows; `eta_pct`, `scenario`, `pair`, `AUC_cv` |
| [contact_table_251.csv](Data/02_Paper_Tables/VersionB/contact251/contact_table_251.csv) | Contact-induced fitted-descriptor shifts and impedance changes at five sampled frequencies. These samples alone do not give the exact maximum over the entire low-frequency band. | 18 rows; `config`, `case`, `state`, `R2_ideal`, `R2_case`, `dR2_Ohm`, `alpha2_ideal`, `alpha2_case`, `dalpha2`, `R2_ideal_batch`, `alpha2_ideal_batch`, `Rs_case`, `R2w_case`, `dZtr_rel_pct_1Hz`, `dZtr_rel_pct_10Hz`, `dZtr_rel_pct_100Hz`, `dZtr_rel_pct_1000Hz`, `dZtr_rel_pct_100000Hz` |
| [cpe_test_251.csv](Data/02_Paper_Tables/VersionB/contact251/cpe_test_251.csv) | Comparison of ideal-contact fits and 10 kOhm contact fits with/without a contact constant-phase element. | 6 rows; `state`, `R2_ideal`, `R2_m3_10k`, `err_m3_pct`, `R2_m3cpe_10k`, `err_m3cpe_pct`, `Qc`, `alpha_c` |

### Data/02_Paper_Tables/VersionB/depth251/d11

| File | Purpose and use | Rows / columns |
|---|---|---|
| [A1_auc_Wenner.csv](Data/02_Paper_Tables/VersionB/depth251/d11/A1_auc_Wenner.csv) | Wenner state-pair AUC versus noise for this depth: cross-validated, in-sample and Gaussian estimates with bootstrap limits. | 32 rows; `pair`, `eta`, `AUC_cv`, `AUC_insample`, `AUC_gauss`, `Delta_mahalanobis`, `AUC_cv_boot_p2_5`, `AUC_cv_boot_p97_5`, `n_boot` |

### Data/02_Paper_Tables/VersionB/depth251/d13

| File | Purpose and use | Rows / columns |
|---|---|---|
| [A1_auc_Wenner.csv](Data/02_Paper_Tables/VersionB/depth251/d13/A1_auc_Wenner.csv) | Wenner state-pair AUC versus noise for this depth: cross-validated, in-sample and Gaussian estimates with bootstrap limits. | 32 rows; `pair`, `eta`, `AUC_cv`, `AUC_insample`, `AUC_gauss`, `Delta_mahalanobis`, `AUC_cv_boot_p2_5`, `AUC_cv_boot_p97_5`, `n_boot` |

### Data/02_Paper_Tables/VersionB/depth251/d15

| File | Purpose and use | Rows / columns |
|---|---|---|
| [A1_auc_Wenner.csv](Data/02_Paper_Tables/VersionB/depth251/d15/A1_auc_Wenner.csv) | Wenner state-pair AUC versus noise for this depth: cross-validated, in-sample and Gaussian estimates with bootstrap limits. | 32 rows; `pair`, `eta`, `AUC_cv`, `AUC_insample`, `AUC_gauss`, `Delta_mahalanobis`, `AUC_cv_boot_p2_5`, `AUC_cv_boot_p97_5`, `n_boot` |

### Data/02_Paper_Tables/VersionB/depth251/d17

| File | Purpose and use | Rows / columns |
|---|---|---|
| [A1_auc_Wenner.csv](Data/02_Paper_Tables/VersionB/depth251/d17/A1_auc_Wenner.csv) | Wenner state-pair AUC versus noise for this depth: cross-validated, in-sample and Gaussian estimates with bootstrap limits. | 32 rows; `pair`, `eta`, `AUC_cv`, `AUC_insample`, `AUC_gauss`, `Delta_mahalanobis`, `AUC_cv_boot_p2_5`, `AUC_cv_boot_p97_5`, `n_boot` |

### Data/02_Paper_Tables/VersionB/depth251/d19

| File | Purpose and use | Rows / columns |
|---|---|---|
| [A1_auc_Wenner.csv](Data/02_Paper_Tables/VersionB/depth251/d19/A1_auc_Wenner.csv) | Wenner state-pair AUC versus noise for this depth: cross-validated, in-sample and Gaussian estimates with bootstrap limits. | 32 rows; `pair`, `eta`, `AUC_cv`, `AUC_insample`, `AUC_gauss`, `Delta_mahalanobis`, `AUC_cv_boot_p2_5`, `AUC_cv_boot_p97_5`, `n_boot` |

### Data/02_Paper_Tables/VersionB/depth251/d21

| File | Purpose and use | Rows / columns |
|---|---|---|
| [A1_auc_Wenner.csv](Data/02_Paper_Tables/VersionB/depth251/d21/A1_auc_Wenner.csv) | Wenner state-pair AUC versus noise for this depth: cross-validated, in-sample and Gaussian estimates with bootstrap limits. | 32 rows; `pair`, `eta`, `AUC_cv`, `AUC_insample`, `AUC_gauss`, `Delta_mahalanobis`, `AUC_cv_boot_p2_5`, `AUC_cv_boot_p97_5`, `n_boot` |

### Data/02_Paper_Tables/VersionB/depth251

| File | Purpose and use | Rows / columns |
|---|---|---|
| [depth_contrast.csv](Data/02_Paper_Tables/VersionB/depth251/depth_contrast.csv) | Depth-dependent R2 and alpha2 contrasts by state. | 30 rows; `depth`, `state`, `dR2`, `da2` |
| [depth_endpoint.csv](Data/02_Paper_Tables/VersionB/depth251/depth_endpoint.csv) | Depth-dependent endpoint contrasts, including the high-frequency impedance difference. | 6 rows; `depth`, `state`, `dR2`, `da2`, `dZ100k` |
| [depth_fits.csv](Data/02_Paper_Tables/VersionB/depth251/depth_fits.csv) | Equivalent-circuit descriptors, fit quality and endpoint impedance for each depth/state spectrum. | 30 rows; `depth`, `state`, `Rs`, `R1`, `R2`, `alpha2`, `f2`, `R2w`, `Zre1`, `Zre100k`, `npts` |
| [depth_sep.csv](Data/02_Paper_Tables/VersionB/depth251/depth_sep.csv) | Depth-by-state-pair AUC and allowable-noise thresholds, including stored numerical-adjustment columns. Preserve the analysis version when comparing with manuscript values. | 30 rows; `depth`, `pair`, `AUC05`, `AUC10`, `eta_max`, `eta_max_num`, `AUCn05`, `AUCn0`, `aucs`, `aucn` |

### Data/02_Paper_Tables/VersionB/mesh251

| File | Purpose and use | Rows / columns |
|---|---|---|
| [jitter_contrast_sd.csv](Data/02_Paper_Tables/VersionB/mesh251/jitter_contrast_sd.csv) | Standard deviation of pairwise R2/alpha2 contrasts under jitter, separated by frequency grid. | 12 rows; `grid`, `pair`, `sd_dR2`, `sd_da2` |
| [jitter_sigma.csv](Data/02_Paper_Tables/VersionB/mesh251/jitter_sigma.csv) | State-wise real/imaginary impedance jitter estimates and relative scale. | 18 rows; `state`, `data`, `n`, `sig_re`, `sig_im`, `absZ1`, `rel_re_pct` |
| [mesh_correction_pointwise.csv](Data/02_Paper_Tables/VersionB/mesh251/mesh_correction_pointwise.csv) | Pointwise mesh-induced impedance differences, maximum/RMS measures and relative differences at selected frequencies. | 12 rows; `fam`, `state`, `dZ_mesh_max`, `dZ_mesh_rms`, `absZ1`, `rel_1Hz_pct`, `rel_1kHz_pct`, `rel_100kHz_pct` |
| [robust_dnum.csv](Data/02_Paper_Tables/VersionB/mesh251/robust_dnum.csv) | Comparison of numerical-uncertainty assumptions from 61-point, 251-point and repeatability-adjusted analyses, including AUC. | 6 rows; `pair`, `dnum61`, `dnum61_AUC05`, `dnum251`, `dnum251_AUC05`, `dnum61+rep`, `dnum61+rep_AUC05` |
| [RV_mesh_contrast_251.csv](Data/02_Paper_Tables/VersionB/mesh251/RV_mesh_contrast_251.csv) | Finer versus extra-fine pairwise descriptor/impedance contrasts and numerical-error measures on the 251-point analysis. | 14 rows; `family`, `pair`, `dR2_finer`, `dR2_xfine`, `dnum_R2`, `rel_R2_pct`, `da2_finer`, `da2_xfine`, `dnum_a2`, `rel_a2_pct`, `dZ1_finer`, `dZ1_xfine`, `dnum_Z1` |
| [RV_mesh_fits_251.csv](Data/02_Paper_Tables/VersionB/mesh251/RV_mesh_fits_251.csv) | Finer/extra-fine R2, alpha2, low-frequency impedance and fit-quality values by family/state. | 12 rows; `family`, `state`, `R2_F`, `a2_F`, `R2_X`, `a2_X`, `Z1_F`, `Z1_X`, `R2w_F`, `R2w_X` |
| [sep_num_251.csv](Data/02_Paper_Tables/VersionB/mesh251/sep_num_251.csv) | Final 251-point mesh-adjusted state-pair AUC and allowable-noise threshold summary. Prefer this over earlier numerical-uncertainty columns in B_cov/B_thresholds. | 5 rows; `pair`, `AUCn05`, `AUCn10`, `eta_max_num`, `AUCn0`, `aucn` |
| [T1_pointwise.csv](Data/02_Paper_Tables/VersionB/mesh251/T1_pointwise.csv) | Pointwise mesh and batch maximum/RMS impedance differences by family/state. | 12 rows; `fam`, `state`, `mesh_max`, `mesh_rms`, `batch_max`, `batch_rms`, `absZ1` |
| [T2T3_contrasts.csv](Data/02_Paper_Tables/VersionB/mesh251/T2T3_contrasts.csv) | Descriptor contrasts decomposed into mesh and frequency-grid effects for the 61/251-point analyses. | 14 rows; `fam`, `pair`, `dR2_f61`, `dR2_x61`, `dnum61_R2`, `dR2_p251`, `dR2_p61`, `grid_R2`, `dR2_x251`, `dnum251_R2`, `da2_p251`, `dnum61_a2`, `grid_a2`, `dnum251_a2` |
| [T4_loo.csv](Data/02_Paper_Tables/VersionB/mesh251/T4_loo.csv) | Leave-one-out maximum deviations compared with maximum mesh deviations by family/state. | 12 rows; `fam`, `state`, `loo_max`, `dmesh_max` |

### Data/02_Paper_Tables/VersionB/new_tables

| File | Purpose and use | Rows / columns |
|---|---|---|
| [B_band.csv](Data/02_Paper_Tables/VersionB/new_tables/B_band.csv) | Equivalent-circuit fits using different frequency bands; includes fit quality and relative RMSE. | 45 rows; `family`, `state`, `band`, `Rs`, `R1`, `C1`, `R2`, `Q2`, `alpha2`, `f2`, `R2w`, `rel_rmse_pct`, `n` |
| [B_cov.csv](Data/02_Paper_Tables/VersionB/new_tables/B_cov.csv) | Noise-dependent state-pair descriptor covariance, Mahalanobis separation and AUC. AUC_G_num is an earlier numerical-adjustment result; see sep_num_251.csv for the final summary. | 10 rows; `pair`, `eta_pct`, `dR2`, `dalpha2`, `sig_R2`, `sig_a2`, `rho`, `Delta`, `AUC_G`, `AUC_cv`, `AUC_G_num` |
| [B_fits.csv](Data/02_Paper_Tables/VersionB/new_tables/B_fits.csv) | Equivalent-circuit fits for each family/state/survey variant, including alternative circuit models and fit metrics. Filter variant=main for the main state-fit table. | 63 rows; `family`, `state`, `variant`, `Rs`, `R1`, `C1`, `R2`, `Q2`, `alpha2`, `f1`, `f2`, `R2w3`, `AIC3`, `Rs2`, `R1_2`, `C1_2`, `R2_2`, `C2_2`, `R2w2`, `AIC2`, `Rs1`, `R1_1`, `C1_1`, `R2w1`, `AIC1`, `Zre1`, `Zre100k`, `fpk`, `negIm_pk`, `npts` |
| [B_thresholds.csv](Data/02_Paper_Tables/VersionB/new_tables/B_thresholds.csv) | Allowable-noise thresholds and bootstrap information for adjacent states. Numerical-adjustment columns belong to an earlier analysis; see sep_num_251.csv. | 5 rows; `pair`, `eta_max`, `status`, `boot`, `eta_max_num`, `status_num`, `aucn0`, `aucn` |

### Data/03_Electrode_1kHz/A4

| File | Purpose and use | Rows / columns |
|---|---|---|
| [A4_criteria_Dipole.csv](Data/03_Electrode_1kHz/A4/A4_criteria_Dipole.csv) | Dipole: electrode criteria aggregated by array length. Derived criteria/optima are supplied outputs; their post-processing code is not included. | 50 rows; `L_mm`, `n_geometries`, `S_zstar_N`, `S_frac_signed_N`, `S_frac_abs_N`, `S_frac_signed_F`, `abs_dZ`, `rel_dZ_pct` |
| [A4_criteria_Schlumberger.csv](Data/03_Electrode_1kHz/A4/A4_criteria_Schlumberger.csv) | Schlumberger: electrode criteria aggregated by array length. Derived criteria/optima are supplied outputs; their post-processing code is not included. | 53 rows; `L_mm`, `n_geometries`, `S_zstar_N`, `S_frac_signed_N`, `S_frac_abs_N`, `S_frac_signed_F`, `abs_dZ`, `rel_dZ_pct` |
| [A4_criteria_Wenner.csv](Data/03_Electrode_1kHz/A4/A4_criteria_Wenner.csv) | Wenner: electrode criteria aggregated by array length. Derived criteria/optima are supplied outputs; their post-processing code is not included. | 37 rows; `L_mm`, `n_geometries`, `S_zstar_N`, `S_frac_signed_N`, `S_frac_abs_N`, `S_frac_signed_F`, `abs_dZ`, `rel_dZ_pct` |
| [A4_Lopt_Dipole.csv](Data/03_Electrode_1kHz/A4/A4_Lopt_Dipole.csv) | Dipole: optimum array length and 90-percent plateau for each criterion. Derived criteria/optima are supplied outputs; their post-processing code is not included. | 6 rows; `criterion`, `description`, `L_opt_mm`, `max_value`, `L_selected_paper_mm`, `value_at_selected_pct_of_max`, `plateau90_Lmin_mm`, `plateau90_Lmax_mm` |
| [A4_Lopt_Schlumberger.csv](Data/03_Electrode_1kHz/A4/A4_Lopt_Schlumberger.csv) | Schlumberger: optimum array length and 90-percent plateau for each criterion. Derived criteria/optima are supplied outputs; their post-processing code is not included. | 6 rows; `criterion`, `description`, `L_opt_mm`, `max_value`, `L_selected_paper_mm`, `value_at_selected_pct_of_max`, `plateau90_Lmin_mm`, `plateau90_Lmax_mm` |
| [A4_Lopt_Wenner.csv](Data/03_Electrode_1kHz/A4/A4_Lopt_Wenner.csv) | Wenner: optimum array length and 90-percent plateau for each criterion. Derived criteria/optima are supplied outputs; their post-processing code is not included. | 6 rows; `criterion`, `description`, `L_opt_mm`, `max_value`, `L_selected_paper_mm`, `value_at_selected_pct_of_max`, `plateau90_Lmin_mm`, `plateau90_Lmax_mm` |
| [A4_sweep_Dipole.csv](Data/03_Electrode_1kHz/A4/A4_sweep_Dipole.csv) | Dipole: historical 1 kHz per-geometry intact/fractured sensitivities and complex impedance, with solve time. Derived criteria/optima are supplied outputs; their post-processing code is not included. | 75 rows; `family`, `Re_mm`, `n`, `a_mm`, `freq_Hz`, `S_zstar_N`, `S_frac_signed_N`, `S_frac_abs_N`, `S_zstar_F`, `S_frac_signed_F`, `S_frac_abs_F`, `ReZ_N`, `ImZ_N`, `ReZ_F`, `ImZ_F`, `solve_s` |
| [A4_sweep_Schlumberger.csv](Data/03_Electrode_1kHz/A4/A4_sweep_Schlumberger.csv) | Schlumberger: historical 1 kHz per-geometry intact/fractured sensitivities and complex impedance, with solve time. Derived criteria/optima are supplied outputs; their post-processing code is not included. | 60 rows; `family`, `Re_mm`, `n`, `a_mm`, `freq_Hz`, `S_zstar_N`, `S_frac_signed_N`, `S_frac_abs_N`, `S_zstar_F`, `S_frac_signed_F`, `S_frac_abs_F`, `ReZ_N`, `ImZ_N`, `ReZ_F`, `ImZ_F`, `solve_s` |
| [A4_sweep_Wenner.csv](Data/03_Electrode_1kHz/A4/A4_sweep_Wenner.csv) | Wenner: historical 1 kHz per-geometry intact/fractured sensitivities and complex impedance, with solve time. Derived criteria/optima are supplied outputs; their post-processing code is not included. | 60 rows; `family`, `Re_mm`, `n`, `a_mm`, `freq_Hz`, `S_zstar_N`, `S_frac_signed_N`, `S_frac_abs_N`, `S_zstar_F`, `S_frac_signed_F`, `S_frac_abs_F`, `ReZ_N`, `ImZ_N`, `ReZ_F`, `ImZ_F`, `solve_s` |
