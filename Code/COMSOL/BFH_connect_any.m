function BFH_connect_any(C)
try
    ModelUtil.tags();
    fprintf('[BFH] already in a LiveLink session - no mphstart needed\n');
    return
catch
end
cands = {};
if isfield(C, 'mli_path'),     cands{end+1} = char(C.mli_path);     end
if isfield(C, 'mli_path_alt'), cands{end+1} = char(C.mli_path_alt); end
cands{end+1} = 'C:\Program Files\COMSOL\COMSOL64\Multiphysics\mli';
port = 2045; if isfield(C, 'server_port'), port = double(C.server_port); end
for k = 1:numel(cands)
    if isfolder(cands{k})
        fprintf('[BFH] using LiveLink path %s\n', cands{k});
        bfh_connect(cands{k}, port);
        return
    end
end
error('BFH_connect_any: no COMSOL mli folder found. Tried:\n  %s', strjoin(cands, sprintf('\n  ')));
end
