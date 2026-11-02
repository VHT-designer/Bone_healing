function p = bfh_resolve_path(cfg, rel)
rel = char(rel);
if isempty(rel), p = rel; return; end
if ~isempty(regexp(rel, '^([A-Za-z]:[\\/]|\\\\)', 'once')) || startsWith(rel, '/')
    p = rel;
else
    p = fullfile(cfg.x_config_dir, rel);
end
end
