function [plist, f] = bfh_reduced_freq_plist(pointsPerDecade, fmin, fmax)
if nargin < 1 || isempty(pointsPerDecade), pointsPerDecade = 12; end
if nargin < 2 || isempty(fmin), fmin = 1; end
if nargin < 3 || isempty(fmax), fmax = 1e5; end
n = round(log10(fmax/fmin) * pointsPerDecade) + 1;
f = logspace(log10(fmin), log10(fmax), n);
plist = strjoin(arrayfun(@(v) sprintf('%.10g', v), f, 'UniformOutput', false), ' ');
end
