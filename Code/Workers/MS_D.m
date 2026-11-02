addpath('V:\Journal\Sensor\Code\COMSOL');
addpath('V:\Journal\Sensor\Code\Common\matlab');
cfg = 'V:\Journal\Sensor\Code\COMSOL\config_newrun.json';
fprintf('==== MS_D: contrast mesh convergence, Dipole, port 2047  %s ====\n', datestr(now));
try
    BFH_run_mesh(cfg, 'Dipole', 2047, {'S1'}, {'finer','xfine'}, '_SMOKE');
catch ME
    fprintf(2,'ERROR SMOKE: %s (%s)\n', ME.message, ME.identifier);
end
smokeOK = isfile('V:\Journal\Sensor\Data\Runs\revised_models\mesh\Z_Dipole_S1_finer_SMOKE.csv') && ...
          isfile('V:\Journal\Sensor\Data\Runs\revised_models\mesh\Z_Dipole_S1_xfine_SMOKE.csv');
if ~smokeOK
    fprintf(2,'SMOKE TEST FAILED - full run skipped.\n');
else
    try
        BFH_run_mesh(cfg, 'Dipole', 2047, {'S0','S3','S4','S5','S1','S2'}, {'finer','xfine'}, '');
    catch ME
        fprintf(2,'ERROR: %s (%s)\n', ME.message, ME.identifier);
        for kk=1:numel(ME.stack), fprintf(2,'    at %s line %d\n', ME.stack(kk).name, ME.stack(kk).line); end
    end
end
fprintf('==== DONE MS_D %s ====\n', datestr(now));
