function bfh_apply_state(model, C, row)
u = ''; if isfield(C, 'param_unit_suffix'), u = char(C.param_unit_suffix); end
pn = C.state_param_names;
setp = @(name, val) model.param.set(char(name), val);
if row.region_present ~= 0
    if isfield(C, 'mix_material') && ~isempty(C.mix_material)
        mm = C.mix_material;
        pg = model.component(char(mm.component)).material(char(mm.tag)).propertyGroup('def');
        pg.set('electricconductivity', 'Mix_sigma');
        pg.set('relpermittivity', 'Mix_epsilonr');
    end
    if isfield(C, 'geom_scalar') && ~isempty(C.geom_scalar)
        gs = C.geom_scalar;
        val = gs.values.(char(row.state));
        if isnumeric(val), val = sprintf('%.10g', val); end
        setp(gs.name, char(val));
        fprintf('[bfh] geom scalar %s = %s\n', char(gs.name), char(val));
    end
end
if row.region_present ~= 0
    if isfield(pn, 'dl') && ~startsWith(char(pn.dl), '<<'), setp(pn.dl, sprintf('%.10g%s', row.dl_mm, u)); end
    if isfield(pn, 'a')  && ~startsWith(char(pn.a),  '<<'), setp(pn.a,  sprintf('%.10g%s', row.a_mm,  u)); end
    if isfield(pn, 'b')  && ~startsWith(char(pn.b),  '<<'), setp(pn.b,  sprintf('%.10g%s', row.b_mm,  u)); end
    switch char(C.state_mode)
        case 'params'
            assert(isfield(pn, 'w') && ~startsWith(char(pn.w), '<<'), 'state_mode=params needs state_param_names.w');
            setp(pn.w, sprintf('%.10g', row.w_blood));
        case 'mix_expr'
            assert(all(ismember({'Mix_sigma_expr','Mix_epsilonr_expr'}, row.Properties.VariableNames)), ...
                'state_mode=mix_expr needs Mix_sigma_expr / Mix_epsilonr_expr columns');
            se = char(row.Mix_sigma_expr); ee = char(row.Mix_epsilonr_expr);
            assert(~isempty(strtrim(se)) && ~isempty(strtrim(ee)), 'empty Mix expression for state %s', char(row.state));
            model.param.set('Mix_sigma', se);
            model.param.set('Mix_epsilonr', ee);
        otherwise
            error('bfh_apply_state: state_mode must be params | mix_expr (got "%s")', char(C.state_mode));
    end
end
if isfield(C, 's5_mode') && strcmp(char(C.s5_mode), 'param') && isfield(C, 's5_param')
    if row.region_present == 0
        model.param.set(char(C.s5_param.name), char(C.s5_param.value_off));
    else
        model.param.set(char(C.s5_param.name), char(C.s5_param.value_on));
    end
elseif isfield(C, 's5_mode') && strcmp(char(C.s5_mode), 'material') && row.region_present == 0
    model.param.set('Mix_sigma', 'BoneMarrow_sigma');
    model.param.set('Mix_epsilonr', 'BoneMarrow_epsilonr');
end
fprintf('[bfh] state %s applied (dl=%g mm, a=%g mm, b=%g mm, w=%g, region=%d)\n', ...
    char(row.state), row.dl_mm, row.a_mm, row.b_mm, row.w_blood, row.region_present);
end
