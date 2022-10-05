function guidance = guidance_dwa2d()
    guidance = block_base('sensors/rangefinder', {'platform', 'goal', 'sensors/rangefinder'}, @dwaStep);

    % core DWA related parameters
    guidance.default_vMin = 0;                  % min. translational velocity [m / s]
    guidance.default_vMax = 1;                  % max. translational velocity [m / s]
    guidance.default_omegaMin = -90 * pi / 180; % min. angular velocity [rad / s]
    guidance.default_omegaMax = 90 * pi / 180;  % max. angular velocity [rad / s]
    guidance.default_accV = 2;                  % translational acceleration/deceleration [m / s^2]
    guidance.default_accOmega = 180 * pi / 180; % angular acceleration/deceleration [rad / s^2]
    guidance.default_weights = [5 1 0.2 1];     % weight factors: [heading, obstacle distance, velocity, approach]
    guidance.default_maxDistanceCare = 0.7;     % upper limit for obstacle distance utility [m]
    
    % obstacle line field related parameters
    guidance.default_safetyMargin = 0.05;       % additional clearance between robot & obstacles [m]
    guidance.default_radius = 0.1;              % robot radius (usually overwritten in experiment file [m]
    
    guidance.default_showAllCollisionPoints = false; % set to true, to visualize all collision distances (e. g. to verify your calculation of the collision distance)
                                                     % by default (false) the collision distances are only visualized for non-admissible candidates 
    
                                                     
    guidance.graphicElements(end + 1).draw = @drawObstacleLines;
    guidance.graphicElements(end).name = 'Obstacle Lines';
    guidance.graphicElements(end).hideByDefault = true;
    guidance.graphicElements(end + 1).draw = @drawTrajCandidates;
    guidance.graphicElements(end).name = 'Candidate Trajectories';    
    guidance.graphicElements(end + 1).draw = @drawSelectedTrajectory;
    guidance.graphicElements(end).name = 'Selected Trajectory';
    
    guidance.figures(end + 1).name = 'DWA Internals';
    guidance.figures(end).icon = fullfile(fileparts(mfilename('fullpath')), 'radar.png');
    guidance.figures(end).init = @createFigure;
    guidance.figures(end).draw = @updateFigure;                
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % visualization functions for the main window
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    function handles = drawObstacleLines(block, ax, handles, out, debugOut, state, platform, varargin)        
        if isempty(handles) 
            handles = line('Parent', ax, 'XData', [], 'YData', [], 'Color', [1 0 1]);
        end
        if ~isempty(debugOut) && ~isempty(platform)                        
            lineData = debugOut.obstacleLines;
            pose = platform(end).data;
            
            N_obst = size(lineData, 1);
            R_mat = [cos(pose(3)), -sin(pose(3)); sin(pose(3)), cos(pose(3))];
            
            transformedLineData = repmat([pose(1), pose(2)], N_obst, 2) + lineData * blkdiag(R_mat.', R_mat.');            
            
            set(handles, 'XData', reshape([transformedLineData(:, [1 3]).'; NaN(1, N_obst)], 1, []), ...
                         'YData', reshape([transformedLineData(:, [2 4]).'; NaN(1, N_obst)], 1, []));
        else set(handles, 'XData', [], 'YData', []);
        end
    end      

    function handles = drawTrajCandidates(block, ax, handles, out, debugOut, state, platform, varargin)        
        if isempty(handles) 
            handles.curves = line('Parent', ax, 'XData', [], 'YData', [], 'Color', [0 0.8 0]);            
            handles.minDist = line('Parent', ax, 'XData', [], 'YData', [], 'Color', [1 0 0], 'LineWidth', 2);                    
        end
        if ~isempty(debugOut) && ~isempty(platform)
            pose = platform(end).data;
            R_mat = [cos(pose(3)), -sin(pose(3)); sin(pose(3)), cos(pose(3))];
            
            N_candidates = numel(debugOut.omegas);
            curvePts = zeros(0, 2);
            for i = 1:N_candidates
                v = debugOut.velocities(i);
                omega = debugOut.omegas(i);

                if i > 1; curvePts = [curvePts; NaN, NaN]; end

                if omega ~= 0
                    % curve
                    R = v / omega;
                    arcs = linspace(0, 5 * pi/4, min(225, max(10, 12.5 * pi * abs(R)))).';                    
                    curvePts = [curvePts; [sign(v) * abs(R) * sin(arcs), R * (1 - cos(arcs))]];                    
                else
                    % straight line
                    curveLength = v * 2;
                    curvePts = [curvePts; 0, 0; curveLength, 0];
                end            

            end
            curvePts = repmat([pose(1), pose(2)], size(curvePts, 1), 1) + curvePts * R_mat.';
            set(handles.curves, 'XData', curvePts(:, 1), 'YData', curvePts(:, 2));
 
            curvePts = zeros(0, 2);
            for i = 1:N_candidates
                if block.showAllCollisionPoints || ~debugOut.admissibleCandidates(i)
                    d_coll = debugOut.minDists(i);
                    v = debugOut.velocities(i);
                    omega = debugOut.omegas(i);
                    if isfinite(d_coll)
                        if size(curvePts, 1) > 0; curvePts = [curvePts; NaN, NaN]; end
                        if omega == 0
                            lineLength = sign(v) * d_coll;
                            curvePts = [curvePts; 0, 0; lineLength, 0];
                        else
                            R = v / omega;
                            arcs = linspace(0, d_coll / abs(R), min(360, max(10, d_coll / 0.1))).';
                            curvePts = [curvePts; [sign(v) * abs(R) * sin(arcs), R * (1 - cos(arcs))]];
                        end
                    end
                end                   
            end
            
            curvePts = repmat([pose(1), pose(2)], size(curvePts, 1), 1) + curvePts * R_mat.';
            set(handles.minDist, 'XData', curvePts(:, 1), 'YData', curvePts(:, 2));
            
        else set([handles.curves, handles.minDist], 'XData', [], 'YData', []);
        end
    end

    function handles = drawSelectedTrajectory(block, ax, handles, out, debugOut, state, platform, varargin)
        if isempty(handles)
            handles = line('Parent', ax, 'XData', [], 'YData', [], 'Color', [0 0.5 0], 'LineWidth', 2);
        end
        
        if ~isempty(debugOut) && ~isempty(platform)
            pose = platform(end).data;
            R_mat = [cos(pose(3)), -sin(pose(3)); sin(pose(3)), cos(pose(3))];
            
            v = out(1);
            omega = out(2);
            
            if omega ~= 0 % curve
                R = v / omega;
                arcs = linspace(0, 5 * pi/4, min(225, max(10, 12.5 * pi * abs(R)))).';                    
                curvePts = [sign(v) * abs(R) * sin(arcs), R * (1 - cos(arcs))];                    
            else % straight line
                curveLength = v * 2;
                curvePts = [0, 0; curveLength, 0];
            end            
            
            curvePts = repmat([pose(1), pose(2)], size(curvePts, 1), 1) + curvePts * R_mat.';
            set(handles, 'XData', curvePts(:, 1), 'YData', curvePts(:, 2));
        else set(handles, 'XData', [], 'YData', []);
        end
    end

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % functions for the extra visualization window
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    function [f, diag] = createFigure(block, blockName)
        f = figure('Name', ['DWA Internals for ' blockName], 'NumberTitle', 'off');
        diag.axVelocity = axes('Parent', f, 'OuterPosition', [0, 1/3, 1/2, 2/3]);
        set(diag.axVelocity, 'XGrid', 'on', 'YGrid', 'on', 'Layer', 'top', ...
                             'XLim', ([block.omegaMin block.omegaMax] * 180 / pi) + [-10 10], 'XDir', 'reverse', ...
                             'YLim', [block.vMin - 0.1, block.vMax + 0.1]);
        xlabel('omega [deg/s]');
        ylabel('velocity [m/s]');
        title('Dynamic Window');
        rectangle('Parent', diag.axVelocity, 'FaceColor', 0.8 * [1 1 1], 'EdgeColor', 0.2 * [1 1 1], ...
                  'Position', [block.omegaMin * 180 / pi, block.vMin, (block.omegaMax - block.omegaMin) * 180 / pi, block.vMax - block.vMin]);
        
        diag.dynWindowRect = rectangle('Position', [0 0 eps eps], 'FaceColor', [1 1 1], 'EdgeColor', [0 0 0]);
        diag.candidateMarkers = line('XData', [], 'YData', [], 'Marker', '.', 'Color', [0 0.8 0], 'LineStyle', 'none');
        diag.invalidCandidateMarkers = line('XData', [], 'YData', [], 'Marker', '.', 'Color', [1 0 0], 'LineStyle', 'none');
        diag.velocityMarker = line('XData', [], 'YData', [], 'Marker', 'x', 'MarkerSize', 15, 'Color', [0 1 1], 'LineWidth', 2);        
        diag.selectedVelocityMarker = line('XData', [], 'YData', [], 'Marker', 'o', 'MarkerSize', 10, 'Color', 0.5 * [0 1 1], 'LineWidth', 2);
        
        
        diag.axHeadingUtility = axes('Parent', f, 'OuterPosition', [0, 0, 1/4, 1/3], 'XDir', 'reverse');
        diag.headingSurf = surf('XData', [], 'YData', [], 'ZData', []);
        title('Heading Utility');
        set(diag.axHeadingUtility, 'ZLim', [0 1], 'ZLimMode', 'manual');

        diag.axDistUtility = axes('Parent', f, 'OuterPosition', [1/4, 0, 1/4, 1/3], 'XDir', 'reverse');
        diag.distSurf = surf('XData', [], 'YData', [], 'ZData', []);
        title('Obstacle Clearance Utility');
        set(diag.axDistUtility , 'ZLim', [0 1], 'ZLimMode', 'manual');
        
        diag.axVelocityUtility = axes('Parent', f, 'OuterPosition', [2/4, 0, 1/4, 1/3], 'XDir', 'reverse');
        diag.velocitySurf = surf('XData', [], 'YData', [], 'ZData', []);
        title('Velocity Utility');
        set(diag.axVelocityUtility, 'ZLim', [0 1], 'ZLimMode', 'manual');

        diag.axApproachUtility = axes('Parent', f, 'OuterPosition', [3/4, 0, 1/4, 1/3], 'XDir', 'reverse');
        diag.approachSurf = surf('XData', [], 'YData', [], 'ZData', []);
        title('Approach Utility');
        set(diag.axApproachUtility, 'ZLim', [0 1], 'ZLimMode', 'manual');
        
        
        diag.axUtilitySum = axes('Parent', f, 'OuterPosition', [1/2, 1/3, 1/2, 2/3], 'XDir', 'reverse');
        diag.sumSurf = surf('XData', [], 'YData', [], 'ZData', []);
        title('Summed Utility');
        set(diag.axUtilitySum, 'ZLim', [0 sum(block.weights)], 'ZLimMode', 'manual');
        diag.maxUtilityMarker = line('XData', [], 'YData', [], 'ZData', [], 'Color', [1 0 0], 'LineWidth', 2);
    end
    function diag = updateFigure(block, f, diag, out, debugOut, state, varargin)
        if ~isempty(debugOut)            
            set(diag.headingSurf, 'XData', debugOut.omegas * 180 / pi, 'YData', debugOut.velocities, 'ZData', debugOut.utility_heading);            
            set(diag.distSurf, 'XData', debugOut.omegas * 180 / pi, 'YData', debugOut.velocities, 'ZData', debugOut.utility_dist);                    
            set(diag.velocitySurf, 'XData', debugOut.omegas * 180 / pi, 'YData', debugOut.velocities, 'ZData', debugOut.utility_velocity);            
            set(diag.approachSurf, 'XData', debugOut.omegas * 180 / pi, 'YData', debugOut.velocities, 'ZData', debugOut.utility_approach);            
            set(diag.sumSurf, 'XData', debugOut.omegas * 180 / pi, 'YData', debugOut.velocities, 'ZData', debugOut.utility_sum);            
            
            set(diag.maxUtilityMarker, 'XData', out(2) * 180 / pi * [1 1], 'YData', out(1) * [1 1], 'ZData', [0, sum(block.weights)]);            

            minOmega = debugOut.omegas(1, 1);
            maxOmega = debugOut.omegas(1, end);
            minV = debugOut.velocities(1, 1);
            maxV = debugOut.velocities(end, 1);
            set(diag.dynWindowRect, 'Position', [minOmega * 180 / pi, minV, (maxOmega - minOmega) * 180 / pi + eps, maxV - minV + eps]);                        
            
            
            set(diag.invalidCandidateMarkers, 'XData', debugOut.omegas(~debugOut.admissibleCandidates) * 180 / pi, ...
                                              'YData', debugOut.velocities(~debugOut.admissibleCandidates));
            set(diag.candidateMarkers, 'XData', debugOut.omegas(debugOut.admissibleCandidates) * 180 / pi, ...
                                       'YData', debugOut.velocities(debugOut.admissibleCandidates));                    
                                   
            set(diag.velocityMarker, 'XData', debugOut.prevState(3) * 180 / pi, 'YData', debugOut.prevState(2));                                   
            set(diag.selectedVelocityMarker, 'XData', out(2) * 180 / pi, 'YData', out(1));                        
        else
            set([diag.distSurf, diag.velocitySurf, diag.headingSurf, diag.sumSurf, diag.maxUtilityMarker], 'XData', [], 'YData', [], 'ZData', []);
            set([diag.invalidCandidateMarkers, diag.candidateMarkers, diag.velocityMarker, diag.selectedVelocityMarker], 'XData', [], 'YData', []);
            set(diag.dynWindowRect, 'Position', [0 0 eps eps]);
        end
    end

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Dynamic Window Approach implementation
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    function [state, out, debugOut] = dwaStep(block, t, state, ~, relativeGoal, rangefinder)
        if isempty(state)
            % block state is [t, v, omega]
            state = [t 0 0];
        end
        debugOut.prevState = state;
        
        if ~isempty(rangefinder) && ~isempty(relativeGoal) % there might be a circular references between this module and the platform, which can cause DWA to be compute before an actual pose has been initialized            
        
            T = t - state(1);       % timestep
            velocity = state(2);    % current translational velocity
            omega = state(3);       % current angular velocity
            
            % ===== Task 1 ================================================
            % Compute Obstacles Line Field from laser range data.
            
            % Laser Range data is provided as two column vectors            
            % - bearings are the ray angles, measured relative to the 
            % robot's orientation. The elements are monotonically 
            % increasing, i. e. rays are stored from right to left.
            bearings = rangefinder(end).data.bearing;
            % ranges are the measured obstacle distances. We immediately
            % subtract the desired minimum obstacle distance
            minDistance = block.radius + block.safetyMargin;
            ranges = rangefinder(end).data.range - minDistance;            
            % if a ray did not hit an obstacle within the measurement
            % range, the corresponding entry is set to inf. These rays will
            % not become an obstacle line later.
            invalidRays = ~isfinite(ranges);

            % Obstacle lines should be stored in a Nx4 matrix, where each
            % row contains the coordinates of the start and end point of
            % the obstacle line, i. e. [px py qx qy]
            deltaBearings = bearings(2:end) - bearings(1:(end - 1));            
            rayExtentRight = 0.5 * ranges .* tan([deltaBearings(1); deltaBearings]);
            rayExtentLeft = 0.5 * ranges .* tan([deltaBearings; deltaBearings(end)]);            

            ranges(invalidRays) = [];
            bearings(invalidRays) = [];
            rayExtentLeft(invalidRays) = [];
            rayExtentRight(invalidRays) = [];
            
            rayVectors = [ranges .* cos(bearings), ranges .* sin(bearings)];
            rayNormals = [-rayVectors(:, 2), rayVectors(:, 1)] ./ repmat(sqrt(sum(rayVectors.^2, 2)), 1, 2);            
            obstacleLines = [rayVectors + repmat(rayExtentLeft + minDistance, 1, 2) .* rayNormals, rayVectors - repmat(rayExtentRight + minDistance, 1, 2) .* rayNormals];
            
            debugOut.obstacleLines = obstacleLines; % Store obstacle Lines for visualization
            
            % ===== Task 2 ================================================
            % Determine the v/omega candidates
            
            % compute the limits of the dynamic window
            minV = max(velocity - T * block.accV, block.vMin);
            maxV = min(velocity + T * block.accV, block.vMax);
            minOmega = max(omega - T * block.accOmega, block.omegaMin);
            maxOmega = min(omega + T * block.accOmega, block.omegaMax);                    
            % Generate the candidates as two matrices 
            % - velocities and 
            % - omegas
            % Hint: use the 'meshgrid' function
            [omegas, velocities] = meshgrid(linspace(minOmega, maxOmega, 5), ...
                                            linspace(minV, maxV, 7));
            
            % prevent insanely large arcs by snapping tiny angular rates to
            % zero; store results for visualization
            omegas(abs(omegas) < 1e-4) = 0;
            debugOut.velocities = velocities;
            debugOut.omegas = omegas;                        
            
            % ===== Task 3 ================================================
            % Determine minimal collision distance for each v/omega pair
            % Note: You have to complete the function lineFieldMinDist at
            % the end of this file!
            szCandidates = size(velocities);
            d_coll = zeros(szCandidates);
            for i = 1:numel(velocities)
                d_coll(i) = lineFieldMinDist(velocities(i), omegas(i), obstacleLines);                
            end
                        
            % ===== Task 4 ================================================
            % Rule out non-admissible v/omega candidates
            
            % Assume the candidate v/omega pair is applied for one timestep
            % and compute the distance traveled.
            dNextStep = T * abs(velocities);
            % After one timestep, determine the required distance to
            % completely stop the robot (i. e. v -> 0 AND omega -> 0). For
            % simplification it is assumed that the arc radius stays
            % constant during the deceleration phase.
            dDeceleration = max(velocities.^2 / (2 * block.accV), abs(velocities .* omegas) / (2 * block.accOmega));

            % admissible candidates require a collision distance larger
            % than the combined distance from the next timestep and the
            % deceleration phase.
            admissible = d_coll > (dNextStep + dDeceleration);
            
            debugOut.minDists = d_coll;
            debugOut.admissibleCandidates = admissible;
            
            % ===== Task 5 ================================================
            % Compute the components of the objective function.
            % Because of the visualization, this is done for all candidates 
            % (admissible and non-admissible ones)
            
            % ----- (a): Heading Utility ----------------------------------            
            % predict the location of the robot after
            % - using v/omega for one timestep and then
            % - reducing omega to zero
            % while keeping the arc radius constant.
            % Hint: Reuse dNextStep and dDeceleration from above!
            dPred = dNextStep + dDeceleration;
            phis = omegas ./ abs(velocities) .* dPred;
            phis(~isfinite(phis)) = 0;
            radii = velocities ./ omegas;
            X = radii .* sin(phis);
            Y = radii .* (1 - cos(phis));
            % correct results for omega = 0 (i. e. straight line motion)
            straight = (omegas == 0);            
            X(straight) = sign(velocities(straight)) .* dPred(straight);
            Y(straight) = 0;

            % compute relative target angle
            goal = relativeGoal(end).data;            
            thetas = abs(mod(atan2(goal(2) - Y, goal(1) - X) - phis + pi, 2 * pi) - pi);
            backwards = velocities < 0;
            thetas(backwards) = pi - thetas(backwards);
            utility_heading = 1 - (thetas / pi);
            
            % store for visualization
            debugOut.utility_heading = utility_heading; 
            
            % ----- (b): Obstacle Clearance Utility -----------------------
            % Use predicted obstacle distance after one timestep and the
            % deceleration phase
            utility_dist = min(1, max(d_coll - dNextStep - dDeceleration, 0) / block.maxDistanceCare);            
            
            % store for visualization
            debugOut.utility_dist = utility_dist; 
            
            % ----- (c): Velocity Utility ---------------------------------
            % The faster the robot, the better
            utility_velocity = abs(velocities) / block.vMax;

            % store for visualization
            debugOut.utility_velocity = utility_velocity; 
            
            % ----- (-): Approach Utility ---------------------------------                        
            % Use the predicted target pose after one timestep and the
            % deceleration phase (reuse X, Y) from 5a) to compute a
            % predicted goal distance. 
            % Then compute the reduction in goal distance for each v/omega 
            % candidate and form a utility value in the interval [0, 1]
            utility_approach = sqrt(goal(1).^2 + goal(2).^2) - sqrt((X - goal(1)).^2 + (Y - goal(2)).^2);            
            minApproach = min(min(utility_approach));
            maxApproach = max(max(utility_approach));
            if minApproach < maxApproach
               utility_approach = 0.5 + 0.5 * utility_approach / max(abs(minApproach), abs(maxApproach));               
            else utility_approach(:) = 0;
            end
            
            % store for visualization
            debugOut.utility_approach = utility_approach;

            % create summed utility function
            utility_sum = block.weights(1) * utility_heading + ...
                          block.weights(2) * utility_dist + ...
                          block.weights(3) * utility_velocity + ...
                          block.weights(4) * utility_approach;
            % optionally smooth the result
            %utility_sum = imfilter(utility_sum, fspecial('gaussian',[2 2],2), 'replicate', 'same');        
            % Drop non-admissible velocities
            utility_sum(~admissible) = 0;
            debugOut.utility_sum = utility_sum;
            
            % select the v/omega pair with the highest utility value
            [bestUtility, bestIndex] = max(reshape(utility_sum, [], 1));            
            if (bestUtility > 0)
                velocity = velocities(bestIndex);
                omega = omegas(bestIndex);
            else
                fprintf('No admissible velocity - applying maximum deceleration\n');
                velocity = sign(velocity) * max(0, abs(velocity) - block.accV * T);
                omega = sign(omega) * max(0, abs(omega) - block.accOmega * T);
            end
            
            state = [t, velocity, omega];            
        else debugOut = [];
        end
        out = state(2:3); % the block's output is [v, omega]
    end
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Determine the collision distance d_coll w.r.t. the obstacle line field on 
% a circular arc with radius v/omega or on a straight line (if omega = 0).
% Hint: set showAllCollisionPoints to true to verify your results visually!
function d_coll = lineFieldMinDist(v, omega, obstacles)
    d_coll = inf;
    
    % collision impossible, if the robot is not moving
    if v == 0; return; end    
    
    p = obstacles(:, [1 2]);
    D = obstacles(:, [3 4]) - p;    
    
    if omega == 0
        % Robot will move on a straight line
        slnObstacle = -p(:, 2) ./ D(:, 2);
        dists = sign(v) * (p(:, 1) + slnObstacle .* D(:, 1));
        isects = (slnObstacle >= 0 & slnObstacle <= 1 & dists >= 0);
        if any(isects)
            d_coll = min(dists(isects));
        end
    else
        % Robot will move on an arc of radius v/omega 
        % Note: both v and omega may be negative, therefore R may be negative, too!        
        R = v / omega;

        % The following solution covers all 4 combinations of positive or 
        % negative v and positive or negative omega
                
        p_times_p = sum(p.^2, 2);
        D_times_D = sum(D.^2, 2);
        p_times_D = sum(p .* D, 2);        
        
        % we are solving a quadratic equation here, which is only solvable,
        % if the expression under the square root is >= 0
        rootTerm = (p_times_D - R * D(:, 2)).^2 - D_times_D .* (p_times_p - 2 * R * p(:, 2));
        solvable = rootTerm >= 0;
        
        % throw away all rows without a non-complex solution
        p = p(solvable, :);
        D = D(solvable, :);
        p_times_D = p_times_D(solvable);
        D_times_D = D_times_D(solvable);
        
        rootTerm = sqrt(rootTerm(solvable));
        
        % get the solutions (both solutions concatenated in 3rd dimension) 
        sln = cat(3, (R * D(:, 2) - p_times_D - rootTerm) ./ D_times_D, ...
                     (R * D(:, 2) - p_times_D + rootTerm) ./ D_times_D);
        
        % corresponding coordinates as N (number of obstacles) x 2 (x/y coordinates) x 2 (two solutions) array
        xy = cat(3, p + repmat(sln(:, :, 1), 1, 2) .* D, p + repmat(sln(:, :, 2), 1, 2) .* D);
        
        % resulting 'position' (angle) on the circular arc as N (number of obstacles) x 1 x 2 (to solutions) array 
        % We need the arc angle in the range [0, 2pi)
        phi = mod(atan2(sign(v) * xy(:, 1, :), sign(R) * (R - xy(:, 2, :))), 2 * pi);
        % mask pseudo-solutions outside the limits of the corresponding obstacle line
        phi(sln < 0 | sln > 1) = inf;        
        % find the arc angle of the closer solution per obstacle line
        phi = min(phi, [], 3);
        % find the arc closest solution across all obstacle lines
        minPhi = min(phi);
        if isfinite(minPhi)
            % if the resulting arc angle is finite, an actual intersection
            % was found, the distance d_coll is the corresponding arc length 
            d_coll = abs(R) * minPhi; 
        end
    end
end
