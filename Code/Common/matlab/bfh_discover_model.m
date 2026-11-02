function bfh_discover_model(mphPath, port, mliPath)
if nargin < 2 || isempty(port), port = 2045; end
if nargin < 3, mliPath = 'C:\Program Files\COMSOL\COMSOL64\Multiphysics\mli'; end
bfh_connect(mliPath, port);
model = mphload(mphPath, 'disc');
fprintf('\n=== MODEL: %s ===\n', mphPath);
comps = cellstr(string(model.component().tags()));
fprintf('components: %s\n', strjoin(comps, ', '));
for c = 1:numel(comps)
    comp = model.component(comps{c});
    fprintf('\n--- component %s ---\n', comps{c});
    fprintf('geometries: %s\n', strjoin(cellstr(string(comp.geom().tags())), ', '));
    gt = cellstr(string(comp.geom().tags()));
    if ~isempty(gt), try, fprintf('length unit: %s\n', char(comp.geom(gt{1}).lengthUnit())); catch, end, end
    fprintf('meshes: %s\n', strjoin(cellstr(string(comp.mesh().tags())), ', '));
    mt = cellstr(string(comp.mesh().tags()));
    for k = 1:numel(mt)
        try
            ft = cellstr(string(comp.mesh(mt{k}).feature().tags()));
            fprintf('  mesh %s features: %s\n', mt{k}, strjoin(ft, ', '));
            fprintf('  mesh %s size/hauto = %s\n', mt{k}, char(comp.mesh(mt{k}).feature('size').getString('hauto')));
        catch, end
    end
    fprintf('materials:\n');
    mats = cellstr(string(comp.material().tags()));
    for k = 1:numel(mats)
        lbl = ''; ec = ''; er = '';
        try, lbl = char(comp.material(mats{k}).label()); catch, end
        try, ec = char(comp.material(mats{k}).propertyGroup('def').getString('electricconductivity')); catch, end
        try, er = char(comp.material(mats{k}).propertyGroup('def').getString('relativepermittivity')); catch, end
        fprintf('  %-6s label="%s"  sigma=%s  epsr=%s\n', mats{k}, lbl, ec, er);
    end
    fprintf('physics:\n');
    pt = cellstr(string(comp.physics().tags()));
    for k = 1:numel(pt)
        p = comp.physics(pt{k});
        fprintf('  %s (%s)\n', pt{k}, char(p.getType()));
        ft = cellstr(string(p.feature().tags()));
        for j = 1:numel(ft)
            f = p.feature(ft{j});
            sel = '';
            try, sel = mat2str(double(f.selection().entities())); catch, end
            fprintf('     %-12s type=%-22s sel=%s\n', ft{j}, char(f.getType()), sel);
        end
    end
    fprintf('named selections: %s\n', strjoin(cellstr(string(comp.selection().tags())), ', '));
    fprintf('variables nodes: %s\n', strjoin(cellstr(string(comp.variable().tags())), ', '));
    vt = cellstr(string(comp.variable().tags()));
    for k = 1:numel(vt)
        try
            names = cellstr(string(comp.variable(vt{k}).varnames()));
            for j = 1:numel(names)
                fprintf('   %s = %s\n', names{j}, char(comp.variable(vt{k}).get(names{j})));
            end
        catch, end
    end
end
fprintf('\n--- global parameters (look for dl/a/b/w_blood, Re/b/n, I, Mix_*, end-members) ---\n');
pn = cellstr(string(model.param().varnames()));
for k = 1:numel(pn)
    fprintf('  %-22s = %s\n', pn{k}, char(model.param().get(pn{k})));
end
fprintf('\n--- functions ---\n');
try, fprintf('%s\n', strjoin(cellstr(string(model.func().tags())), ', ')); catch, end
fprintf('\n--- studies ---\n');
st = cellstr(string(model.study().tags()));
for k = 1:numel(st)
    ft = cellstr(string(model.study(st{k}).feature().tags()));
    fprintf('  %s features: %s\n', st{k}, strjoin(ft, ', '));
    for j = 1:numel(ft)
        try, fprintf('     %s plist = %s\n', ft{j}, char(model.study(st{k}).feature(ft{j}).getString('plist'))); catch, end
    end
end
fprintf('\n--- datasets ---\n%s\n', strjoin(cellstr(string(model.result.dataset().tags())), ', '));
fprintf('\n--- probes / global expressions test ---\n');
for ze = {'(bnd2-bnd3)/I', '(bnd4-bnd3)/I', 'I', 'bnd1', 'bnd2', 'bnd3', 'bnd4', 'S'}
    try
        dset = bfh_pick_solved_dataset(model);
        v = mphglobal(model, ze{1}, 'dataset', dset);
        fprintf('  %-16s evaluable (first value %g)\n', ze{1}, real(v(1)));
    catch
        fprintf('  %-16s NOT evaluable in the stored solution (may need a solve)\n', ze{1});
    end
end
com.comsol.model.util.ModelUtil.remove('disc');
end
