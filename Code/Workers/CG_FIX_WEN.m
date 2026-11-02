addpath('V:\Journal\Sensor\Code\COMSOL');
c = jsondecode(fileread('V:\Journal\Sensor\Code\COMSOL\config_newrun.json'));
c.comsol.server_port = 2046;
c.states = {'S0';'S1';'S2';'S3';'S4'};
tmp = [tempname('V:/Journal/Sensor/Data/Runs/configs') '.json']; fid = fopen(tmp,'w'); fwrite(fid, jsonencode(c)); fclose(fid);
fprintf('\n##### RERUN both_linear at hauto=3 for Wenner (section 27) #####\n');
BFH_run_newdata(tmp, 'cole', {'Wenner'}, 'both_linear', 'none');
fprintf('\n##### DONE: Wenner #####\n');
