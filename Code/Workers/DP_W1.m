addpath('V:\Journal\Sensor\Code\COMSOL');
addpath('V:\Journal\Sensor\Code\Common\matlab');
cfg = 'V:\Journal\Sensor\Code\COMSOL\config_newrun.json';
fprintf('==== DP_W1: 251-point depth batch (S0-S4 x 13/15/17/19/21 mm), port 2046  %s ====\n', datestr(now));
V = BFH_run_anat('--list');
fprintf('[check] case 4=%s 5=%s 21=%s 22=%s 23=%s\n', V{4}, V{5}, V{21}, V{22}, V{23});
assert(strcmp(V{21},'depth17') && strcmp(V{22},'depth19') && strcmp(V{23},'depth21') && strcmp(V{4},'depth13') && strcmp(V{5},'depth15'), 'incorrect variant indices');
fprintf('\n---- SMOKE 3 frequencies  %s ----\n', datestr(now));
try
    BFH_run_anat(cfg, 'Wenner', 2046, 21, '1 1000 100000', '_SMOKE', {'S0'});
catch ME
    fprintf(2,'ERROR SMOKE: %s (%s)\n', ME.message, ME.identifier);
end
smokeOK = isfile(sprintf('V:\\Journal\\Sensor\\Data\\Runs\\anat\\Z_Wenner_%s_S0_SMOKE.csv', V{21}));
if ~smokeOK
    fprintf(2,'SMOKE TEST FAILED - full run skipped.\n');
else
    fprintf('\n---- ANAT case 21 x states  %s ----\n', datestr(now));
    try
        BFH_run_anat(cfg, 'Wenner', 2046, 21, '', '', {'S0','S1','S2','S3','S4'});
    catch ME
        fprintf(2,'ERROR case 21: %s (%s)\n', ME.message, ME.identifier);
        for kk=1:numel(ME.stack), fprintf(2,'    at %s line %d\n', ME.stack(kk).name, ME.stack(kk).line); end
    end
    fprintf('\n---- ANAT case 4 x states  %s ----\n', datestr(now));
    try
        BFH_run_anat(cfg, 'Wenner', 2046, 4, '', '', {'S1','S2'});
    catch ME
        fprintf(2,'ERROR case 4: %s (%s)\n', ME.message, ME.identifier);
        for kk=1:numel(ME.stack), fprintf(2,'    at %s line %d\n', ME.stack(kk).name, ME.stack(kk).line); end
    end
end
fprintf('==== DONE DP_W1 %s ====\n', datestr(now));
