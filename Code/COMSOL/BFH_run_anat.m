function names = BFH_run_anat(cfgPath, family, port, sel, plistOverride, tagSfx, statesArg)
names = {};
if nargin >= 1 && ischar(cfgPath) && strcmp(cfgPath, '--list'), V = anat_variants(); names = {V.name}; return; end
if nargin < 1 || isempty(cfgPath), cfgPath = ''; end
if nargin < 2 || isempty(family),  family = 'Wenner'; end
if nargin < 3 || isempty(port),    port = 2046; end
if nargin < 4, sel = []; end
if nargin < 5, plistOverride = ''; end
if nargin < 6 || isempty(tagSfx), tagSfx = ''; end
if nargin < 7 || isempty(statesArg), statesArg = {'S0', 'S4'}; end
if ischar(statesArg), statesArg = {statesArg}; end
import com.comsol.model.util.*
S = BFH_paths(cfgPath); cfg = S.cfg; C = cfg.comsol; C.server_port = port;
F = cfg.families.(family);
BFH_connect_any(C);
ST = bfh_read_states_table(S.statesTable);
comp = char(C.component_tag);
outDir = fullfile(S.dataDir, ['anat' S.outSuffix]);
if ~isfolder(outDir), mkdir(outDir); end
[plist, ~] = BFH_plist_from_cfg(cfg);
if ~isempty(plistOverride), plist = plistOverride; fprintf('[anat] frequency list override: %s\n', plist); end
if strcmpi(tagSfx, '_SMOKE') && isempty(plistOverride), plist = '1 1000 100000'; end
V = anat_variants();
if isempty(sel), sel = 1:numel(V); end
zex = ''; if isfield(F,'z_expr') && ~isempty(F.z_expr), zex = char(F.z_expr); else, zex = char(C.z_expr); end
if isfield(F, 'z_sign') && double(F.z_sign) < 0, zex = ['-(' zex ')']; end
states = statesArg;
nDone = 0; nSkip = 0; nFail = 0; t0 = tic;
for ii = sel(:).'
    v = V(ii);
    for s = 1:numel(states)
        st = states{s};
        csv = fullfile(outDir, sprintf('Z_%s_%s_%s%s.csv', family, v.name, st, tagSfx));
        if isfile(csv), fprintf('[skip] %s\n', csv); nSkip = nSkip + 1; continue; end
        tag = sprintf('an_%s_%d_%s', family, ii, st);
        BFH_drop(tag);
        try
            tc = tic;
            fprintf('\n--- %s | %s | %s ---\n', family, v.name, st);
            fprintf('    skin %.1f mm | bone depth %.1f mm | cortical thickness %.1f mm\n', ...
                v.skin_mm, v.bone_depth_mm, v.cortical_mm);
            model = mphload(char(F.model_path), tag);
            g = cellstr(string(model.component(comp).geom().tags())); g = g{1};
            for q = 1:size(v.ops, 1)
                model.component(comp).geom(g).feature(v.ops{q,1}).set(v.ops{q,2}, v.ops{q,3});
                fprintf('    geom: %s.%s = %s\n', v.ops{q,1}, v.ops{q,2}, v.ops{q,3});
            end
            model.component(comp).geom(g).run();
            BFH_repair_mix(model);
            nelem = BFH_force_mesh(model, C);
            BFH_apply_geom(model, F);
            sinfo = BFH_apply_survey(model, C, ST, st, 'both_linear');
            std = bfh_first_study_tag(model, char(C.study_tag));
            bfh_set_freq_list(model, std, plist, char(C.freq_feature_tag));
            fprintf('    [solve] mesh %d elements ...\n', nelem);
            model.study(std).run();
            meta = struct('family', family, 'state', st, 'kind', 'anatomy_sweep', ...
                          'variant', v.name, 'variant_desc', v.desc, ...
                          'skin_mm', sprintf('%.2f', v.skin_mm), ...
                          'bone_depth_mm', sprintf('%.2f', v.bone_depth_mm), ...
                          'cortical_mm', sprintf('%.2f', v.cortical_mm), ...
                          'geom_ops', strjoin(arrayfun(@(q) sprintf('%s.%s=%s', ...
                             v.ops{q,1}, v.ops{q,2}, v.ops{q,3}), 1:size(v.ops,1), ...
                             'UniformOutput', false), '; '), ...
                          'survey', 'both_linear', 'survey_c', sinfo.c, ...
                          'mesh_hauto', sprintf('%g', C.mesh_hauto), ...
                          'mesh_elements', sprintf('%g', nelem), ...
                          'z_expr', zex, 'model', char(F.model_path), ...
                          'grid', BFH_grid_str(cfg), ...
                          'solve_s', sprintf('%.1f', toc(tc)));
            meta = BFH_stamp_env(meta, C);
            bfh_export_Z(model, zex, csv, meta);
            nDone = nDone + 1;
            fprintf('[done] %s %s in %.1f s\n', v.name, st, toc(tc));
        catch ME
            fprintf('[FAIL] %s %s: %s\n%s\n', v.name, st, ME.identifier, ME.message);
            nFail = nFail + 1;
        end
        BFH_drop(tag);
    end
