function [plist, f] = BFH_plist_from_cfg(cfg)
F = cfg.freq;
mode = 'explicit';
if isfield(F, 'plist_mode') && ~isempty(F.plist_mode), mode = char(F.plist_mode); end
if strcmpi(mode, 'file')
    here = fileparts(mfilename('fullpath'));
    fn = char(F.file);
    if ~isfile(fn), fn = fullfile(here, fn); end
    assert(isfile(fn), 'BFH_plist_from_cfg: frequency file not found: %s', fn);
    T = readtable(fn, 'VariableNamingRule', 'preserve');
    col = 'Frequency';
    if isfield(F, 'column') && ~isempty(F.column), col = char(F.column); end
    f = double(T.(col)); f = f(isfinite(f)); f = sort(f(:)).';
    assert(numel(f) == double(F.n_points), ...
        'BFH_plist_from_cfg: file contains %d frequencies, but config specifies %d', numel(f), double(F.n_points));
else
    n = double(F.n_points);
    f = logspace(log10(double(F.f_min_Hz)), log10(double(F.f_max_Hz)), n);
end
parts = arrayfun(@(v) sprintf('%.10g', v), f, 'UniformOutput', false);
plist = strjoin(parts, ' ');
end
