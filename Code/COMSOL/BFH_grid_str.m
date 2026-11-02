function g = BFH_grid_str(cfg)
F = cfg.freq;
if isfield(F, 'plist_mode') && strcmpi(char(F.plist_mode), 'file')
    g = sprintf('%g-%g Hz, %d points read from %s (%s)', double(F.f_min_Hz), double(F.f_max_Hz), ...
        double(F.n_points), char(F.file), char(getfield_def(F, 'description', 'file grid')));
else
    g = sprintf('%g-%g Hz, %d pts/decade', double(F.f_min_Hz), double(F.f_max_Hz), double(F.points_per_decade));
end
end
function v = getfield_def(s, f, d)
if isfield(s, f) && ~isempty(s.(f)), v = s.(f); else, v = d; end
end
