function model = model_platform2d(move, inputs)
    model = block_base(0, inputs, move);        
    
    model.log.uniform = true;
    
    model.graphicElements(end + 1).draw = @drawBot;
    model.graphicElements(end).name = 'Robot';
    model.graphicElements(end + 1).draw = @drawTrack;    
    model.graphicElements(end).name = 'Track';
    model.graphicElements(end).useLogs = true;
    
    model.default_color = [0 0 1];
    model.default_radius = 0.14;

    function handles = drawBot(block, ax, handles, out, varargin)        
        if isempty(handles) 
            handles.body = rectangle('Parent', ax, 'Curvature', [1 1], 'EdgeColor', 0.5 * block.color, 'FaceColor', block.color);
            handles.direction = line('Parent', ax, 'XData', [], 'YData', [], 'Color', bwContrastColor(block.color), 'LineWidth', 2);
        end
        
        center = out(1:2);
        rad = block.radius;
    	set(handles.body, 'Position', [center - rad * [1 1], rad * [2 2]]);
        set(handles.direction, 'XData', center(1) + [0, rad * cos(out(3))], 'YData', center(2) + [0, rad * sin(out(3))]);        
    end  
    function handles = drawTrack(block, ax, handles, iteration, times, out, debugOut, states)
        if isempty(handles)
            handles = line('Parent', ax, 'XData', [], 'YData', [], 'Color', block.color);
        end
        set(handles, 'XData', out(1, 1:iteration), 'YData', out(2, 1:iteration));
    end    
    
end

function [bw] = bwContrastColor(color)
	if sum([0.4 0.45 0.15] .* color) <= 0.4,
		bw = [1 1 1];
	else
		bw = [0 0 0];
	end
end
