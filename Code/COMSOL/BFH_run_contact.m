function BFH_run_contact(cfgPath, family, port, states, arms, plist, suffix)
if nargin < 1 || isempty(cfgPath), cfgPath = ''; end
if nargin < 2 || isempty(family),  family = 'Wenner'; end
if nargin < 3 || isempty(port),    port = 2046; end
if nargin < 4 || isempty(states),  states = {'S0'}; end
if nargin < 5 || isempty(arms),    arms = {'ideal','const1k','const10k','zc_inf'}; end
if nargin < 6, plist = ''; end
if nargin < 7, suffix = ''; end
import com.comsol.model.util.*
S = BFH_paths(cfgPath); cfg = S.cfg; C = cfg.comsol; C.server_port = port;
F = cfg.families.(family);
if isempty(plist), [plist, ~] = BFH_plist_from_cfg(cfg); end
BFH_connect_any(C);
ST = bfh_read_states_table(S.statesTable);
comp = char(C.component_tag);
outDir = fullfile(S.dataDir, 'contact');
if ~isfolder(outDir), mkdir(outDir); end
DS = 1e-4;
RHOS = struct('ideal', 1e-9, 'const1k', 0.1, 'const10k', 1, 'const100k', 10);
zex = ''; if isfield(F,'z_expr') && ~isempty(F.z_expr), zex = char(F.z_expr); else, zex = char(C.z_expr); end
if isfield(F, 'z_sign') && double(F.z_sign) < 0, zex = ['-(' zex ')']; end
geomStr = '(model default)';
if isfield(F, 'geom_params') && ~isempty(F.geom_params), gp = F.geom_params; geomStr = sprintf('Re=%g b=%g n=%g', double(gp.Re), double(gp.b), double(gp.n)); end
for si = 1:numel(states)
    st = char(states{si}); isS5 = strcmpi(st, 'S5');
    mp = F.model_path; if isS5, mp = F.s5_model_path; end
    for ai = 1:numel(arms)
        arm = char(arms{ai});
        csv = fullfile(outDir, sprintf('Z_%s_%s_%s%s.csv', family, st, arm, suffix));
        if isfile(csv), fprintf('[skip] %s\n', csv); continue; end
        tg = sprintf('ct_%s_%s_%s', family, st, arm);
        tc = tic;
        try
            BFH_drop(tg);
            model = mphload(char(mp), tg);
            BFH_repair_mix(model);
            nelem = BFH_force_mesh(model, C);
            BFH_apply_geom(model, F);
            std = bfh_first_study_tag(model, char(C.study_tag));
            if ~isS5, BFH_apply_survey(model, C, ST, st, 'both_linear'); end
            ec = model.component(comp).physics('ec');
            gt = cellstr(string(model.component(comp).geom().tags())); g = gt{1};
            ud = double(model.component(comp).geom(g).getUpDown());
            tsel = double(ec.feature('term1').selection().entities()).';
            gsel = double(ec.feature('gnd1').selection().entities()).';
            eT = dom_mode(ud, tsel); eG = dom_mode(ud, gsel);
            Edom = [eT eG];
            ptags = cellstr(string(model.component(comp).probe().tags()));
            psel = containers.Map();
            for k = 1:numel(ptags)
                p = model.component(comp).probe(ptags{k});
                try, sel = double(p.selection().entities()).'; catch, sel = []; end
                if ~isempty(sel), psel(ptags{k}) = sel; Edom = [Edom dom_mode(ud, sel)]; end
            end
            Edom = unique(Edom(Edom > 0));
            iface = containers.Map('KeyType','double','ValueType','any');
            for b = 1:size(ud, 2)
                d = ud(:, b).'; e = intersect(d, Edom); s = setdiff(d, [Edom 0]);
                if numel(e) == 1 && numel(s) == 1, iface(e) = [getd(iface, e) b]; end
            end
            injF = [iface(eT) iface(eG)];
            allF = [];  ks = cell2mat(keys(iface)); for k = ks, allF = [allF iface(k)]; end
            senF = setdiff(allF, injF);
            fprintf('\n=== %s %s arm=%s : electrodes %s | drive contacts %s sense contacts %s (mesh %d) ===\n', ...
                family, st, arm, mat2str(Edom), mat2str(injF), mat2str(senF), nelem);
            assert(numel(Edom) == 4 && numel(allF) == 4, 'could not identify 4 electrodes / 4 contact faces');
            if strcmp(arm, 'zc_inf')
                caseMeta = setup_zcinf(model, comp, ec, g, ud, iface, eT, eG, psel, ptags);
            else
                rhos = RHOS.(arm);
                ec.feature('term1').selection().set(setdiff(tsel, allF));
                ec.feature('gnd1').selection().set(setdiff(gsel, allF));
                ci_make(ec, 'cisInj', injF, DS, rhos);
                ci_make(ec, 'cisSen', senF, DS, rhos);
                caseMeta = sprintf('ContactImpedance thinlayer ds=%g m, rhos=%g Ohm*m^2 (Zc=%g kOhm*cm^2) on all 4 contact faces; contact faces excluded from term1/gnd1', DS, rhos, rhos*1e4/1e3);
            end
            bfh_set_freq_list(model, std, plist, char(C.freq_feature_tag));
            fprintf('[solve] %s ...\n', caseMeta);
            model.study(std).run();
            meta = struct('family', family, 'state', st, 'kind', 'contact_impedance', 'arm', arm, ...
                          'case_definition', caseMeta, 'contact_faces_inj', mat2str(injF), 'contact_faces_sen', mat2str(senF), ...
                          'electrode_domains', mat2str(Edom), 'survey', 'both_linear', ...
                          'mix_ladder', 'canonical coefficient-level linear mixture (BFH_repair_mix, in-memory)', ...
                          'mesh_hauto', sprintf('%g', C.mesh_hauto), 'mesh_elements', sprintf('%g', nelem), ...
                          'model', char(mp), 'z_expr', zex, 'geom_Re_b_n', geomStr, 'grid', BFH_grid_str(cfg), ...
                          'solve_s', sprintf('%.1f', toc(tc)));
            meta = BFH_stamp_env(meta, C);
            if strcmp(arm, 'zc_inf')
                try
                    dset = bfh_pick_solved_dataset(model);
                    fprintf('[diag] I = %s\n', mat2str(mphglobal(model, 'I', 'dataset', dset).'));
                    fprintf('[diag] intop_inj(1) = %s  intop_gnd(1) = %s\n', mat2str(mphglobal(model, 'intop_inj(1)', 'dataset', dset).'), mat2str(mphglobal(model, 'intop_gnd(1)', 'dataset', dset).'));
                    for q = 1:4, fprintf('[diag] bnd%d = %s\n', q, mat2str(mphglobal(model, sprintf('bnd%d', q), 'dataset', dset).')); end
                    fprintf('[diag] maxV(skin faces) = %s\n', mat2str(mphmax(model, 'V', 'surface', 'selection', allF, 'dataset', dset).'));
                    for k = 1:numel(ptags)
                        p = model.component(comp).probe(ptags{k});
                        try, fprintf('[diag] probe %s type=%s sel=%s expr=%s\n', ptags{k}, char(p.getType()), mat2str(double(p.selection().entities()).'), char(p.getString('expr'))); catch ME2, fprintf('[diag] probe %s: %s\n', ptags{k}, ME2.message); end
                    end
                catch ME2
                    fprintf('[diag] error: %s\n', ME2.message);
                end
            end
            bfh_export_Z(model, zex, csv, meta);
            fprintf('[done] %s %s %s in %.0f s\n', family, st, arm, toc(tc));
        catch ME
            fprintf(2, '[FAIL] %s %s %s: %s\n', family, st, arm, ME.message);
            for kk = 1:min(4, numel(ME.stack)), fprintf(2, '    at %s line %d\n', ME.stack(kk).name, ME.stack(kk).line); end
        end
        BFH_drop(tg);
    end
end
end
function v = getd(m, k)
if isKey(m, k), v = m(k); else, v = []; end
end
function e = dom_mode(ud, bl)
d = ud(:, bl); d = d(:); d = d(d > 0);
if isempty(d), e = 0; return; end
u = unique(d); c = arrayfun(@(x) sum(d == x), u); [~, i] = max(c); e = u(i);
end
function ci_make(ec, tg, bl, ds, rhos)
if isempty(bl), return; end
ec.create(tg, 'ContactImpedance', 2);
ec.feature(tg).selection().set(bl);
ec.feature(tg).set('spec_type', 'thinlayer');
ec.feature(tg).set('ds', sprintf('%.10g[m]', ds));
ec.feature(tg).set('sigmabnd_mat', 'userdef');
ec.feature(tg).set('sigmabnd', sprintf('%.10g[S/m]', ds/rhos));
ec.feature(tg).set('epsilonrbnd_mat', 'userdef');
ec.feature(tg).set('epsilonrbnd', '1');
end
function caseMeta = setup_zcinf(model, comp, ec, g, ud, iface, eT, eG, psel, ptags)
nd = double(model.component(comp).geom(g).getNDomains());
Edom = cell2mat(keys(iface));
ec.selection().set(setdiff(1:nd, Edom));
fT = iface(eT); fG = iface(eG);
ct = cellstr(string(model.component(comp).cpl().tags()));
if ~any(strcmp(ct, 'intop_inj')), model.component(comp).cpl().create('intop_inj', 'Integration'); end
model.component(comp).cpl('intop_inj').selection().geom(g, 2); model.component(comp).cpl('intop_inj').selection().set(fT);
if ~any(strcmp(ct, 'intop_gnd')), model.component(comp).cpl().create('intop_gnd', 'Integration'); end
model.component(comp).cpl('intop_gnd').selection().geom(g, 2); model.component(comp).cpl('intop_gnd').selection().set(fG);
ec.feature('term1').active(false);
ec.feature('gnd1').active(false);
ft = cellstr(string(ec.feature().tags()));
if ~any(strcmp(ft, 'ncd_inj')), ec.create('ncd_inj', 'NormalCurrentDensity', 2); end
ec.feature('ncd_inj').selection().set(fT); ec.feature('ncd_inj').set('nJ', 'I/intop_inj(1)');
if ~any(strcmp(ft, 'ncd_gnd')), ec.create('ncd_gnd', 'NormalCurrentDensity', 2); end
ec.feature('ncd_gnd').selection().set(fG); ec.feature('ncd_gnd').set('nJ', '-I/intop_gnd(1)');
for k = 1:numel(ptags)
    p = model.component(comp).probe(ptags{k});
    if ~isKey(psel, ptags{k}), continue; end
    e = dom_mode(ud, psel(ptags{k}));
    if isKey(iface, e), p.selection().set(iface(e)); fprintf('[zc_inf] probe %s -> faces %s (electrode %d)\n', ptags{k}, mat2str(iface(e)), e); end
end
pts = mphselectbox(model, g, [-1e3 1e3; -1e3 1e3; -0.1 0.1], 'point');
assert(~isempty(pts), 'zc_inf: no gauge vertex found at z = 0');
if ~any(strcmp(ft, 'pot0_bfh')), ec.create('pot0_bfh', 'ElectricPotential', 0); end
ec.feature('pot0_bfh').selection().set(pts(1)); ec.feature('pot0_bfh').set('V0', '0[V]');
caseMeta = sprintf(['zc_inf: electrodes %s excluded from ec; n.J = +I/A on %s, -I/A on %s; term1/gnd1 disabled; ' ...
    'probes read contact faces; gauge vertex %d (z=0)'], mat2str(Edom), mat2str(fT), mat2str(fG), pts(1));
end
