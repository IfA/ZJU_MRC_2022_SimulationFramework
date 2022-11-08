% Localization algorithm for a Differential Drive Mobile Robot based
% on the Extended Kalman Filter (EKF)

function filter = filter_ddrive_ekf()
    filter = filter_localization2d(@filterStep); % reuse drawing function from generic localization2d block     
    filter.depends = {'sensors/odometer', 'sensors/landmark_detector', 'environment/landmarks'};
    
    filter.default_initialPose = [0 0 0]';
    filter.default_initialPoseCov = zeros(3, 3);
    
    filter.default_odometryError = 5 * pi / 180;    % sigma of assumed odometer uncertainty in rad/s
    filter.default_wheelRadiusError = 1e-3;         % sigma of assumed wheel diameter uncertainty in m
    filter.default_wheelDistanceError = 5e-3;       % sigma of assumed wheel distance uncertainty in m
    filter.default_bearingError = 5 * pi / 180;     % sigma of assumed bearing error in rad
    filter.default_rangeError = 2 / 100;            % sigma of assumed range error in percent of the aquired distance value
    
end

function [state, out, debugOut] = filterStep(block, t, state, odometer, sensor, landmarks)
    debugOut = [];

    if isempty(state)            
        % Initialization
        state.pose = block.initialPose(:);
        state.cov = block.initialPoseCov;
        state.lastInput = [0; 0]; % initial speed is zero
        state.t = 0;
    end

    % use shorter symbols 
    x = state.pose;
    P = state.cov;
    u = state.lastInput;
    tNow = state.t;

    iPredict = 1;
    iUpdate = 1;

    while tNow < t
        % determine, which measurement to proceed next
        if iUpdate <= length(sensor)
            tNextUpdate = sensor(iUpdate).t;
        else tNextUpdate = t;
        end            
        while tNow < tNextUpdate
            if iPredict <= length(odometer)
                tNext = odometer(iPredict).t;
                if tNext <= tNextUpdate
                    [x, P] = doPrediction(x, P, u, tNext - tNow);
                    tNow = tNext;           
                    u = odometer(iPredict).data(:);
                    iPredict = iPredict + 1;
                else break;
                end
            else break;    
            end
        end

        if tNow < tNextUpdate
            [x, P] = doPrediction(x, P, u, tNextUpdate - tNow);
            tNow = tNextUpdate;
        end

        if iUpdate <= length(sensor)                
            [x, P] = doUpdate(x, P, sensor(iUpdate).data, landmarks.data);
            iUpdate = iUpdate + 1;
        end
    end

    % put short-named intermediate variables back into the filter state
    state.pose = x;
    state.cov = P;
    state.lastInput = u;
    state.t = tNow;

    % the output of the localization filter is the estimated state (=pose) vector 
    out.pose = x;  
    out.cov = P;

    function [x, P] = doPrediction(x, P, u, T)
        % Implementation of the prediction step

        % get the model parameters 
        if numel(block.wheelRadius) == 1
            R_R = block.wheelRadius;
            R_L = block.wheelRadius;
        else
            R_R = block.wheelRadius(1);
            R_L = block.wheelRadius(2);
        end
        a = block.wheelDistance / 2;

        dtheta_R = u(1);
        dtheta_L = u(2);

        % TODO: implement the prediction step
        
        
    end

    function [x, P] = doUpdate(x, P, meas, landmarks)
        % Implementation of the update step
        visIdx = meas.lmIds; % assume we can associate each measurement with a known landmark
        if isempty(visIdx); return; end

        beta = meas.bearing;
        d = meas.range;                        
        m = landmarks(visIdx, :);
                               
        % TODO: implement the update step
        
        
    end
end

