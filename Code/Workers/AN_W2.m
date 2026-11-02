addpath('V:\Journal\Sensor\Code\COMSOL');
addpath('V:\Journal\Sensor\Code\Common\matlab');
fprintf('==== ANAT W2 (bone depth 15 mm + skin thicknesses 1,3,4 mm) %s ====\n', datestr(now));
try
    BFH_run_anat('V:\Journal\Sensor\Code\COMSOL\config_newrun.json', 'Wenner', 2047, [5 6 7 8]);
catch ME
    fprintf(2,'ERROR: %s (%s)\n', ME.message, ME.identifier);
    for kk=1:numel(ME.stack), fprintf(2,'    at %s line %d\n', ME.stack(kk).name, ME.stack(kk).line); end
end
fprintf('==== DONE %s ====\n', datestr(now));
