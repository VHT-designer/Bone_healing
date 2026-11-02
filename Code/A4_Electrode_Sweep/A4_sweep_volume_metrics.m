function A4_sweep_volume_metrics(configPath, mode, family)
here = fileparts(mfilename('fullpath'));
addpath(fullfile(fileparts(here),'Common','matlab'));
if nargin < 1 || isempty(configPath), configPath = fullfile(here,'config_A4.json'); end
if nargin < 2 || isempty(mode), mode = 'prod'; end
import com.comsol.model.util.*
cfg = bfh_read_config(configPath);
if nargin >= 3 && ~isempty(family), cfg.family = family; end
fam = char(cfg.family);
C = cfg.comsol;
if strcmpi(fam, 'Dipole')
    C.z_expr = '-(bnd3-bnd4)/I';
end
if isfield(C, 'models_by_family') && isfield(C.models_by_family, fam)
    C.model_normal   = C.models_by_family.(fam).normal;
    C.model_fracture = C.models_by_family.(fam).fracture;
end
outCsv = bfh_resolve_path(cfg, strrep(char(cfg.sweep_csv), '{family}', fam));
if ~exist(fileparts(outCsv), 'dir'), mkdir(fileparts(outCsv)); end
Re = cfg.sweep.Re_mm;
nvals = cfg.sweep.n_values.(fam)(:)';
avals = cfg.sweep.a_values_mm(:)';
isSmoke = strcmpi(mode, 'smoke');
if isSmoke, nvals = nvals(1); avals = avals([1 3]); end
u = char(C.param_unit_suffix);
pn = C.param_names;
zs = cfg.zstar_point(:);
el = cfg.ellipsoid_S0;
ind = sprintf(['((x-(%g[mm]))^2/(%g[mm])^2+(y-(%g[mm]))^2/(%g[mm])^2+' ...
    '(z-(%g[mm]))^2/(%g[mm])^2<=1)'], ...
    el.center(1), el.semiaxes(1), el.center(2), el.semiaxes(2), el.center(3), el.semiaxes(3));
done = containers.Map('KeyType', 'char', 'ValueType', 'logical');
hdr = {'family','Re_mm','n','a_mm','freq_Hz','S_zstar_N','S_frac_signed_N','S_frac_abs_N', ...
       'S_zstar_F','S_frac_signed_F','S_frac_abs_F','ReZ_N','ImZ_N','ReZ_F','ImZ_F','solve_s'};
if exist(outCsv, 'file')
    Tdone = readtable(outCsv);
    for r = 1:height(Tdone), done(sprintf('%g_%g', Tdone.n(r), Tdone.a_mm(r))) = true; end
    fprintf('[A4] resuming: %d geometries already in %s\n', height(Tdone), outCsv);
else
    fid = fopen(outCsv, 'w'); fprintf(fid, '%s\n', strjoin(hdr, ',')); fclose(fid);
end
if isfield(C, 'seat_preflight') && C.seat_preflight
    assert(bfh_preflight_seat(char(C.license_server)), 'A4: no free ACDC seat');
end
bfh_connect(char(C.mli_path), C.server_port);
mN = mphload(bfh_resolve_path(cfg, C.model_normal), 'a4N');
mF = mphload(bfh_resolve_path(cfg, C.model_fracture), 'a4F');
models = {mN, mF}; names = {'N', 'F'};
if C.fracture_state_S0.apply
    FS = C.fracture_state_S0;
    T = bfh_read_states_table(bfh_resolve_path(cfg, FS.states_table));
    bfh_apply_state(mF, FS, T(strcmp(T.state, 'S0'), :));
end
for k = 1:2
    std = bfh_first_study_tag(models{k}, C.study_tag);
    try
        ft = cellstr(string(models{k}.study(std).feature().tags()));
        for j = 1:numel(ft)
            if strcmpi(char(models{k}.study(std).feature(ft{j}).getType()), 'Parametric')
                models{k}.study(std).feature(ft{j}).active(false);
            end
        end
    catch, end
    bfh_set_freq_list(models{k}, std, sprintf('%.10g', cfg.freq_Hz), char(C.freq_feature_tag));
    models{k}.param.set(char(pn.Re), sprintf('%.10g%s', Re, u));
