function bnds = bfh_find_boundaries_by_box(model, compTag, geomTag, box)
bnds = mphselectbox(model, geomTag, box, 'boundary');
if isempty(bnds)
    warning('no boundaries found in box %s (component %s)', mat2str(box), compTag);
end
end
