function bfh_write_csv(path, headers, data)
fid = fopen(path, 'w'); assert(fid > 0, 'cannot open %s', path);
fprintf(fid, '%s', headers{1});
for k = 2:numel(headers), fprintf(fid, ',%s', headers{k}); end
fprintf(fid, '\n');
fmt = [repmat('%.10g,', 1, size(data,2)-1) '%.10g\n'];
for r = 1:size(data,1), fprintf(fid, fmt, data(r,:)); end
fclose(fid);
end
