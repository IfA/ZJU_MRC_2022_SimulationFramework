function sensor = sensor_landmarks2d()
    sensor = block_base(1/15, {'environment/landmarks', 'environment/obstacles', 'platform'}, @sample);
    
    sensor.mexFiles{end + 1} = fullfile(fileparts(mfilename('fullpath')), 'mex_isect_gridmap_rays.cpp');
    
    sensor.default_range = 3;    
    sensor.default_fieldOfView = [-65, 65] * pi / 180;  % camera field-of-view in rad (relativ to robot a.k.a. camera)
    sensor.default_bearingError = 5 * pi / 180;         % bearing error (1 sigma) in rad;
    sensor.default_rangeError = 1 / 100;				% distance error (1 sigma) in percent        
    sensor.default_color = [0 0 1];
    
    sensor.graphicElements(end + 1).draw = @drawFov;
    sensor.graphicElements(end).name = 'fiel-of-view';
    sensor.graphicElements(end + 1).draw = @drawConnections;
    sensor.graphicElements(end).name = 'connections';        
    
    function handles = drawFov(block, ax, handles, out, debugOut, state, landmarks, obstacleMap, platform)        
        if isempty(handles) 
            color = min(block.color + 0.5 * [1 1 1], [1 1 1]);
            handles = patch('Parent', ax, 'XData', [], 'YData', [], ...,
                            'FaceColor', color, 'EdgeColor', color, 'FaceAlpha', 0.2);
        end
        pose = platform.data;
        ts = pose(3) + linspace(block.fieldOfView(1), block.fieldOfView(2), 20);
        set(handles, 'XData', pose(1) + [0, block.range * cos(ts)], 'YData', pose(2) + [0, block.range * sin(ts)]);
    end    
	
    function handles = drawConnections(block, ax, handles, out, debugOut, state, landmarks, obstacleMap, platform)        
        if isempty(handles) 
            handles = line('Parent', ax, 'XData', [], 'YData', [], 'Color', block.color, 'LineWidth', 2, 'LineStyle', '-.');            
        end
        pose = platform.data;
        landmarks = landmarks.data;
        lmCount = length(out.lmIds);
        X = [repmat([NaN; pose(1)], 1, lmCount); landmarks(out.lmIds, 1)'];
        Y = [repmat([NaN; pose(2)], 1, lmCount); landmarks(out.lmIds, 2)'];
        set(handles, 'XData', reshape(X, [], 1), 'YData', reshape(Y, [], 1));
    end

    function [state, out, debugOut] = sample(block, t, state, landmarks, obstacleMap, platform)
        state = [];
        
        pose = platform(end).data;
        map = obstacleMap(end).data;
        lmPositions = landmarks(end).data;
        
        bearings = atan2(lmPositions(:, 2) - pose(2), lmPositions(:, 1) - pose(1)) - pose(3);
        bearings = mod(bearings + pi, 2 * pi) - pi;
        lmIds = [1:size(lmPositions, 1)]';
        
        inFovIdx = find((bearings >= block.fieldOfView(1)) & (bearings <= block.fieldOfView(2)));
        bearings = bearings(inFovIdx);
        lmIds = lmIds(inFovIdx);
        
        range = sqrt(sum((lmPositions(inFovIdx, :) - repmat(pose(1:2), size(bearings, 1), 1)).^2, 2));
        inRangeIdx = find(range < block.range);
        range = range(inRangeIdx);
        bearings = bearings(inRangeIdx);
        lmIds = lmIds(inRangeIdx);
                
        % detect visible landmarks       
        rayStarts = repmat((pose(1:2) - map.offset) / map.scale, size(lmIds, 1), 1);
        rayEnds = (lmPositions(lmIds, :) - repmat(map.offset, size(lmIds, 1), 1)) / map.scale;
        visIdx = find(~mex_isect_gridmap_rays(map.obstacles, rayStarts, rayEnds, true));
        range = range(visIdx);
        bearings = bearings(visIdx);
        lmIds = lmIds(visIdx);
        
        bearings = mod(bearings + block.bearingError * randn(size(bearings)) + pi, 2 * pi) - pi;
        range = range + (block.rangeError * range) .* randn(size(range));
        
        out = struct('range', range, 'bearing', bearings, 'lmIds', lmIds);
        debugOut = pose;
    end
end