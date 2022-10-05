% This block implements the common behaviour of a localization algorithm 
% for a ground robot, i. e. common parameters and the visualization, but 
% not the actual algorithm. The block should be used as a "base class" by 
% instantiating it and passing the localization algorithm as a function 
% handle. 
% The expected format are block inputs are
% - first input: a struct with field .pose = [r_x; r_x; phi]
% - number and type of further inputs is irrelevant
% The expected output format is a struct with fields
% - .pose = [r_x; r_y; phi] (mean of pose probability distribution)
% - .cov = 3x3 covariance matrix of .pose

function filter = filter_localization2d(processFunction)
    filter = block_base('sensors/landmark_detector', {'platform', 'sensors/landmark_detector', 'environment/landmarks'}, processFunction);
    filter.default_color = [0 0 1];    
    
    filter.graphicElements(end + 1).draw = @drawPose;
    filter.graphicElements(end).name = 'estimated Pose';    
    
    filter.graphicElements(end + 1).draw = @drawTrack;    
    filter.graphicElements(end).name = 'Track';
    filter.graphicElements(end).useLogs = true;
    
    filter.default_sigmaScale = 3;
    filter.default_radius = 0;
    
    filter.default_useBearing = true;
    filter.default_useRange = true;

    filter.default_initialPose = [];
    filter.default_initialPoseError = [0.005, 0.005, 1 * pi / 180];
    filter.default_odometryError = [0.005, 0.005, 0.5 * pi / 180];
    filter.default_bearingError = 5 * pi / 180;
    filter.default_rangeError = 1 / 100;       
    
    filter.log.uniform = true;
    
    function handles = drawTrack(block, ax, handles, iteration, times, out, debugOut, states, varargin)
        if isempty(handles)
            handles = line('Parent', ax, 'XData', [], 'YData', [], 'Color', block.color, 'LineStyle', '--');
        end
        track = reshape([out(1:iteration).pose], 3, []);
        set(handles, 'XData', track(1, :), 'YData', track(2, :));
    end        
    
    function handles = drawPose(block, ax, handles, out, debugOut, state, varargin)        
        if isempty(handles) 
            handles.ellipse = patch('Parent', ax, 'XData', [], 'YData', [], ...
									'FaceColor', block.color, 'FaceAlpha', 0.5, ...
                                    'EdgeColor', block.color);
            handles.pie = patch('Parent', ax, 'XData', [], 'YData', [], 'FaceColor', 0.3 * block.color, 'FaceAlpha', 0.5, 'EdgeColor', 0.3 * block.color);
        end
                
        % error ellipse
        [eigvec, eigval] = eig(out.cov(1:2, 1:2));
        t = linspace(0, 2 * pi, 20);
        XY = [cos(t'), sin(t')] * diag(block.radius + block.sigmaScale * sqrt(diag(eigval))) * eigvec' + ...
             repmat([out.pose(1), out.pose(2)], length(t), 1);

		set(handles.ellipse, 'XData', XY(:, 1), 'YData', XY(:, 2));

        % pie slice for visualizing orientation error
        range = out.pose(3) + block.sigmaScale * sqrt(out.cov(3, 3)) * [-1 1];
        t = linspace(range(1), range(2), 10);				
        pieLength = block.radius * 3;
        set(handles.pie, 'XData', out.pose(1) + [0, pieLength * cos(t)], ...
                         'YData', out.pose(2) + [0, pieLength * sin(t)]);
    end
end
