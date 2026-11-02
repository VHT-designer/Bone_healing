addpath('V:\Journal\Sensor\Code\COMSOL');
addpath('V:\Journal\Sensor\Code\Common\matlab');
cfg = 'V:\Journal\Sensor\Code\COMSOL\config_newrun.json';
fprintf('==== CT_W2: 251-point contact batch, Wenner 2 states x 4 arms, port 2047  %s ====\n', datestr(now));
try
    BFH_run_contact(cfg, 'Wenner', 2047, {'S2','S3'}, {'ideal','const1k','const10k','zc_inf'}, '', '');
catch ME
    fprintf(2,'ERROR: %s (%s)\n', ME.message, ME.identifier);
    for kk=1:numel(ME.stack), fprintf(2,'    at %s line %d\n', ME.stack(kk).name, ME.stack(kk).line); end
end
fprintf('==== DONE CT_W2 %s ====\n', datestr(now));
