% Test Environment for ground robot equipped with a differential drive
% locomotion system
% The chain of relevant blocks is 
%
%    controller -> robot (kinematic model) -> sink
%
function exp = exp_ddrive_test(varargin) 
    % Instantiate an empty experiment
    exp = experiment_base('ddrive_test');
    
    % Add an environment map (serves as a background image)
    exp.environment = grp_obstacles_and_landmarks_from_image('../maps/emptyroom.png', 'scale', 0.01);
    
    % Instantiate the robot
    exp.robot.platform = model_platform2d_ddrive([2 0.75 90*pi/180]);
    %exp.robot.platform.wheelRadius = [0.030 0.0303];    
    %exp.robot.platform.wheelDistance = 0.255;
    exp.robot.radius = 0.14;
    exp.robot.color = [0 0 1];
    exp.robot.wheelRadius = 0.03;
    exp.robot.wheelDistance = 0.25;   
    
    % Add rangefinder
%     exp.robot.sensor = sensor_rangefinder2d();
    
    % add a sink to convince the simulator engine, that the robot is used.
    % Otherwise the engine would 'optimize' the robot away
    exp.robot.sink = block_sink('platform');
    
    % If you have a gamepad or joystick at hand you can steer your robot
    % interactively by setting useGamepad to true
    useGamepad = false;
    if useGamepad
        % You probably have to modify the axis mappings and directions to
        % fit your device
        mappings(1).axis = 5;
        mappings(1).range = 720 * pi / 180 * [1 -1];
        mappings(2).axis = 2;
        mappings(2).range = 720 * pi / 180 * [1 -1];        
        exp.robot.controller = input_gamepad(mappings');
    else
        % Otherwise, use a controller that make the robot move on a square 
        % path
        exp.robot.controller = guidance_ddrive_square();
        exp.robot.controller.length = 4;
    end
    
    
%     exp.robot2.platform = model_platform2d_omni([2.5 3 90*pi/180]);
%     exp.robot2.radius = 0.14;
%     exp.robot2.color = [0.5 0 1]; % Farbe setzen
%     exp.robot2.sink = block_sink('platform');
%     exp.robot2.controller = guidance_omni_circle();
%     exp.robot2.controller.radius = 1.5;
%     exp.robot2.controller.rotVelocity = 20*pi/180;
    
    % The 'depends' field controls, which blocks should not be optimized
    % away, even if their outputs are unused.
    % (Note: This mechanism does not work with continuous blocks like the 
    % robot. Therefore we had to add the sink above, which is discrete and
    % can be put into the depends list)
	exp.depends = {'*sink', '*environment*'};
%     exp.depends{end + 1} ='*sensor'; 
    
    % Some parameters that influence the appereance of the display area
    exp.display.settings = {'XGrid', 'on', 'YGrid', 'on', 'Layer', 'top', 'XLim', [0 8], 'YLim', [0 6]};
end