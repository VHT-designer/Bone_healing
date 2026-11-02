function [f, Z] = bfh_export_Z(model, zExpr, csvPath, meta)
dset = bfh_pick_solved_dataset(model);
f  = mphglobal(model, 'freq', 'dataset', dset); f = f(:);
re = mphglobal(model, ['real(' zExpr ')'], 'dataset', dset);
im = mphglobal(model, ['imag(' zExpr ')'], 'dataset', dset);
Z  = re(:) + 1i*im(:);
[f, srt] = sort(f); Z = Z(srt);
signnote = 'native sign gives Im(Z)<0 for the capacitive arc';
if mean(imag(Z(~isnan(Z)))) > 0
    Z = conj(Z); signnote = 'Im flipped (conj) so that the capacitive arc gives Im(Z)<0';
end
bfh_write_csv(csvPath, {'freq_Hz','ReZ_Ohm','ImZ_Ohm'}, [f, real(Z), imag(Z)]);
if nargin < 4, meta = struct(); end
meta.dataset = char(dset);
meta.expression = sprintf('Z = %s', zExpr);
meta.sign = signnote;
meta.n_freq = sprintf('%d', numel(f));
meta.units = 'freq in Hz; ReZ, ImZ in Ohm';
bfh_write_meta([csvPath '.meta.txt'], meta);
fprintf('  [ok] %s (%d freq pts) |Z|@fmin=%.4g Ohm\n', csvPath, numel(f), abs(Z(1)));
end
