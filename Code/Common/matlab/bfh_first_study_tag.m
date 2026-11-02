function studyTag = bfh_first_study_tag(model, preferred)
tags = cellstr(string(model.study().tags()));
assert(~isempty(tags), 'bfh: no study found in model');
if nargin > 1 && ~isempty(preferred) && any(strcmp(tags, char(preferred)))
    studyTag = char(preferred);
else
    studyTag = tags{1};
end
end
