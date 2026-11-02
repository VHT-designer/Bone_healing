function meta = BFH_stamp_env(meta, C)
import com.comsol.model.util.*
np = 'unknown'; ver = 'unknown';
try, np = char(string(ModelUtil.getNumberOfProcessors())); catch, end
if strcmp(np,'unknown')
    try, np = char(string(java.lang.Runtime.getRuntime().availableProcessors())); catch, end
    if ~strcmp(np,'unknown'), np = [np ' (JVM availableProcessors, not the server -np setting)']; end
end
if isfield(C,'server_np'), np = sprintf('%g (requested in config)', double(C.server_np)); end
try, ver = char(ModelUtil.getComsolVersion());              catch, end
host = 'unknown';
try, host = char(java.net.InetAddress.getLocalHost().getHostName()); catch, end
port = 'unknown';
if isfield(C, 'server_port'), port = sprintf('%g', double(C.server_port)); end
meta.env_comsol_np      = np;
meta.env_comsol_version = ver;
meta.env_server_port    = port;
meta.env_matlab         = version;
meta.env_host           = host;
meta.env_run_started    = datestr(now, 'yyyy-mm-ddTHH:MM:SS');
end
