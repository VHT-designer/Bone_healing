addpath('V:\Journal\Sensor\Code\COMSOL');
c = jsondecode(fileread('V:\Journal\Sensor\Code\COMSOL\config_newrun.json'));
c.comsol.server_port = 2048;
c.states = {'S0'};
tmp = [tempname('V:/Journal/Sensor/Data/Runs/configs') '.json']; fid = fopen(tmp,'w'); fwrite(fid, jsonencode(c)); fclose(fid);
fprintf('\n##### RERUN both_linear at hauto=3 for Dipole (section 27) #####\n');
BFH_run_newdata(tmp, 'cole', {'Dipole'}, 'both_linear', 'none');
fprintf('\n##### DONE: Dipole #####\n');
