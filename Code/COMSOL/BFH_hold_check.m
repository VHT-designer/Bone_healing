function BFH_hold_check()
if isfile(fullfile(fileparts(mfilename('fullpath')), 'HOLD_QUEUE'))
    error('BFH:hold', ['HOLD_QUEUE present - case not started. Remove ' ...
        'Code\\COMSOL\\HOLD_QUEUE to resume.']);
end
end
