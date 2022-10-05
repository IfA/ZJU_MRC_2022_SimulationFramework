function pts = const_points(points)
    if ~isnumeric(points) || ~isreal(points) || length(size(points)) > 2 || (size(points, 2) ~= 2 && size(points, 2) ~= 3)
        error('const_points:format', 'Invalid format for points array: expected Nx2 or Nx3 numeric array');
    end

	pts = block_const(points);    
    pts.default_color = [0 0 0];
    pts.default_format = {'Marker', '.'};    
    
    pts.graphicElements(end + 1).draw = @draw;    
    
    function handles = draw(block, ax, handles, out, debug, state)        
        if isempty(handles)
            handles = line('Parent', ax, 'XData', [], 'YData', [], 'LineStyle', 'none', 'MarkerEdgeColor', block.color, block.format{:});
        end
		if size(out, 2) > 2
			set(handles, 'XData', out(:, 1), 'YData', out(:, 2), 'ZData', out(:, 3));        
		else set(handles, 'XData', out(:, 1), 'YData', out(:, 2));
		end
    end
end