end
t0 = tic; nrun = 0;
for n = nvals
    for a = avals
        key = sprintf('%g_%g', n, a);
        if isKey(done, key), continue; end
        vals = struct();
        ts = tic;
        geomOk = true;
        try
            for k = 1:2
                m = models{k};
                m.param.set(char(pn.n), sprintf('%g', n));
                m.param.set(char(pn.a), sprintf('%.10g%s', a, u));
                std = bfh_first_study_tag(m, C.study_tag);
                m.study(std).run();
                dset = bfh_pick_solved_dataset(m);
                Sx = char(C.S_expr);
                try
                    Sz = mphinterp(m, Sx, 'coord', zs, 'dataset', dset);
                catch
                    Sx = char(C.S_expr_fallback);
                    Sz = mphinterp(m, Sx, 'coord', zs, 'dataset', dset);
                end
                Ssig = mphint2(m, [Sx '*' ind], 'volume', 'dataset', dset, 'selection', 'all');
                Sabs = mphint2(m, ['abs(' Sx ')*' ind], 'volume', 'dataset', dset, 'selection', 'all');
                Z = mphglobal(m, char(C.z_expr), 'dataset', dset);
                vals.(['Sz_' names{k}]) = real(Sz(1)); vals.(['Ssig_' names{k}]) = real(Ssig(1));
                vals.(['Sabs_' names{k}]) = real(Sabs(1)); vals.(['Z_' names{k}]) = Z(1);
            end
        catch ME
            geomOk = false;
            fprintf(2, '[A4] SKIP n=%g a=%g mm (geometry/mesh/solve failed): %s\n', n, a, ME.message);
        end
        if geomOk
            row = [Re, n, a, cfg.freq_Hz, vals.Sz_N, vals.Ssig_N, vals.Sabs_N, vals.Sz_F, vals.Ssig_F, vals.Sabs_F, ...
                   real(vals.Z_N), imag(vals.Z_N), real(vals.Z_F), imag(vals.Z_F), toc(ts)];
        else
            row = [Re, n, a, cfg.freq_Hz, nan(1, 10), toc(ts)];
        end
        fid = fopen(outCsv, 'a');
        fprintf(fid, '%s,%s\n', fam, strjoin(arrayfun(@(v) sprintf('%.10g', v), row, 'UniformOutput', false), ','));
        fclose(fid);
        nrun = nrun + 1;
        if geomOk
            fprintf('[A4] n=%g a=%g mm | S(z*)_N=%.3g | S_frac_N=%.3g | |dZ|=%.4g Ohm | %.0f s (elapsed %.0f min)\n', ...
                n, a, vals.Sz_N, vals.Ssig_N, abs(vals.Z_F - vals.Z_N), toc(ts), toc(t0)/60);
        else
            fprintf('[A4] n=%g a=%g mm | NaN row (geometry failed) | %.0f s (elapsed %.0f min)\n', ...
                n, a, toc(ts), toc(t0)/60);
        end
    end
end
bfh_write_meta([outCsv '.meta.txt'], struct('package', 'A4 fracture-volume criterion', 'family', fam, ...
    'freq_Hz', cfg.freq_Hz, 'Re_mm', Re, 'zstar_point', mat2str(zs'), 'ellipsoid_indicator', ind, ...
    'model_normal', bfh_resolve_path(cfg, C.model_normal), 'model_fracture', bfh_resolve_path(cfg, C.model_fracture), ...
    'S_expr', char(C.S_expr), 'z_expr', char(C.z_expr), 'mode', mode, 'n_geometries_this_run', nrun));
ModelUtil.remove('a4N'); ModelUtil.remove('a4F');
fprintf('[A4] done: %d geometries in %.1f min -> %s\nSee the root README for output details.\n', nrun, toc(t0)/60, outCsv);
end
