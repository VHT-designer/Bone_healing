function info = BFH_apply_override(model, C, overrideName)
info = struct('override', overrideName, 'materials', '');
if strcmpi(overrideName, 'none'), return; end
O = C.material_override.(overrideName);
comp = char(C.component_tag);
applied = {};
for k = 1:numel(O.targets)
    t = O.targets{k};
    if iscell(t), t = t{1}; end
    try
        pg = model.component(comp).material(char(t)).propertyGroup('def');
        before = char(pg.getString('electricconductivity'));
        pg.set('electricconductivity', char(O.sigma));
        pg.set('relpermittivity',      char(O.epsr));
        applied{end+1} = sprintf('%s(%s->%s)', char(t), before, char(O.sigma));
    catch ME
        warning('override: material %s not set (%s)', char(t), ME.message);
    end
end
info.materials = strjoin(applied, ' ');
fprintf('[override] %s: %s\n', overrideName, info.materials);
end
