function bfh_probe_details(mphPath, port, mliPath)
if nargin < 2 || isempty(port), port = 2045; end
if nargin < 3, mliPath = 'C:\Program Files\COMSOL\COMSOL64\Multiphysics\mli'; end
bfh_connect(mliPath, port);
model = mphload(mphPath, 'probe_disc');
fprintf('\n=== PROBE DETAILS: %s ===\n', mphPath);
comp = model.component('comp1');
g = comp.geom('geom1');
ft = cellstr(string(g.feature().tags()));
fprintf('--- geometry features ---\n');
for k = 1:numel(ft)
    f = g.feature(ft{k});
    typ = ''; try, typ = char(f.getType()); catch, end
    fprintf('%-8s type=%s\n', ft{k}, typ);
    for prop = {'r', 'h', 'pos', 'ax2', 'ax3', 'semiaxes', 'a', 'b', 'c', 'rot', 'axis', 'axistype', 'size', 'base', 'layer'}
        try
            v = char(f.getString(prop{1}));
            fprintf('    %-9s = %s\n', prop{1}, v);
        catch
            try
                v = f.getStringArray(prop{1});
                vv = cellstr(string(v));
                fprintf('    %-9s = [%s]\n', prop{1}, strjoin(vv, ', '));
            catch
                try
                    v2 = f.getStringMatrix(prop{1});
                    rows = {};
                    for r = 1:numel(v2), rows{end+1} = strjoin(cellstr(string(v2(r))), ' '); end
                    fprintf('    %-9s = [%s]\n', prop{1}, strjoin(rows, '; '));
                catch, end
            end
        end
    end
end
fprintf('--- material domain selections + all property expressions ---\n');
mats = cellstr(string(comp.material().tags()));
for k = 1:numel(mats)
    m = comp.material(mats{k});
    sel = ''; try, sel = mat2str(double(m.selection().entities())); catch, end
    lbl = ''; try, lbl = char(m.label()); catch, end
    fprintf('%-6s label="%s" domains=%s\n', mats{k}, lbl, sel);
    try
        pg = m.propertyGroup('def');
        pn = cellstr(string(pg.properties()));
        for j = 1:numel(pn)
            try, fprintf('    %-24s = %s\n', pn{j}, char(pg.getString(pn{j}))); catch, end
        end
    catch, end
end
fprintf('--- probes ---\n');
try
    pt = cellstr(string(model.probe().tags()));
    for k = 1:numel(pt)
        p = model.probe(pt{k});
        typ = ''; try, typ = char(p.getType()); catch, end
        sel = ''; try, sel = mat2str(double(p.selection().entities())); catch, end
        expr = '';
        try, expr = char(p.getString('expr')); catch, end
        pname = ''; try, pname = char(p.getString('probename')); catch, end
        fprintf('%-8s type=%-14s name=%-8s sel=%s expr=%s\n', pt{k}, typ, pname, sel, expr);
        try
            sub = cellstr(string(p.feature().tags()));
            for j = 1:numel(sub)
                se = ''; try, se = char(p.feature(sub{j}).getString('expr')); catch, end
                sn = ''; try, sn = char(p.feature(sub{j}).getString('probename')); catch, end
                fprintf('    feature %-8s name=%-8s expr=%s\n', sub{j}, sn, se);
            end
        catch, end
    end
catch e
    fprintf('(no probes: %s)\n', e.message);
end
fprintf('--- component couplings (intop*) ---\n');
try
    ct = cellstr(string(comp.cpl().tags()));
    for k = 1:numel(ct)
        c = comp.cpl(ct{k});
        sel = ''; try, sel = mat2str(double(c.selection().entities())); catch, end
        typ = ''; try, typ = char(c.getType()); catch, end
        fprintf('%-8s type=%-12s sel=%s\n', ct{k}, typ, sel);
    end
catch, end
fprintf('--- terminal/ground details ---\n');
p = comp.physics('ec');
for tag = {'term1', 'gnd1'}
    try
        f = p.feature(tag{1});
        fprintf('%s sel=%s\n', tag{1}, mat2str(double(f.selection().entities())));
        for prop = {'TerminalType', 'I0', 'V0', 'TerminalName'}
            try, fprintf('    %-14s = %s\n', prop{1}, char(f.getString(prop{1}))); catch, end
        end
    catch, end
end
fprintf('--- study/solver ---\n');
st = cellstr(string(model.study().tags()));
for k = 1:numel(st)
    ftg = cellstr(string(model.study(st{k}).feature().tags()));
    for j = 1:numel(ftg)
        f = model.study(st{k}).feature(ftg{j});
        for prop = {'plist', 'punit', 'activate'}
            try, fprintf('  %s.%s %s = %s\n', st{k}, ftg{j}, prop{1}, char(f.getString(prop{1}))); catch, end
        end
    end
end
com.comsol.model.util.ModelUtil.remove('probe_disc');
end
