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
