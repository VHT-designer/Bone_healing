function bfh_connect(mliPath, port)
if nargin < 2 || isempty(port), port = 2045; end
if ~isempty(mliPath) && exist(mliPath, 'dir'), addpath(mliPath); end
try
    mphstart(port);
    fprintf('[bfh] connected to COMSOL server on port %d\n', port);
catch ME
    if contains(ME.message, 'already connected') || contains(ME.message, 'Already connected')
        fprintf('[bfh] already connected to COMSOL server\n');
    else
        rethrow(ME);
    end
end
end
