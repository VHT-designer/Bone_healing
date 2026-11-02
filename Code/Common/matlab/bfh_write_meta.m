function bfh_write_meta(path, s)
fid = fopen(path, 'w'); assert(fid > 0, 'cannot open %s', path);
fprintf(fid, '# COMSOL export audit trail (R2_COMPUTE_PACKAGES)\n');
fn = fieldnames(s);
for k = 1:numel(fn)
    v = s.(fn{k});
    if isnumeric(v) || islogical(v), v = mat2str(v); end
    fprintf(fid, '%s: %s\n', fn{k}, char(string(v)));
end
fprintf(fid, 'export_timestamp: %s\n', datestr(now, 'yyyy-mm-ddTHH:MM:SS'));
[~, host] = system('hostname'); fprintf(fid, 'host: %s\n', strtrim(host));
try, fprintf(fid, 'comsol_version: %s\n', char(com.comsol.model.util.ModelUtil.getVersion())); catch, end
fclose(fid);
end
