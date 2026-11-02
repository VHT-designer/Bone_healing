function BFH_run_mesh(cfgPath, family, port, states, levels, tagSfx)
if nargin < 1 || isempty(cfgPath), cfgPath = ''; end
if nargin < 2 || isempty(family),  family = 'Wenner'; end
if nargin < 3 || isempty(port),    port = 2046; end
if nargin < 4 || isempty(states),  states = {'S0','S1','S2','S3','S4','S5'}; end
if nargin < 5 || isempty(levels),  levels = {'finer','xfine'}; end
if nargin < 6 || isempty(tagSfx),  tagSfx = ''; end
import com.comsol.model.util.*
HAUTO = struct('xfine', 2, 'finer', 3, 'fine', 4);
S = BFH_paths(cfgPath); cfg = S.cfg; C = cfg.comsol; C.server_port = port;
F = cfg.families.(family);
BFH_connect_any(C);
ST = bfh_read_states_table(S.statesTable);
outDir = fullfile(S.dataDir, 'mesh');
if ~isfolder(outDir), mkdir(outDir); end
[plist, frequencies] = BFH_plist_from_cfg(cfg);
if strcmpi(tagSfx, '_SMOKE'), plist = '1 1000 100000'; frequencies = [1 1000 100000]; end
nDone = 0; nSkip = 0; nFail = 0; t0 = tic;
fprintf('==== BFH_run_mesh  %s  port %d  %s ====\n', family, port, datestr(now));
fprintf('states: %s | levels: %s\n', strjoin(states, ','), strjoin(levels, ','));
for si = 1:numel(states)
  st = states{si};
  for li = 1:numel(levels)
    lv = levels{li};
    csv = fullfile(outDir, sprintf('Z_%s_%s_%s%s.csv', family, st, lv, tagSfx));
    if isfile(csv), fprintf('[skip] %s\n', csv); nSkip = nSkip + 1; continue; end
    isS5 = strcmpi(st, 'S5');
    mp = F.model_path; if isS5, mp = F.s5_model_path; end
    if ~isfile(mp), fprintf('[MISS] %s\n', mp); nFail = nFail + 1; continue; end
    tag = sprintf('mesh_%s_%s_%s', family, st, lv);
    BFH_drop(tag);
    try
        BFH_hold_check();
        tc = tic;
        fprintf('\n--- %s | %s | %s (hauto=%d) ---\n', family, st, lv, HAUTO.(lv));
        Cl = C; Cl.mesh_hauto = HAUTO.(lv);
        model = mphload(char(mp), tag);
        BFH_repair_mix(model);
        nelem = BFH_force_mesh(model, Cl);
        BFH_apply_geom(model, F);
        sinfo = struct('mode', 'both_linear', 'state', st, 'c', 'n/a (intact model)', 'sigma', 'n/a');
        if ~isS5, sinfo = BFH_apply_survey(model, C, ST, st, 'both_linear'); end
        std = bfh_first_study_tag(model, char(C.study_tag));
        bfh_set_freq_list(model, std, plist, char(C.freq_feature_tag));
        fprintf('    [solve] mesh %d elements, %d frequencies ...\n', nelem, numel(strsplit(plist)));
        model.study(std).run();
        meta = struct('family', family, 'state', st, 'kind', 'mesh_contrast_convergence', ...
                      'mesh_level', lv, 'mesh_hauto', sprintf('%g', Cl.mesh_hauto), ...
                      'mesh_elements', sprintf('%g', nelem), ...
                      'survey', 'both_linear', 'survey_c', sinfo.c, ...
                      'survey_sigma', getfielddef(sinfo, 'sigma', 'n/a'), ...
                      'mix_ladder', 'canonical coefficient-level linear mixture (BFH_repair_mix, in-memory)', ...
                      'material_override', 'none', ...
                      'model', char(mp), ...
                      'z_expr', mesh_zexpr(C, F), ...
                      'geom_Re_b_n', mesh_geomstr(F), ...
                      'grid', sprintf('%g-%g Hz, %d points', frequencies(1), frequencies(end), numel(frequencies)), ...
                      'solve_s', sprintf('%.1f', toc(tc)));
        meta = BFH_stamp_env(meta, Cl);
        bfh_export_Z(model, mesh_zexpr(C, F), csv, meta);
        nDone = nDone + 1;
        fprintf('[done] %s %s %s in %.1f s\n', family, st, lv, toc(tc));
    catch ME
        fprintf('[FAIL] %s %s %s: %s\n%s\n', family, st, lv, ME.identifier, ME.message);
        for kk = 1:numel(ME.stack), fprintf('    at %s line %d\n', ME.stack(kk).name, ME.stack(kk).line); end
        nFail = nFail + 1;
    end
    BFH_drop(tag);
  end
end
fprintf('\n==== finished in %.1f min: %d solved, %d skipped, %d failed ====\n', toc(t0)/60, nDone, nSkip, nFail);
end
function e = mesh_zexpr(C, F)
if isfield(F, 'z_expr') && ~isempty(F.z_expr), e = char(F.z_expr); else, e = char(C.z_expr); end
if isfield(F, 'z_sign') && double(F.z_sign) < 0, e = ['-(' e ')']; end
end
function g = mesh_geomstr(F)
if isfield(F, 'geom_params') && ~isempty(F.geom_params)
    p = F.geom_params; g = sprintf('Re=%g b=%g n=%g', double(p.Re), double(p.b), double(p.n));
else, g = '(model default)'; end
end
function v = getfielddef(s, f, d)
if isfield(s, f), v = s.(f); else, v = d; end
end
