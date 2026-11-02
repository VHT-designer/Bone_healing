function bfh_c_mapping_check(port)
if nargin < 1 || isempty(port), port = 2045; end
import com.comsol.model.util.*
here    = fileparts(mfilename('fullpath'));
common  = fileparts(here);
outDir  = 'V:\Journal\Sensor\Data\Runs\c_mapping_check';
if ~exist(outDir, 'dir'), mkdir(outDir); end
mphPath = 'V:\Journal\Sensor\Data\04_Models\Wenner\Wenner_Cole\LEG3D_Fracture_Wenner_Cole.mph';
statesT = bfh_read_states_table(fullfile(common, 'data', 'states_table_S0S5.csv'));
plist   = '10 1000 100000';
fsolve  = [10 1000 100000];
cases = { ...
    'S0_c0',   'S0', 0.00; ...
    'S1_c025', 'S1', 0.25; ...
    'S1_c05',  'S1', 0.50; ...
    'S2_c05',  'S2', 0.50; ...
    'S2_c10',  'S2', 1.00};
assert(bfh_preflight_seat('1718@RYOTRAN'), 'no free ACDC seat');
bfh_connect('C:\Program Files\COMSOL\COMSOL62\Multiphysics_copy1\mli', port);
model = mphload(mphPath, 'cmap');
cleanup = onCleanup(@() ModelUtil.remove('cmap'));
pg = model.component('comp1').material('mat6').propertyGroup('def');
pg.set('electricconductivity', 'Mix_sigma');
pg.set('relpermittivity', 'Mix_epsilonr');
fprintf('[cmap] mat6 -> Mix_sigma / Mix_epsilonr\n');
for k = 1:size(cases, 1)
    nm = cases{k,1}; st = cases{k,2}; cval = cases{k,3};
    csvPath = fullfile(outDir, sprintf('Zcheck_%s.csv', nm));
    if exist(csvPath, 'file'), fprintf('[cmap] skip (exists) %s\n', nm); continue; end
    row = statesT(strcmp(statesT.state, st), :);
    model.param.set('c', sprintf('%.10g', cval));
    model.param.set('Mix_sigma', char(row.Mix_sigma_expr));
    model.param.set('Mix_epsilonr', char(row.Mix_epsilonr_expr));
    bfh_set_freq_list(model, 'std1', plist, 'freq');
    fprintf('[cmap] === %s : state %s, c=%.2f, w=%.2f === solving...\n', nm, st, cval, row.w_blood);
    ts = tic; model.study('std1').run(); solveSec = toc(ts);
    nel = NaN; try, s = mphmeshstats(model, 'mesh1'); nel = sum(s.numelem); catch, end
    meta = struct('purpose', 'c-mapping hypothesis check', 'state', st, 'c', sprintf('%.4g', cval), ...
        'w_blood', sprintf('%.4g', row.w_blood), 'source_mph', mphPath, 'plist', plist, ...
        'n_elements', sprintf('%d', nel), 'solve_seconds', sprintf('%d', round(solveSec)), ...
        'material_override', 'mat6 def -> Mix_sigma/Mix_epsilonr');
    bfh_export_Z(model, '(bnd2-bnd3)/I', csvPath, meta);
    fprintf('[cmap] %s solved in %.1f min (%d elements)\n', nm, solveSec/60, nel);
end
fprintf('\n[cmap] ===== comparison vs submitted spectra =====\n');
fid = fopen(fullfile(outDir, 'c_mapping_verdict.txt'), 'w');
lines = {sprintf('case, freq_Hz, |Z|_fem, |Z|_submitted, dev_pct')};
for k = 1:size(cases, 1)
    nm = cases{k,1}; st = cases{k,2};
    csvPath = fullfile(outDir, sprintf('Zcheck_%s.csv', nm));
    if ~exist(csvPath, 'file'), continue; end
    A = readtable(csvPath);
    Sref = readtable(fullfile('V:\Journal\Sensor\Q1_Access\IEEE Access Bone 2\IEEE Access Bone 2\R2_COMPUTE_PACKAGES\00_COMMON\data', sprintf('Z_Wenner_%s.csv', st)));
    zr = sqrt(Sref.ReZ_Ohm.^2 + Sref.ImZ_Ohm.^2);
    for q = 1:numel(fsolve)
        zref = interp1(log10(Sref.freq_Hz), zr, log10(fsolve(q)));
        [~, iq] = min(abs(A.freq_Hz - fsolve(q)));
        zfem = hypot(A.ReZ_Ohm(iq), A.ImZ_Ohm(iq));
        lines{end+1} = sprintf('%s, %g, %.4f, %.4f, %+.3f', nm, fsolve(q), zfem, zref, 100*(zfem-zref)/zref);
    end
end
fprintf('%s\n', lines{:});
fprintf(fid, '%s\n', lines{:});
fclose(fid);
fprintf('[cmap] verdict written to %s\n', fullfile(outDir, 'c_mapping_verdict.txt'));
end
