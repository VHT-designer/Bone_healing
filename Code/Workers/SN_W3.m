addpath('V:\Journal\Sensor\Code\COMSOL');
addpath('V:\Journal\Sensor\Code\Common\matlab');
fprintf('==== SN_W3: full 251-point grid, case 10-13 %s ====\n', datestr(now));
try
    BFH_run_sens('V:\Journal\Sensor\Code\COMSOL\config_newrun.json', 'Wenner', 2048, [10 11 12 13], 'S2', '');
catch ME
    fprintf(2,'ERROR: %s (%s)\n', ME.message, ME.identifier);
    for kk=1:numel(ME.stack), fprintf(2,'    at %s line %d\n', ME.stack(kk).name, ME.stack(kk).line); end
end
fprintf('==== DONE %s ====\n', datestr(now));
