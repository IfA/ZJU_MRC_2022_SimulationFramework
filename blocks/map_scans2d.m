% This block collects a scan map.
% Since it is currently not used by any other block, there is no useful 
% output data. 
% Visualization of the scan map is done by storing a Mx2 array of absolute
% ray endpoint coordinates for every scan in the state.
% The drawing function accesses the whole log to display all scans
function mapper = map_scans2d()
    mapper = block_base('sensors/rangefinder', {'platform', 'sensors/rangefinder'}, @addScan);    
    
    mapper.graphicElements(end + 1).draw = @drawMap;
    mapper.graphicElements(end).useLogs = true;
    
    mapper.default_color = [1 0 0];
    
    function handles = drawMap(block, ax, handles, iteration, times, outs, debugOuts, states)
        if isempty(handles) 
			%handles = patch('Parent', ax, 'XData', [], 'YData', [], 'FaceColor', 'none', 'EdgeColor', 'none', 'Marker', '.', 'MarkerEdgeColor', block.color);
            handles = line('Parent', ax, 'XData', [], 'YData', [], 'LineStyle', 'none', 'Marker', '.', 'Color', block.color);
        end
        sz = 0;
        for i = 1:iteration
            sz = sz + size(states{i}, 1);
        end
        XY = zeros(sz, 2);
        offset = 0;
        for i = 1:iteration
            sz = size(states{i}, 1);
            XY(offset + (1:sz), :) = states{i};
            offset = offset + sz;
        end
        set(handles, 'XData', XY(:, 1), 'YData', XY(:, 2));
    end

    function [state, out, debugOut] = addScan(block, t, state, poseProvider, rangefinder)
        debugOut = [];
        out = 0; % empty output ([]) not allowed
        
        validIdx = ~isinf(rangefinder.data.range);
        pose = poseProvider(end).data;
        absBearings = rangefinder.data.bearing(validIdx) + pose(3);        
        state = [rangefinder.data.range(validIdx) .* cos(absBearings) + pose(1), rangefinder.data.range(validIdx) .* sin(absBearings) + pose(2)];                
    end
end
