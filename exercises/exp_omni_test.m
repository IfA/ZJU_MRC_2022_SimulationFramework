% Test Environment for an omnidirectional ground robot
%
% The chain of relevant blocks is 
%
%    controller -> robot (kinematic model) -> sink
%
function exp = exp_omni_test(varargin) 
    % Instantiate an empty experiment
    exp = experiment_base('omni_test');
    
    % Add an environment map (serves as a background image)
    exp.environment = grp_obstacles_and_landmarks_from_image('../maps/emptyroom.png', 'scale', 0.01);
    
    % Instantiate the robot
    exp.robot.platform = model_platform2d_omni([2 2.5 90*pi/180]);
    exp.robot.radius = 0.14;
	exp.robot.color = [0 0 1];
    
    % add a sink to convince the simulator engine, that the robot is used.
    % Otherwise the engine would 'optimize' the robot away    
    exp.robot.sink = block_sink('platform');
    
    % If you have a gamepad or joystick at hand you can steer your robot
    % interactively by setting useGamepad to true
    useGamepad = false;
    if useGamepad
        % You probably have to modify the axis mappings and directions to
        % fit your device
        mapping(1).axis = 2;
        mapping(1).range = [0.5 -0.5]; % left stick up/down, v_x = -0.5...0.5 m/s
        mapping(2).axis = 1;
        mapping(2).range = [0.5 -0.5];  % left stick left/right, v_y = -0.5...0.5 m/s
        mapping(3).axis = 4;
        mapping(3).range = 45 * pi / 180 * [1 -1]; % right stick left/right, omega = -45...45 deg/s
        exp.robot.controller = input_gamepad(mapping');
    else
        % Otherwise, use a controller that make the robot move on a square 
        % path
        exp.robot.controller = guidance_omni_circle();
        exp.robot.controller.radius = 2;
        exp.robot.controller.rotVelocity = 20 * pi / 180;
    end
    
    % The 'depends' field controls, which blocks should not be optimized
    % away, even if their outputs are unused.
    % (Note: This mechanism does not work with continuous blocks like the 
    % robot. Therefore we had to add the sink above, which is discrete and
    % can be put into the depends list)
	exp.depends = {'*sink', '*environment*'};
    
    % Some parameters that influence the appereance of the display area
    exp.display.settings = {'XGrid', 'on', 'YGrid', 'on', 'Layer', 'top', 'XLim', [0 8], 'YLim', [0 6]};
end