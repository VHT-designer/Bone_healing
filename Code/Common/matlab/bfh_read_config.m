function cfg = bfh_read_config(configPath)
txt = fileread(configPath);
cfg = jsondecode(txt);
cfg.x_config_dir = fileparts(char(java.io.File(configPath).getAbsolutePath()));
fn = fieldnames(cfg);
for k = 1:numel(fn)
    if startsWith(fn{k}, 'x_') && ~strcmp(fn{k}, 'x_config_dir')
        cfg = rmfield(cfg, fn{k});
    end
end
end
