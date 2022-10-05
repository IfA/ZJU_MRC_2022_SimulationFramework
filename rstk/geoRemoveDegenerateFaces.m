function g = geoRemoveDegenerateFaces(g)
    if ~isstruct(g) || ~isscalar(g) || ~all(isfield(g, {'v', 'f'}))
        error('Input is no valid geometry object');
    end

    f = g.f;
    v = g.v;
    if ~isempty(f)
        if (size(f, 2) == 3)
            validTris = false(size(f, 1), 1);
            for i = 1:size(f, 1)
                pts = v(f(i, :), :);
                validTris (i) = ~any([all(pts(1, :) == pts(2, :)), all(pts(2, :) == pts(3, :)), all(pts(3, :) == pts(1, :))]);
            end                
            g.f = f(validTris, :);            
        else
            validQuads = false(size(f, 1), 1);
            for i = 1:size(f, 1)
                if isnan(f(i, 1))
                    % triangle
                    pts = v(f(i, 1:3), :);                    
                    validQuads(i) = ~any([all(pts(1, :) == pts(2, :)), all(pts(2, :) == pts(3, :)), all(pts(3, :) == pts(1, :))]);
                else
                    pts = v(f(i, :), :);
                    validQuads(i) = ~any([all(pts(1, :) == pts(2, :)), all(pts(2, :) == pts(3, :)), all(pts(3, :) == pts(4, :)), all(pts(4, :) == pts(1, :)), ...
                                         all(pts(1, :) == pts(3, :)), all(pts(2, :) == pts(4, :))]);
                end
            end
            g.f = f(validQuads, :);
        end        
    end
end