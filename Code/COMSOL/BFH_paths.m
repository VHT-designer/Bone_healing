function S = BFH_paths(cfgPath)
here = fileparts(mfilename('fullpath'));
if nargin < 1 || isempty(cfgPath), cfgPath = fullfile(here, 'config_newrun.json'); end
S.cfg = jsondecode(fileread(cfgPath));
S.here = here;
S.projectDir = fileparts(fileparts(here));
S.resultsDir = S.projectDir;
S.dataDir = fullfile(S.projectDir, 'Data', 'Runs');
if isfield(S.cfg,'data_dir') && ~isempty(S.cfg.data_dir), S.dataDir = char(S.cfg.data_dir); end
sfx = '';
if isfield(S.cfg,'out_dir_suffix'), sfx = char(S.cfg.out_dir_suffix); end
S.outSuffix = sfx;
S.outDir = fullfile(S.dataDir, ['comsol_new' sfx]);
S.discoveryDir = fullfile(S.outDir,'_discovery');
S.logDir = fullfile(S.outDir,'_logs');
S.helperDir = fullfile(S.projectDir,'Code','Common','matlab');
S.statesTable = fullfile(S.projectDir,'Code','Common','data','states_table_S0S5.csv');
assert(isfolder(S.helperDir),'Missing helper directory: %s',S.helperDir);
assert(isfile(S.statesTable),'Missing states table: %s',S.statesTable);
addpath(S.helperDir);
for d = {S.outDir,S.discoveryDir,S.logDir}
    if ~isfolder(d{1}), mkdir(d{1}); end
end
end
