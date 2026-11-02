function test_sensor_paths()
root = 'V:\Journal\Sensor';
addpath(fullfile(root,'Code','COMSOL'));
addpath(fullfile(root,'Code','Common','matlab'));
addpath(fullfile(root,'Code','A4_Electrode_Sweep'));
testDir = fullfile(root,'Data','Tests','revised_models');
if ~isfolder(testDir), mkdir(testDir); end
results = struct();
files = dir(fullfile(root,'Code','**','*.m'));
messages = struct('file',{},'id',{},'line',{},'message',{});
for k=1:numel(files)
    p=fullfile(files(k).folder,files(k).name);
    msg=checkcode(p,'-id');
    for j=1:numel(msg)
        messages(end+1)=struct('file',p,'id',msg(j).id,'line',msg(j).line,'message',msg(j).message);
    end
end
results.analyzer=messages;
S=BFH_paths();
assert(strcmp(S.projectDir,root));
assert(strcmp(S.dataDir,fullfile(root,'Data','Runs','revised_models')));
assert(isfile(S.statesTable));
ST=bfh_read_states_table(S.statesTable);assert(height(ST)==6);
[~,f]=BFH_plist_from_cfg(S.cfg);assert(numel(f)==251 && f(1)==1 && abs(f(end)-1e5)<1e-6);
families=fieldnames(S.cfg.families);
for k=1:numel(families)
    F=S.cfg.families.(families{k});
    for field={'model_path','s5_model_path','depth_model_path'}
        assert(isfile(F.(field{1})),'Missing model: %s',F.(field{1}));
    end
end
A=bfh_read_config(fullfile(root,'Code','A4_Electrode_Sweep','config_A4.json'));
for k=1:numel(families)
    F=A.comsol.models_by_family.(families{k});assert(isfile(F.normal));assert(isfile(F.fracture));
end
assert(isfile(A.comsol.fracture_state_S0.states_table));
assert(startsWith(bfh_resolve_path(A,A.sweep_csv),fullfile(root,'Data','Runs','revised_models')));
variants=BFH_run_anat('--list');assert(strcmp(variants{21},'depth17'));
results.static_pass=true;results.matlab=version;results.checked_m_files=numel(files);
fid=fopen(fullfile(testDir,'matlab_test_results.json'),'w');fprintf(fid,'%s',jsonencode(results,PrettyPrint=true));fclose(fid);
fprintf('STATIC_PATH_TEST_PASS: %d MATLAB files; 15 model references checked.\n',numel(files));
c=S.cfg;c.data_dir=fullfile(testDir,['Smoke_' datestr(now,'yyyymmdd_HHMMSS')]);c.states={'S0'};
c.comsol.server_port=2055;c.comsol.seat_preflight=false;
cp=fullfile(testDir,'config_smoke.json');fid=fopen(cp,'w');fprintf(fid,'%s',jsonencode(c));fclose(fid);
BFH_run_newdata(cp,'smoke',{'Wenner'},'both_linear','none');
p=fullfile(c.data_dir,'comsol_new','Z_Wenner_S0_SMOKE.csv');
assert(isfile(p),'Smoke runner ended without the expected CSV; check solver log');
T=readtable(p);assert(height(T)==3);assert(all(isfinite(T{:,1:3}),'all'));assert(isfile([p '.meta.txt']));
results.smoke_pass=true;results.smoke_file=p;
fid=fopen(fullfile(testDir,'matlab_test_results.json'),'w');fprintf(fid,'%s',jsonencode(results,PrettyPrint=true));fclose(fid);
fprintf('COMSOL_SMOKE_PASS: 3 frequencies, exported CSV and metadata.\n');
end
