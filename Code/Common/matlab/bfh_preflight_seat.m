function ok = bfh_preflight_seat(licenseServer, feature)
if nargin < 1 || isempty(licenseServer), licenseServer = '1718@RYOTRAN'; end
if nargin < 2 || isempty(feature), feature = 'ACDC'; end
ok = false;
lmutil = 'C:\Program Files\COMSOL\COMSOL64\Multiphysics\license\win64\lmutil.exe';
if ~isfile(lmutil)
    warning('lmutil not found at %s -- refusing to assume a free seat.', lmutil); return;
end
try
    [rc, out] = system(sprintf('"%s" lmstat -c %s -f %s', lmutil, licenseServer, feature));
    if rc ~= 0, warning('lmstat rc=%d\n%s', rc, out); return; end
    tok = regexp(out, '(\d+)\s+license(s)? in use', 'tokens', 'once');
    if isempty(tok)
        if ~isempty(regexp(out, ['Users of ' feature], 'once'))
            ok = true; fprintf('[preflight] %s: no "in use" line -> assuming FREE\n', feature); return;
        end
        warning('could not parse %s usage', feature); return;
    end
    inUse = str2double(tok{1});
    ok = inUse == 0;
    v = 'BUSY'; if ok, v = 'FREE'; end
    fprintf('[preflight] %s in use=%d -> %s\n', feature, inUse, v);
catch ME
    warning('seat pre-flight error: %s', ME.message);
end
end
