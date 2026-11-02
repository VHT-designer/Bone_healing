addpath('V:\Journal\Sensor\Code\COMSOL');
addpath('V:\Journal\Sensor\Code\Common\matlab');
fprintf('==== LICHTENECKER Schlumberger %s ====\n', datestr(now));
base = jsondecode(fileread('V:\Journal\Sensor\Code\COMSOL\config_newrun.json'));
base.comsol.server_port = 2047;
c = base; c.states = {'S0';'S1';'S2';'S3';'S4'};
tmp = [tempname('V:/Journal/Sensor/Data/Runs/configs') '.json']; fid = fopen(tmp,'w'); fwrite(fid, jsonencode(c)); fclose(fid);
try
    BFH_run_newdata(tmp, 'cole', {'Schlumberger'}, 'both_log', 'none');
catch ME
    fprintf(2,'ERROR: %s (%s)\n', ME.message, ME.identifier);
    for kk=1:numel(ME.stack), fprintf(2,'    at %s line %d\n', ME.stack(kk).name, ME.stack(kk).line); end
end
fprintf('==== DONE %s ====\n', datestr(now));
