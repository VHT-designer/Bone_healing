function ds = bfh_pick_solved_dataset(model)
tags = cellstr(char(model.result.dataset.tags()));
ds = tags{1};
for k = 1:numel(tags)
    try sol = char(model.result.dataset(tags{k}).getString('solution')); catch, sol = ''; end
    if ~isempty(sol) && ~strcmpi(sol, '<none>')
        try
            f = mphglobal(model, 'freq', 'dataset', tags{k});
            if ~isempty(f), ds = tags{k}; return; end
        catch
        end
    end
end
end
