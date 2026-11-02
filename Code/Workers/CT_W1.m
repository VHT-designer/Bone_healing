addpath('V:\Journal\Sensor\Code\COMSOL');
addpath('V:\Journal\Sensor\Code\Common\matlab');
cfg = 'V:\Journal\Sensor\Code\COMSOL\config_newrun.json';
fprintf('==== CT_W1: 251-point contact batch, Wenner 2 states x 4 arms, port 2046  %s ====\n', datestr(now));
try
    BFH_run_contact(cfg, 'Wenner', 2046, {'S0','S1'}, {'ideal','const1k','const10k','zc_inf'}, '', '');
catch ME
    fprintf(2,'ERROR: %s (%s)\n', ME.message, ME.identifier);
    for kk=1:numel(ME.stack), fprintf(2,'    at %s line %d\n', ME.stack(kk).name, ME.stack(kk).line); end
end
fprintf('==== DONE CT_W1 %s ====\n', datestr(now));
