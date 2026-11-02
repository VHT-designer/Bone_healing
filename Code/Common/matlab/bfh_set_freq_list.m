function bfh_set_freq_list(model, studyTag, plist, freqFeatureTag)
if nargin < 4 || isempty(freqFeatureTag), freqFeatureTag = 'freq'; end
model.study(studyTag).feature(freqFeatureTag).set('plist', plist);
fprintf('[bfh] %s/%s plist = %s\n', studyTag, freqFeatureTag, plist);
end
