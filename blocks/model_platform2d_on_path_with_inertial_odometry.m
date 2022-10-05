function model = model_platform2d_on_path(path)
    if ~isnumeric(path) || ~isreal(path) || length(size(path)) ~= 2 || size(path, 2) ~= 2 || size(path, 1) < 2
        error('Invalid format: path should be an Nx2 matrix (with N >= 2)');
    end

    model = model_platform2d(@move, []);
    model.graphicElements(end + 1).draw = @drawPath;
    model.graphicElements(end).name = 'Path';
    
    model.default_v = -0.5;	% translational speed in m/s
    model.default_omega = 90 * pi / 180; % rotational speed in rad/s
    model.default_initialPose = [path(1, :), atan2(path(2, 2) - path(1, 2), path(2, 1) - path(1, 1))];
    model.firstTargetPoint = 2;
    model.startBackwards = false;
    model.default_odometryError = [0.005, 0.005, (0.5 * pi / 180)];	% stddev for odometry [m, m, rad]
    
    function handles = drawPath(block, ax, handles, ~, ~, ~)   
        if isempty(handles); 
			handles.path = line('Parent', ax, 'XData', [], 'YData', [], 'Color', block.color, 'LineWidth', 1);
            handles.start = line('Parent', ax, 'XData', [], 'YData', [], 'Marker', 'd', 'MarkerFaceColor', block.color, 'MarkerEdgeColor', block.color, 'MarkerSize', 10);
            handles.goal = line('Parent', ax, 'XData', [], 'YData', [], 'Marker', 'p', 'MarkerFaceColor', block.color, 'MarkerEdgeColor', block.color, 'MarkerSize', 20);
        end
        set(handles.path, 'XData', path(:, 1), 'YData', path(:, 2));
        set(handles.start, 'XData', path(1, 1), 'YData', path(1, 2));
        set(handles.goal, 'XData', path(end, 1), 'YData', path(end, 2));
    end

    function [state, out, debugOut] = move(block, t, state, varargin)
        debugOut = [];
        if isempty(state)
            state = struct();
            state.targetPoint = min(size(path, 1), block.firstTargetPoint);
            state.backwards = model.startBackwards;
            state.doTurn = true;
            state.lastT = 0.0;
            state.pose = block.initialPose;
        end
        
        if state.backwards; dir = -1; else dir = 1; end

        deltaT = t - state.lastT;
        state.lastT = t;
        v = abs(block.v);
        omega = abs(block.omega);
        pose = state.pose;

        while(deltaT > 0)
            delta = path(state.targetPoint, :) - pose(1:2);
            if all(delta == 0)
                % determine next point
                if all(path(1, :) == path(end, :))
                    % path closed -> circle
                    if dir == 1,
                        if state.targetPoint < size(path, 1)
                            state.targetPoint = state.targetPoint + 1;
                        else state.targetPoint = 2;
                        end
                    else
                        if state.targetPoint > 1
                            state.targetPoint = state.targetPoint - 1;
                        else state.targetPoint = size(path, 1) - 1;
                        end
                    end		
                else
                    % path not closed -> toggle between start and end point
                    if dir == 1,
                        if state.targetPoint < size(path, 1)
                            state.targetPoint = state.targetPoint + 1;
                        else
                            state.backwards = ~state.backwards;
                            state.targetPoint = size(path, 1) - 1;
                        end
                    else
                        if state.targetPoint > 1,
                            state.targetPoint = state.targetPoint - 1;
                        else
                            state.backwards = ~state.backwards;
                            state.targetPoint = 2;
                        end
                    end
                end
                state.doTurn = true;
                delta = path(state.targetPoint, :) - pose(1:2);
            end

            if state.doTurn
                % adjust heading towards target point
                % compute angle difference \in (-pi, pi]
                destAngle = atan2(delta(2), delta(1));
                deltaAngle = mod(destAngle - pose(3), 2 * pi);
                if deltaAngle > pi, deltaAngle = deltaAngle - 2 * pi; end

                tWholeTurn = abs(deltaAngle) / omega;
                if tWholeTurn > deltaT,
                    pose(3) = pose(3) + deltaT * omega * sign(deltaAngle);
                    deltaT = 0;
                else
                    % remaining angle difference can be removed completely within this time step
                    pose(3) = destAngle;
                    deltaT = deltaT - tWholeTurn;
                    state.doTurn = false;
                end			
            else
                % approach target point
                distance = norm(delta);
                tWholeDistance = distance / v;
                if tWholeDistance > deltaT, 				
                    % remaining distance cannot be travelled completely in deltaT
                    pose(1:2) = pose(1:2) + deltaT * v / distance * delta;
                    deltaT = 0;
                else
                    % remaining distance can be completely travelled within
                    % this time step
                    pose(1:2) = path(state.targetPoint, :);
                    deltaT = deltaT - tWholeDistance;
                end
            end	
        end
        
        delta_noisy = pose - state.pose + block.odometryError .* randn(1, 3);
        state.pose = [pose(1:2), mod(pose(3) + pi, 2 * pi) - pi];        
        
        out = state.pose;
    end    
end

