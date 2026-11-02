function BFH_run_sens(cfgPath, family, port, sel, state, tagSfx)
if nargin < 1 || isempty(cfgPath), cfgPath = ''; end
if nargin < 2 || isempty(family),  family = 'Wenner'; end
if nargin < 3 || isempty(port),    port = 2046; end
if nargin < 4, sel = []; end
if nargin < 5 || isempty(state),   state = 'S2'; end
if nargin < 6 || isempty(tagSfx),  tagSfx = ''; end
import com.comsol.model.util.*
S = BFH_paths(cfgPath); cfg = S.cfg; C = cfg.comsol; C.server_port = port;
F = cfg.families.(family);
BFH_connect_any(C);
ST = bfh_read_states_table(S.statesTable);
comp = char(C.component_tag);
outDir = fullfile(S.dataDir, ['sens' S.outSuffix]);
if ~isfolder(outDir), mkdir(outDir); end
[plist, ~] = BFH_plist_from_cfg(cfg);
if strcmpi(tagSfx, '_SMOKE'), plist = '1 1000 100000'; end
V = sens_variants();
if isempty(sel), sel = 1:numel(V); end
nDone = 0; nSkip = 0; nFail = 0; t0 = tic;
fprintf('==== BFH_run_sens  %s  %s  port %d  %s ====\n', family, state, port, datestr(now));
fprintf('cases: %s\n', strjoin({V(sel).name}, ', '));
for ii = sel(:).'
    v = V(ii);
    csv = fullfile(outDir, sprintf('Z_%s_%s_%s%s.csv', family, state, v.name, tagSfx));
    if isfile(csv), fprintf('[skip] %s\n', csv); nSkip = nSkip + 1; continue; end
    tag = sprintf('sn_%s_%s_%d', family, state, ii);
    BFH_drop(tag);
    try
        BFH_hold_check();
        tc = tic;
        fprintf('\n--- %s | %s | %s (%s) ---\n', family, state, v.name, v.desc);
        model = mphload(char(F.model_path), tag);
        BFH_repair_mix(model);
        nelem = BFH_force_mesh(model, C);
        BFH_apply_geom(model, F);
        sinfo = BFH_apply_survey(model, C, ST, state, 'both_linear');
        pinfo = sens_perturb(model, comp, v);
        std = bfh_first_study_tag(model, char(C.study_tag));
        bfh_set_freq_list(model, std, plist, char(C.freq_feature_tag));
        fprintf('    [solve] mesh %d elements ...\n', nelem);
        model.study(std).run();
        meta = struct('family', family, 'state', state, 'kind', 'layer_sensitivity', ...
                      'variant', v.name, 'variant_desc', v.desc, ...
                      'pert_material', v.mat, 'pert_layer', v.layer, ...
                      'pert_factor', sprintf('%.4f', v.k), ...
                      'pert_sigma_before', pinfo.before, ...
                      'pert_sigma_after',  pinfo.after, ...
                      'survey', 'both_linear', 'survey_c', sinfo.c, ...
                      'survey_sigma', sinfo.sigma, ...
                      'mix_ladder', 'canonical coefficient-level linear mixture (BFH_repair_mix, in-memory)', ...
                      'mesh_hauto', sprintf('%g', C.mesh_hauto), ...
                      'mesh_elements', sprintf('%g', nelem), ...
                      'material_override', 'none', ...
                      'model', char(F.model_path), ...
                      'z_expr', sens_zexpr(C, F), ...
                      'geom_Re_b_n', sens_geomstr(F), ...
                      'grid', BFH_grid_str(cfg), ...
                      'solve_s', sprintf('%.1f', toc(tc)));
        meta = BFH_stamp_env(meta, C);
        bfh_export_Z(model, sens_zexpr(C, F), csv, meta);
        nDone = nDone + 1;
        fprintf('[done] %s in %.1f s\n', v.name, toc(tc));
    catch ME
        fprintf('[FAIL] %s: %s\n%s\n', v.name, ME.identifier, ME.message);
        for kk = 1:numel(ME.stack), fprintf('    at %s line %d\n', ME.stack(kk).name, ME.stack(kk).line); end
        nFail = nFail + 1;
    end
    BFH_drop(tag);
end
fprintf('\n==== finished in %.1f min: %d solved, %d skipped, %d failed ====\n', ...
    toc(t0)/60, nDone, nSkip, nFail);
end
function V = sens_variants()
d = 0.20;
L = { 'skin', 'mat1', 'Skin'
      'fat',  'mat2', 'Fat'
      'musc', 'mat3', 'Muscle'
      'cort', 'mat4', 'BoneCortical'
      'marr', 'mat5', 'BoneMarrow'
      'frac', 'mat6', 'FractureRegion' };
mk = @(nm, mt, ly, k, ds) struct('name', nm, 'mat', mt, 'layer', ly, 'k', k, 'desc', ds);
V = mk('base', 'none', 'none', 1.0, 'baseline: no perturbation');
for q = 1:size(L, 1)
    V(end+1) = mk(sprintf('%s_p%02d', L{q,1}, round(d*100)), L{q,2}, L{q,3}, ...
                  1 + d, sprintf('sigma(%s) x %.2f', L{q,3}, 1 + d));
    V(end+1) = mk(sprintf('%s_m%02d', L{q,1}, round(d*100)), L{q,2}, L{q,3}, ...
                  1 - d, sprintf('sigma(%s) x %.2f', L{q,3}, 1 - d));
end
d2 = 0.50;
L2 = { 'cort', 'mat4', 'BoneCortical'
       'marr', 'mat5', 'BoneMarrow'
       'frac', 'mat6', 'FractureRegion' };
for q = 1:size(L2, 1)
    V(end+1) = mk(sprintf('%s_p%02d', L2{q,1}, round(d2*100)), L2{q,2}, L2{q,3}, ...
                  1 + d2, sprintf('sigma(%s) x %.2f', L2{q,3}, 1 + d2));
    V(end+1) = mk(sprintf('%s_m%02d', L2{q,1}, round(d2*100)), L2{q,2}, L2{q,3}, ...
                  1 - d2, sprintf('sigma(%s) x %.2f', L2{q,3}, 1 - d2));
end
end
function info = sens_perturb(model, comp, v)
info = struct('before', 'n/a', 'after', 'n/a');
if strcmpi(v.mat, 'none'), fprintf('[pert] no perturbation\n'); return; end
pg = model.component(comp).material(char(v.mat)).propertyGroup('def');
before = char(pg.getString('electricconductivity'));
assert(~isempty(strtrim(before)), 'sens_perturb: %s has no electricconductivity property', v.mat);
after = sprintf('(%s)*(%.10g)', before, v.k);
pg.set('electricconductivity', after);
back = char(pg.getString('electricconductivity'));
assert(strcmp(back, after), 'sens_perturb: COMSOL did not accept the new expression for %s', v.mat);
info.before = before;
info.after  = after;
fprintf('[pert] %s (%s) x %.2f\n', v.mat, v.layer, v.k);
end
function e = sens_zexpr(C, F)
if isfield(F, 'z_expr') && ~isempty(F.z_expr), e = char(F.z_expr); else, e = char(C.z_expr); end
if isfield(F, 'z_sign') && double(F.z_sign) < 0, e = ['-(' e ')']; end
end
function g = sens_geomstr(F)
if isfield(F, 'geom_params') && ~isempty(F.geom_params)
    p = F.geom_params;
    g = sprintf('Re=%g b=%g n=%g', double(p.Re), double(p.b), double(p.n));
else
    g = '(model default)';
end
end
