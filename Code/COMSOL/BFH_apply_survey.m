function info = BFH_apply_survey(model, C, ST, state, modeName)
M = C.survey_modes.(modeName);
mm = C.mix_material;
pg = model.component(char(mm.component)).material(char(mm.tag)).propertyGroup('def');
info = struct('mode', modeName, 'state', state);
if M.vary_geometry
    cval = C.geom_scalar.values.(state);
else
    cval = M.fixed_c;
end
if isnumeric(cval)
    cval = sprintf('%.10g', cval);
end
cval = char(cval);
assert(~isempty(strtrim(cval)), ...
    'BFH_apply_survey: empty c value for state %s, mode %s', state, modeName);
model.param.set(char(C.geom_scalar.name), cval);
info.c = cval;
if ~M.vary_dielectric
    fm = M.fixed_material;
    pg.set('electricconductivity', char(fm.sigma));
    pg.set('relpermittivity',      char(fm.epsr));
    info.sigma = char(fm.sigma);
    info.epsr  = char(fm.epsr);
else
    switch char(M.mix_law)
        case 'model_linear'
            L = C.dielectric_ladder_model_linear.(state);
            pg.set('electricconductivity', char(L.sigma));
            pg.set('relpermittivity',      char(L.epsr));
            info.sigma = char(L.sigma);
            info.epsr  = char(L.epsr);
            info.mix_law = 'model-native linear mixing of the Cole-Cole coefficients';
        case 'lichtenecker'
            row = ST(strcmp(ST.state, state), :);
            assert(height(row) == 1, 'state %s not in the states table', state);
            w = row.w_blood;
            se = sprintf(['-2*pi*freq*epsilon0_const*imag(exp(%g*log((Blood_epsilonr ' ...
                 '- j*Blood_sigma/(2*pi*freq*epsilon0_const))) + %g*log((BoneMarrow_epsilonr ' ...
                 '- j*BoneMarrow_sigma/(2*pi*freq*epsilon0_const)))))'], w, 1-w);
            ee = sprintf(['real(exp(%g*log((Blood_epsilonr - j*Blood_sigma/' ...
                 '(2*pi*freq*epsilon0_const))) + %g*log((BoneMarrow_epsilonr ' ...
                 '- j*BoneMarrow_sigma/(2*pi*freq*epsilon0_const)))))'], w, 1-w);
            model.param.set('Mix_sigma', se);
            model.param.set('Mix_epsilonr', ee);
            pg.set('electricconductivity', 'Mix_sigma');
            pg.set('relpermittivity',      'Mix_epsilonr');
            info.sigma = 'Mix_sigma (Lichtenecker)';
            info.epsr  = 'Mix_epsilonr (Lichtenecker)';
            info.w_blood = sprintf('%g', w);
            info.mix_law = 'Lichtenecker (log) mixing of the complex permittivity';
        otherwise
            error('BFH_apply_survey: unknown mix_law "%s"', char(M.mix_law));
    end
end
fprintf('[survey] %-12s %s: c = %-4s  sigma = %s\n', modeName, state, info.c, info.sigma);
end