end
fprintf('\n==== finished in %.1f min: %d solved, %d skipped, %d failed ====\n', ...
    toc(t0)/60, nDone, nSkip, nFail);
end
function V = anat_variants()
mk = @(nm, ds, ops, sk, bd, ct) struct('name', nm, 'desc', ds, 'ops', {ops}, ...
        'skin_mm', sk, 'bone_depth_mm', bd, 'cortical_mm', ct);
E = cell(0, 3);
V = mk('base', 'baseline: skin 2 mm, bone depth 11 mm, cortical thickness 4 mm', E, 2, 11, 4);
for xb = [43 41 37 35]
    d = 60 - (xb + 10);
    ops = { 'cyl4', 'pos', sprintf('%d 0 0', xb)
            'cyl6', 'pos', sprintf('%d 0 0', xb)
            'elp1', 'pos', sprintf('%d 0 100', xb) };
    V(end+1) = mk(sprintf('depth%02d', d), sprintf('bone surface %d mm below skin', d), ...
                  ops, 2, d, 4);
end
for r2 = [59 57 56]
    th = 60 - r2;
    V(end+1) = mk(sprintf('skin%d', th), sprintf('skin thickness %d mm', th), ...
                  {'cyl2', 'r', sprintf('%d', r2)}, th, 11, 4);
end
for r6 = [8 7 5 4]
    th = 10 - r6;
    V(end+1) = mk(sprintf('cort%d', th), sprintf('cortical thickness %d mm', th), ...
                  {'cyl6', 'r', sprintf('%d', r6)}, 2, 11, th);
end
for r3 = [47 46 44 43]
    th = 58 - (10 + r3);
    V(end+1) = mk(sprintf('fat%d', th), sprintf('fat thickness %d mm', th), ...
                  {'cyl3', 'r', sprintf('%d', r3)}, 2, 11, 4);
end
for dz = [2 5 10 15]
    V(end+1) = mk(sprintf('mis%02d', dz), sprintf('axial fracture offset %d mm', dz), ...
                  {'elp1', 'pos', sprintf('39 0 %d', 100 + dz)}, 2, 11, 4);
end
for xb = [33 31 29]
    d = 60 - (xb + 10);
    ops = { 'cyl4', 'pos', sprintf('%d 0 0', xb)
            'cyl6', 'pos', sprintf('%d 0 0', xb)
            'elp1', 'pos', sprintf('%d 0 100', xb) };
    V(end+1) = mk(sprintf('depth%02d', d), sprintf('bone surface %d mm below skin', d), ...
                  ops, 2, d, 4);
end
end
