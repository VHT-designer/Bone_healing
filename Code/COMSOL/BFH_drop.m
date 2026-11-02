function n = BFH_drop(tag)
import com.comsol.model.util.*
n = NaN;
try
    present = cellstr(string(ModelUtil.tags()));
catch ME
    warning('BFH_drop: cannot list models (%s) - is LiveLink connected?', ME.message);
    return
end
if any(strcmp(char(tag), present))
    try
        ModelUtil.remove(char(tag));
    catch ME
        warning('BFH_drop: server refused to remove %s (%s)', char(tag), ME.message);
    end
end
try
    n = numel(cellstr(string(ModelUtil.tags())));
catch
end
if n > 2
    fprintf('[mem] %d model(s) still resident on the server after dropping %s\n', ...
            n, char(tag));
end
end
