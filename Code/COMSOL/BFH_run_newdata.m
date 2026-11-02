function BFH_run_newdata(cfgPath, mode, families, survey, override)
import com.comsol.model.util.*
if nargin < 1 || isempty(cfgPath), cfgPath = ''; end
if nargin < 2 || isempty(mode), mode = 'smoke'; end
S = BFH_paths(cfgPath);
cfg = S.cfg;  C = cfg.comsol;
if nargin < 3 || isempty(families), families = fieldnames(cfg.families); end
if ischar(families), families = {families}; end
if nargin < 4 || isempty(survey), survey = 'both_linear'; end
assert(isfield(C.survey_modes, survey), ...
    'unknown survey "%s"; known: %s', survey, strjoin(fieldnames(C.survey_modes), ', '));
fprintf('survey:   %s (%s)\n', survey, char(C.survey_modes.(survey).description));
sfx = '';
if ~strcmp(survey, 'both_linear'), sfx = ['_' survey]; end
if nargin < 5 || isempty(override), override = 'none'; end
if ~strcmp(override, 'none')
    sfx = [sfx '_' override];
    fprintf('override: %s\n', override);
end
states = cellstr(string(cfg.states));
depths = double(cfg.depths_mm);
[plistFull, fFull] = BFH_plist_from_cfg(cfg);
plistSmoke = '1 1000 100000';
logFile = fullfile(S.logDir, sprintf('run_%s_%s.log', mode, datestr(now,'yyyymmdd_HHMMSS')));
diary(logFile); diary on;
fprintf('==== BFH_run_newdata  mode=%s  %s ====\n', mode, datestr(now));
fprintf('grid: %s, %d points\n', BFH_grid_str(cfg), numel(fFull));
fprintf('families: %s\n', strjoin(families, ', '));
fprintf('output:   %s\n\n', S.outDir);
if isfield(C,'seat_preflight') && C.seat_preflight
    if ~bfh_preflight_seat(char(C.license_server), 'ACDC')
        warning('ACDC seat busy - another COMSOL solve may be running. Continuing anyway.');
    end
