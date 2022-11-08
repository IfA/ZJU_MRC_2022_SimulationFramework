% Experiment setup for Exercise 2: 
% Extende Kalman Filter based localization of a Differential Drive Mobile
% Robot
function exp = exp_ekf_ddrive() 
    exp = experiment_base('ddrive_ekf');
    
    % Some configuration options for the experiment
    useEmptyRoom = true;
    useFilterPose = true;
        
    if useEmptyRoom
        % Prepare map and (rectangular) path for empty-room experiment setup
        exp.environment = grp_obstacles_and_landmarks_from_image('../maps/emptyroom.png', 'scale', 0.01);
        pathPoints = [2.00, 0.75; ...
                      2.00, 4.75; ...
                      6.00, 4.75; ...
                      6.00, 0.75; ...
                      2.00, 0.75];
    else
        % Prepare map and path for office environment experiment setup
        exp.environment = grp_obstacles_and_landmarks_from_image('../maps/office.png', 'scale', 0.01);    
        pathPoints = [1.00,   0.50;...
                      1.00, 4.30;...
                      2.60, 4.30;...
                      2.60, 2.70;...
                      6.00, 2.70;... 
                      6.00, 5.10;...
                      7.00, 5.10;...
                      6.00, 5.10;...
                      6.00, 3.30;...
                      7.50, 2.70;...
                      7.50, 0.75;...
                      5.00, 1.50;...
                      2.00, 1.50;...
                      2.00, 0.50];
    end
    
    % The first path point is used as initial pose
    exp.robot.initialPose = [pathPoints(1, :), 90 * pi / 180];
    
    % instantiate the platform (differential drive) and set its parameters
    exp.robot.platform = model_platform2d_ddrive();
    exp.robot.radius = 0.14;
    exp.robot.color = [0 0 1];
    exp.robot.wheelRadius = [0.03 0.03];
    exp.robot.wheelDistance = 0.25;    
        
    % add the controller (which uses the 'platform' as input by default)
    exp.robot.controller = controller_ddrive_follow_path(pathPoints);
    if useFilterPose
        exp.robot.localizationPose = block_extract('localization', 'pose');
        exp.robot.controller.depends = {'localizationPose'};
    end    
    
    % add the sensors
    exp.robot.sensors.odometer = sensor_odometer_wheelspeed();
    exp.robot.odometryError = 10 * pi / 180;        
    
    exp.robot.sensors.landmark_detector = sensor_landmarks2d();
    exp.robot.sensors.range = 7;
    exp.robot.sensors.fieldOfView = 70 * pi / 180 * [-1 1];
    exp.robot.bearingError = 5 * pi / 180;
    exp.robot.rangeError = 2 / 100;    
    
    % ...and finally the localization filter
    % (variant 1: prediction using ODE45; linearize, then discretize; use
    % cartesian measurements)
    exp.robot.localization = filter_ddrive_ekf();   
    exp.robot.localization.useNumericPrediction = true;
    exp.robot.localization.useExactDiscretization = false;
    exp.robot.localization.useCartesianSensor = false;
    exp.robot.localization.useRange = true;
    exp.robot.localization.useBearing = true;
    
    % (variant 2: analytic prediction, exact discretization, followed by
    % linearization, range+bearing measurements)
    exp.robot.localization2 = filter_ddrive_ekf();   
    exp.robot.localization2.useNumericPrediction = false;
    exp.robot.localization2.useExactDiscretization = true;
    exp.robot.localization2.useCartesianSensor = false;
    exp.robot.localization2.useRange = true;
    exp.robot.localization2.useBearing = true;
    exp.robot.localization2.color = [1 0 0];
    
    % (This is only required when useFilterPose = false)
	exp.depends = {'*localization', '*localization2'};

    
    exp.display.title = 'Differential Drive with EKF-based fusion of dead reckoning and a landmark sensor';       
    exp.display.settings = {'XGrid', 'on', 'YGrid', 'on', 'Layer', 'top', 'XLim', [0 8], 'YLim', [0 6]};
end