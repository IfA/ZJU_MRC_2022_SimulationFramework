function ctrl = guidance_waypoints()
    ctrl = block_base(0, {'path', 'platform'}, @control);
    
    ctrl.graphicElements(end + 1).draw = @drawTargetPoint;
    ctrl.graphicElements(end).name = 'Current Target Point';
    
    ctrl.default_color = [0 0 1];
    ctrl.default_positionTolerance = 0.3;
    ctrl.default_relative = false; 
    
    
    function handles = drawTargetPoint(block, ax, handles, ~, ~, state, path, ~)   
        if isempty(handles); 
            handles = line('Parent', ax, 'XData', [], 'YData', [], 'Color', block.color, 'LineStyle', 'none', 'Marker', 'o', 'MarkerSize', 10);
        end
        if ~isempty(state) && ~isempty(path);            
            path = path(end).data;
            if state.targetPointIndex >= 1 && state.targetPointIndex <= size(path, 1);
                set(handles, 'XData', path(state.targetPointIndex, 1), 'YData', path(state.targetPointIndex, 2));
                return;
            end
        end
        set(handles, 'XData', [], 'YData', []);
    end

    function [state, out, debugOut] = control(block, ~, state, path, poseProvider)
        debugOut = [];
        out = [0; 0]; % default output
        
        if ~isempty(path) && ~isempty(poseProvider)
            path = path(end).data;
            if isempty(state)
                % initialize state on the arrival of the first pose input
                state = struct();
                state.targetPointIndex = 1;
            end
            
            pose = poseProvider(end).data;


            if state.targetPointIndex < size(path, 1)
                dist = sqrt(sum([path(state.targetPointIndex, 1) - pose(1), path(state.targetPointIndex, 2) - pose(2)].^2));
                if dist <= block.positionTolerance
                    state.targetPointIndex = state.targetPointIndex + 1;                        
                end
            end

            if state.targetPointIndex <= size(path, 1)
                out = [path(state.targetPointIndex, 1); path(state.targetPointIndex, 2)];
                if block.relative; out = [cos(pose(3)), sin(pose(3)); -sin(pose(3)), cos(pose(3))] * (out - [pose(1); pose(2)]); end
            end
        end        
    end
end