end
BFH_connect_any(C);
ST = bfh_read_states_table(S.statesTable);
doCole  = any(strcmpi(mode, {'cole','all','smoke'}));
doDepth = any(strcmpi(mode, {'depth','all','smoke'}));
plist   = plistFull;
suffix  = '';
if strcmpi(mode, 'smoke'), plist = plistSmoke; suffix = '_SMOKE'; end
nDone = 0; nSkip = 0; nFail = 0; t0 = tic;
for i = 1:numel(families)
    fam = families{i};
    if ~isfield(cfg.families, fam)
        warning('unknown family %s - skipped', fam); continue;
    end
    F = cfg.families.(fam);
    if doCole
        for k = 1:numel(states)
            st = states{k};
            csv = fullfile(S.outDir, sprintf('Z_%s_%s%s%s.csv', fam, st, sfx, suffix));
            if isfile(csv), fprintf('[skip] %s\n', csv); nSkip = nSkip + 1; continue; end
            isS5 = strcmpi(st, 'S5');
            mp = F.model_path; if isS5, mp = F.s5_model_path; end
            if ~isfile(mp)
                fprintf('[MISS] %s (%s %s)\n', mp, fam, st); nFail = nFail + 1; continue;
            end
            try
                BFH_hold_check();
                tc = tic;
                fprintf('\n--- %s %s (cole) ---\n%s\n', fam, st, mp);
                BFH_drop(sprintf('m_%s_%s', fam, st));
                model = mphload(mp, sprintf('m_%s_%s', fam, st));
                BFH_repair_mix(model);
                nelem = BFH_force_mesh(model, C);
                studyTag = bfh_first_study_tag(model, char(C.study_tag));
                BFH_apply_geom(model, F);
                sinfo = struct('mode', survey, 'state', st, 'c', 'n/a (intact model)');
                if ~isS5
                    sinfo = BFH_apply_survey(model, C, ST, st, survey);
                end
                oinfo = BFH_apply_override(model, C, override);
                bfh_set_freq_list(model, studyTag, plist, char(C.freq_feature_tag));
                fprintf('[solve] ...\n'); model.study(studyTag).run();
                meta = struct('family', fam, 'state', st, 'kind', 'cole', ...
                              'survey', survey, ...
                              'survey_c', sinfo.c, ...
                              'survey_sigma', getfielddef(sinfo, 'sigma', 'n/a'), ...
                              'survey_mix_law', getfielddef(sinfo, 'mix_law', 'n/a'), ...
                              'mix_ladder', 'canonical coefficient-level linear mixture (BFH_repair_mix, in-memory)', ...
                              'mesh_hauto', sprintf('%g', C.mesh_hauto), ...
                              'mesh_elements', sprintf('%g', nelem), ...
                              'material_override', override, ...
                              'override_detail', oinfo.materials, ...
                              'model', mp, 'mode', mode, ...
                              'z_expr', BFH_zexpr(C, F), ...
                              'z_expr_raw', BFH_zexpr_raw(F), ...
                              'z_sign_applied', BFH_zsign_str(F), ...
                              'geom_Re_b_n', BFH_geom_str(F), ...
                              'grid', BFH_grid_str(cfg), ...
                              'solve_s', sprintf('%.1f', toc(tc)));
                meta = BFH_stamp_env(meta, C);
                bfh_export_Z(model, BFH_zexpr(C, F), csv, meta);
                BFH_drop(sprintf('m_%s_%s', fam, st));
                nDone = nDone + 1;
                fprintf('[done] %s %s in %.1f s\n', fam, st, toc(tc));
            catch ME
                fprintf('[FAIL] %s %s: %s\n%s\n', fam, st, ME.identifier, ME.message);
                nFail = nFail + 1;
                BFH_drop(sprintf('m_%s_%s', fam, st));
            end
        end
    end
    if doDepth
        if isfield(C, 'depth_supported') && ~C.depth_supported
            fprintf(['\n[STOP] %s: the depth sweep cannot be solved from the models\n' ...
                     '       in this project. No depth parameter exists, and\n' ...
                     '       *_Sensitivity_Depth.mph are the A4 electrode-geometry\n' ...
                     '       sensitivity models, not fracture-depth models.\n' ...
                     '       See the root README for the anatomy/depth workflow.\n'], fam);
            continue
        end
        dmp = F.depth_model_path;
        if ~isfile(dmp)
            fprintf('[MISS] depth model %s\n', dmp); nFail = nFail + 1; continue;
        end
        dparam = BFH_find_depth_param(S, fam, C);
        if isempty(dparam)
            fprintf(['[STOP] %s: depth parameter unknown. Run BFH_discover_all, read\n' ...
                     '       %s\\discovery_%s_depth.txt, then add the real name to\n' ...
                     '       comsol.depth_param_candidates in config_newrun.json.\n'], ...
                     fam, S.discoveryDir, fam);
            nFail = nFail + 1; continue;
        end
        fprintf('\n[%s] depth parameter = %s\n', fam, dparam);
        for k = 1:numel(states)
            st = states{k};
            for q = 1:numel(depths)
                d = depths(q);
                csv = fullfile(S.outDir, sprintf('Z_%s_%s_%dmm%s.csv', fam, st, d, suffix));
                if isfile(csv), fprintf('[skip] %s\n', csv); nSkip = nSkip + 1; continue; end
                try
                    BFH_hold_check();
                    tc = tic;
                    fprintf('\n--- %s %s +%d mm (depth) ---\n', fam, st, d);
                    model = mphload(dmp, sprintf('d_%s_%s_%d', fam, st, d));
                    BFH_repair_mix(model);
                    nelem = BFH_force_mesh(model, C);
                    studyTag = bfh_first_study_tag(model, char(C.study_tag));
                    if ~strcmpi(st, 'S5')
                        row = ST(strcmp(ST.state, st), :);
                        bfh_apply_state(model, C, row);
                    end
                    model.param.set(dparam, sprintf('%g[mm]', d));
                    bfh_set_freq_list(model, studyTag, plist, char(C.freq_feature_tag));
                    fprintf('[solve] ...\n'); model.study(studyTag).run();
                    meta = struct('family', fam, 'state', st, 'kind', 'depth', ...
                                  'depth_mm', sprintf('%g', d), 'depth_param', dparam, ...
                                  'model', dmp, 'mode', mode, ...
                                  'mesh_hauto', sprintf('%g', C.mesh_hauto), ...
                                  'mesh_elements', sprintf('%g', nelem), ...
                                  'solve_s', sprintf('%.1f', toc(tc)));
                    meta = BFH_stamp_env(meta, C);
                    bfh_export_Z(model, BFH_zexpr(C, F), csv, meta);
                    BFH_drop(sprintf('d_%s_%s_%d', fam, st, d));
                nDone = nDone + 1;
                    fprintf('[done] %s %s +%d mm in %.1f s\n', fam, st, d, toc(tc));
                catch ME
                    fprintf('[FAIL] %s %s +%d mm: %s\n%s\n', fam, st, d, ME.identifier, ME.message);
                    nFail = nFail + 1;
                    BFH_drop(sprintf('d_%s_%s_%d', fam, st, d));
                end
            end
        end
    end
