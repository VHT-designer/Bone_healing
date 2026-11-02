function S = sensor_setup(port)
here = fileparts(mfilename('fullpath'));
addpath(fullfile(here,'COMSOL'));
addpath(fullfile(here,'Common','matlab'));
addpath(fullfile(here,'A4_Electrode_Sweep'));
S = BFH_paths();
if nargin < 1 || isempty(port), port = S.cfg.comsol.server_port; end
bfh_connect(S.cfg.comsol.mli_path,port);
fprintf('Sensor root: %s\nNew results: %s\n',S.projectDir,S.dataDir);
end
