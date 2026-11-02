function nelem = bfh_set_mesh_level(model, compTag, meshTag, hauto)
m = model.component(compTag).mesh(meshTag);
m.feature('size').set('hauto', hauto);
m.run();
nelem = NaN;
try
    st = mphmeshstats(model, meshTag);
    types = cellstr(string(st.types));
    ne = st.numelem;
    it = find(strcmp(types, 'tet'), 1);
    if ~isempty(it), nelem = ne(it); else, nelem = sum(ne); end
catch ME
    warning('mphmeshstats failed: %s', ME.message);
end
fprintf('[bfh] mesh %s/%s rebuilt at hauto=%d -> %d elements\n', compTag, meshTag, hauto, nelem);
end