end
fprintf('\n==== finished in %.1f min: %d solved, %d skipped, %d failed ====\n', ...
    toc(t0)/60, nDone, nSkip, nFail);
fprintf('log: %s\n', logFile);
diary off;
end
function name = BFH_find_depth_param(S, fam, C)
name = '';
rep = fullfile(S.discoveryDir, sprintf('discovery_%s_depth.txt', fam));
if isfile(rep)
    txt = fileread(rep);
    tok = regexp(txt, 'FOUND:\s*(\w+)\s*=', 'tokens', 'once');
    if ~isempty(tok), name = tok{1}; return; end
end
cand = cellstr(string(C.depth_param_candidates));
if ~isempty(cand) && ~any(strcmp(cand, '')), name = ''; end
end
function e = BFH_zexpr(C, F)
if isfield(F, 'z_expr') && ~isempty(F.z_expr)
    e = char(F.z_expr);
else
    e = char(C.z_expr);
end
if isfield(F, 'z_sign') && double(F.z_sign) < 0
    e = ['-(' e ')'];
end
end
function BFH_apply_geom(model, F)
if ~isfield(F, 'geom_params') || isempty(F.geom_params), return; end
g = F.geom_params;
nm = fieldnames(g);
have = cellstr(string(model.param.varnames()));
for k = 1:numel(nm)
    if any(strcmp(have, nm{k}))
        model.param.set(nm{k}, sprintf('%.10g', double(g.(nm{k}))));
    end
end
fprintf('[geom] Re=%g b=%g n=%g\n', g.Re, g.b, g.n);
end
function v = getfielddef(s, f, d)
if isfield(s, f), v = s.(f); else, v = d; end
end
function e = BFH_zexpr_raw(F)
if isfield(F, 'z_expr') && ~isempty(F.z_expr), e = char(F.z_expr); else, e = '(default)'; end
end
function s = BFH_zsign_str(F)
if isfield(F, 'z_sign'), s = sprintf('%+d', double(F.z_sign)); else, s = '+1'; end
end
function g = BFH_geom_str(F)
if isfield(F, 'geom_params') && ~isempty(F.geom_params)
    p = F.geom_params;
    g = sprintf('Re=%g b=%g n=%g', double(p.Re), double(p.b), double(p.n));
else
    g = '(model default)';
end
end
