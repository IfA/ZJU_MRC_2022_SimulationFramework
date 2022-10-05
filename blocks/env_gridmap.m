% In its current state, this block just provides a static boolean obstacle
% map. In the future, it might be extended with dynamic obstacles.
% Expected inputs: none
% Output format: struct with fields
% - .obstacles: boolean matrix where true means the cell is covered by an obstacle
% - .scale: scale of the map in meter per cell
% - .offset: coordinates of the map origin (in meters)

function env = env_gridmap(map)
    env = block_base(inf, [], @createMap);
    env.graphicElements(end + 1).draw = @draw;
    env.default_scale = 0.01; % m/pixel
    env.default_offset = [0 0];
    env.default_color = [0 0 0];
    env.default_alpha = 1;
    env.default_inflateRadius = 0;
    
    function handles = draw(block, ax, handles, out, debug, state)        
        if isempty(handles); 
            handles = image('Parent', ax);
        end
        set(handles, 'CData', cat(3, out.obstacles * block.color(1), out.obstacles * block.color(2), out.obstacles * block.color(3)), ...
                     'AlphaData', out.obstacles * block.alpha, ...
                     'XData', out.offset(1) + out.scale * ((1:size(out.obstacles, 2)) - 0.5), ...
                     'YData', out.offset(2) + out.scale * ((1:size(out.obstacles, 1)) - 0.5));
    end

    function [state, out, debugOut] = createMap(block, varargin)        
        state = [];
        debugOut = [];
        if (~isnumeric(map) && ~islogical(map)) || ~isreal(map) || length(size(map)) > 2 || isempty(map)
            error('env_gridmap:format', 'Invalid argument format: expected matrix of numeric (or logical) values');
        end
        out = struct();
        out.obstacles = logical(map);
        if block.inflateRadius > 0
            % inflate map data to accommodate robot radius (+ safety distance)                    
            out.obstacles = imdilate(out.obstacles, strel('disk', round(block.inflateRadius / block.scale), 0));
        end
        out.scale = block.scale;
        out.offset = block.offset;
    end
end