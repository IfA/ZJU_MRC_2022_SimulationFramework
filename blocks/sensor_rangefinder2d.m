function sensor = sensor_rangefinder2d()
    sensor = block_base(1/10, {'environment/obstacles', 'platform'}, @sample);

    sensor.mexFiles{end + 1} = fullfile(fileparts(mfilename('fullpath')), 'mex_isect_gridmap_rays.cpp');
    
    sensor.default_color = [0 0 1];
	sensor.default_fieldOfView = [-90, 90] * pi / 180; % [rad], relative to robot orientation
    sensor.default_increment = 1 * pi / 180;		   % angular difference between adjacent rays in rad
    sensor.default_maxRange = 4.5;                     % maximum detection distance in m
    sensor.default_error = 0.5 / 100;				   % stddev of range error, error scales with distance 
        
    sensor.graphicElements(end + 1).draw = @drawRays;
    
    % output data format: 
    % .range = Nx1 vector
    % .bearing = Nx1 vector
    % N...number of rays

    function handles = drawRays(block, ax, handles, out, debugOut, state, obstacles, platform)        
        if isempty(handles) 
            handles = line('Parent', ax, 'XData', [], 'YData', [], 'Color', block.color);
        end
        
        if ~isempty(platform)
            pose = platform.data;
            angles = out.bearing + pose(3);
            ranges = out.range;
            ranges(isinf(ranges)) = block.maxRange;
            XY = [ranges .* cos(angles), ranges .* sin(angles)];
            numRays = size(out.range, 1);

            X = pose(1) + [zeros(1, numRays); XY(:, 1)'];
            Y = pose(2) + [zeros(1, numRays); XY(:, 2)'];
            set(handles, 'XData', reshape([NaN(1, numRays); X], [], 1), 'YData', reshape([NaN(1, numRays); Y], [], 1));
        end
    end
	

    function [state, out, debugOut] = sample(block, t, state, obstacleMap, platform)
        state = [];
        debugOut = [];

		if ~isempty(platform) && ~isempty(obstacleMap)
            bearing = (block.fieldOfView(1):block.increment:block.fieldOfView(2))';
			arcs = mod(bearing + platform(end).data(3) + pi, 2 * pi) - pi;
            map = obstacleMap(end).data;
            rayStart = repmat((platform(end).data(1:2) - map.offset) / map.scale, length(arcs), 1);
            rayEnd = rayStart + (block.maxRange / map.scale) * [cos(arcs), sin(arcs)];
            [isect, range] = mex_isect_gridmap_rays(map.obstacles, rayStart, rayEnd, true);
            range(~isect) = inf;
            range = range * map.scale;
        
            % apply distance-dependent gaussian noise
            range(isect) = range(isect) + block.error * (range(isect) .* randn(sum(isect), 1));
        else
            bearing = [];
            range = [];
        end
        out = struct('bearing', bearing, 'range', range);
    end
end
