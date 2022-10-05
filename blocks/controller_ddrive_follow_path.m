function ctrl = controller_ddrive_follow_path(path)
    if ~isnumeric(path) || ~isreal(path) || length(size(path)) ~= 2 || size(path, 2) ~= 2 || size(path, 1) < 2
        error('Invalid format: path should be an Nx2 matrix (with N >= 2)');
    end

    ctrl = block_base(1/50, 'platform', @control);
    
    ctrl.graphicElements(end + 1).draw = @drawPath;
    ctrl.graphicElements(end).name = 'Path';
    
    ctrl.default_color = [0 0 1];
    ctrl.default_velocity = 0.5;        % translational speed in m/s
    ctrl.default_omega = 90 * pi / 180; % rotational speed in rad/s
    
    ctrl.default_firstTargetPoint = 1;
    ctrl.default_startBackwards = false;
    ctrl.default_K_rot = 10;
    
    function handles = drawPath(block, ax, handles, ~, ~, state, varargin)   
        if isempty(handles); 
			handles.path = line('Parent', ax, 'XData', [], 'YData', [], 'Color', block.color, 'LineWidth', 1, 'Marker', '.');            
            handles.nextPoint = line('Parent', ax, 'XData', [], 'YData', [], 'Color', block.color, 'LineStyle', 'none', 'Marker', 's', 'MarkerSize', 8);
        end
        set(handles.path, 'XData', path(:, 1), 'YData', path(:, 2));
        pathPt = [];
        if ~isempty(state);
            if state.targetPointIndex <= size(path, 1)
                pathPt = path(state.targetPointIndex, :);
            end
        end
        if ~isempty(pathPt)
            set(handles.nextPoint, 'XData', pathPt(1), 'YData', pathPt(2));
        else set(handles.nextPoint, 'XData', [], 'YData', []);
        end
    end

    function [state, out, debugOut] = control(block, ~, state, input)
        debugOut = [];
        if isempty(state)
            if isempty(input)
                out = [0; 0];
                return;
            end
            
            % initialize state on the arrival of the first pose input
            state = struct();
            state.pose = input(end).data;
            state.targetPointIndex = min(size(path, 1), block.firstTargetPoint);
            targetPt = path(state.targetPointIndex, :);
            state.targetPose = [targetPt(1), targetPt(2), mod(atan2(targetPt(2) - state.pose(2), targetPt(1) - state.pose(1)) + pi, 2 * pi) - pi].';
            state.backwards = block.startBackwards;        
        elseif ~isempty(input)
            state.pose = input(end).data;
        end
        
        pose = state.pose;            
        targetPose = state.targetPose;
        targetVec = [cos(targetPose(3)); sin(targetPose(3))];
        % determine distance of projected position on line-to-target
        % from next target point
        posOnLine = targetVec.' * [pose(1) - targetPose(1); pose(2) - targetPose(2)];

        if posOnLine >= -0.01
            % Distance > 0 --> we are beyond the target point
            % (the condition also applies, if the target point is still slightly ahead of the robot) 
            % Switch to next target point
            if ~state.backwards
                state.targetPointIndex = state.targetPointIndex + 1;
                if state.targetPointIndex > size(path, 1)
                    if all(path(1, :) == path(end, :)) 
                        state.targetPointIndex = 2;
                    else
                        state.targetPointIndex = size(path, 1) - 1;
                        state.backwards = true;
                    end
                end
            else
                state.targetPointIndex = state.targetPointIndex - 1;
                if state.targetPointIndex == 0                    
                    if all(path(1, :) == path(end, :))
                        state.targetPointIndex = size(path, 1) - 1;
                    else
                        state.targetPointIndex = 2;
                        state.backwards = false;
                    end
                end
            end
            targetPt = path(state.targetPointIndex, :);
            targetPose = [targetPt(1); targetPt(2); mod(atan2(targetPt(2) - targetPose(2), targetPt(1) - targetPose(1)) + pi, 2 * pi) - pi];                
            state.targetPose = targetPose;
        end

        % Determine orientation difference between robot and line-of-sight
        % to next target point
        diffAngle = mod(atan2(targetPose(2) - pose(2), targetPose(1) - pose(1)) - pose(3) + pi, 2 * pi) - pi;
        if abs(diffAngle) > 5 * pi / 180
            % too much orientation difference --> turn on the spot
            vOmega = [0; sign(diffAngle) * block.omega];                
        else
            % approach target point, maybe with slight curvature to reduce
            % the remaining orientation error (proportional controller)
            vOmega = [block.velocity; diffAngle * block.K_rot];
        end
        
        % limit v/omega outputs
        if abs(vOmega(2)) > block.omega
            vOmega(2) = sign(vOmega(2)) * block.omega;
        end
        vOmega(1) = min(vOmega(1), block.velocity);
        
        % convert v/omega to [theta_R, theta_L]'
        if numel(block.wheelRadius) > 1
            R_right = block.wheelRadius(1);
            R_left = block.wheelRadius(2);
        else
            R_right = block.wheelRadius(1);
            R_left = block.wheelRadius(1);
        end
        out = [1 / R_right, 0.5 * block.wheelDistance / R_right; 1 / R_left, -0.5 * block.wheelDistance / R_left] * vOmega;                           
    end    
end

