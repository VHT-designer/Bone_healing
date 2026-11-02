function T = bfh_read_states_table(csvPath)
T = readtable(csvPath, 'TextType', 'string', 'Delimiter', ',');
req = {'state','dl_mm','a_mm','b_mm','w_blood','region_present'};
miss = setdiff(req, T.Properties.VariableNames);
assert(isempty(miss), 'states table missing columns: %s', strjoin(miss, ', '));
end
