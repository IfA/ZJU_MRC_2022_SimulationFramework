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
    
    filter.default_useCartesianSensor = false;      % if true, compute landmark positions (m_ix, m_iy) from range & bearing and use then as output measurements
                                                    % otherwise (the default), use range & bearing directly in the output equations (which allows to disable them individually)
    filter.default_useBearing = true;               % enable update from bearing measurements
    filter.default_useRange = true;                 % enable update from range measurements 
    
    
    filter.default_useNumericPrediction = false;    % do mean prediction using ode45
    filter.default_useExactDiscretization = false;  % if true: do exact discretization, followed by linearization for covariance propagation
                                                    % if false (the default), linearize first and then discretize using the matrix exponential 

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

        % to simplify the equations, we convert 
        % differential drive and convert our 'real' inputs to v/omega
        v = (R_R * dtheta_R + R_L * dtheta_L) / 2;
        omega = (R_R * dtheta_R - R_L * dtheta_L) / (2 * a);

        
        % some more abbreviations (see slides of exercise 3)
        phi = x(3);            
        sk = sin(phi);
        ck = cos(phi);
        skp1 = sin(phi + T * omega);
        ckp1 = cos(phi + T * omega);

        % do state prediction
        if block.useNumericPrediction
            % Use numeric integration
            % This is applicable to any nonlinear system            
            options = odeset('RelTol', 10^-13, 'AbsTol', eps);        
            [~, X] = ode45(@(t, x)vomega_model(x, v, omega), [0, T], x, options);
            x = (X(end, :)).';                
        else
            % exact solution
            if abs(omega) < 1e-12
                x = x + [v * T * ck; ...
                         v * T * sk; ...
                                       0];
            else
                x = x + [v / omega * (skp1 - sk); ...
                         v / omega * (ck - ckp1); ...
                         T * omega];
            end  
        end

        % do covariance prediction

        % input error covariance
        N = diag([block.odometryError^2, block.odometryError^2]);

        if ~block.useExactDiscretization
            % linearize first...
            A = [0, 0, -v * sk; ...
                 0, 0,  v * ck; ...
                 0, 0,       0];

            B = [ R_R / 2 * ck,   R_L / 2 * ck; ...
                  R_R / 2 * sk,   R_L / 2 * sk; ...
                 R_R / (2 * a), -R_L / (2 * a)];

            % ...then discretize using the matrix exponential
            F   = expm(A * T);

            I = eye(size(F));
            S = T * I;

            i = 2;
            while true
                D = T^i / factorial(i) * A^(i - 1);
                S = S + D;
                i = i + 1;
                if all(abs(D(:)) <= eps); break; end
            end
            H = S * B;

            P = F * P * F.' + H * N * H.';
        else
            % discretize first (only applicable, if ODEs can be solved
            % analytically), then linearize the discrete model

            if abs(omega) < 1e-12
                A_dis = [1, 0, -v * T * sk; ...
                         0, 1, v * T * ck; ...
                         0, 0, 1];
                B_dis = [R_R * T / 2 * ck, R_L * T / 2 * ck; ...
                         R_R * T / 2 * sk, R_L * T / 2 * ck; ...
                                        0,                0];
            else
                A_dis = [1, 0, v / omega * (ckp1 - ck); ...
                         0, 1, v / omega * (skp1 - sk); ...
                         0, 0,                       1];
                B_dis = [R_R / (2 * omega) * (v * T / a * ckp1 + R_L * dtheta_L / (a * omega) * (sk - skp1)), ...
                                -R_L / (2 * omega) * (v * T / a * ckp1 + R_R * dtheta_R / (a * omega) * (sk - skp1)); ...
                         R_R / (2 * omega) * (v * T / a * skp1 - R_L * dtheta_L / (a * omega) * (ck - ckp1)), ...
                                -R_L / (2 * omega) * (v * T / a * skp1 - R_R * dtheta_R / (a * omega) * (ck - ckp1)); ...
                         R_R * T / (2 * a), -R_L * T / (2 * a)];
            end

            P = A_dis * P * A_dis.' + B_dis * N * B_dis.';
        end
    end

    function [x, P] = doUpdate(x, P, meas, landmarks)
        % Implementation of the update step
        visIdx = meas.lmIds; % assume we can associate each measurement with a known landmark
        if isempty(visIdx); return; end

        beta = meas.bearing;
        d = meas.range;                        
        m = landmarks(visIdx, :);
                               
        C = zeros(0, 3);
        W = zeros(0, 0);
        delta_y = zeros(0, 1);

        b = m - repmat([x(1), x(2)], size(visIdx));

        if ~block.useCartesianSensor
            if block.useBearing
                % compute output vector z = h(x_k|k-1) (= model-based prediction of measurement)				
                y_pred = atan2(b(:, 2), b(:, 1)) - x(3);

                % innovation vector (measurement - output prediction)
                delta_y = [delta_y; mod(beta - y_pred + pi, 2 * pi) - pi]; % force into interval +-pi

                % H = jacobi matrix of output function w.r.t. state (dh/dx)
                denoms = b(:, 1).^2 + b(:, 2).^2;
                C = [C; [b(:, 2) ./ denoms, -b(:, 1) ./ denoms, repmat(-1, size(visIdx))]];

                % W = covariance matrix of measurement noise
                W = blkdiag(W, block.bearingError^2 * eye(length(visIdx)));
            end
            if block.useRange
                y_pred = sqrt(b(:, 1).^2 + b(:, 2).^2);

                delta_y = [delta_y; d - y_pred];			
                C = [C; [-b(:, 1) ./ y_pred, -b(:, 2) ./ y_pred, zeros(size(visIdx))]];

                W = blkdiag(W, diag((block.rangeError * d).^2));			
            end

        else
            for i = 1:length(visIdx)
                % transform d/beta uncertainty into m_ix/m_iy uncertainty
                J_y = [cos(beta(i)), -d(i) * sin(beta(i));
                       sin(beta(i)),  d(i) * cos(beta(i))];
                W(2 * i - [1 0], 2 * i - [1 0]) = J_y * diag([(block.rangeError * d(i))^2; block.bearingError^2]) * J_y';

                y_meas = d(i) * [cos(beta(i)); sin(beta(i))];
                y_pred = [cos(x(3)), -sin(x(3)); sin(x(3)), cos(x(3))]' * b(i, :)';
                delta_y(2 * i - [1 0], 1) = y_meas - y_pred;

                C(2 * i - [1 0], :) = [-cos(x(3)), -sin(x(3)),  cos(x(3)) * b(i, 2) - sin(x(3)) * b(i, 1); ...
                                        sin(x(3)), -cos(x(3)), -cos(x(3)) * b(i, 1) - sin(x(3)) * b(i, 2)];
            end

        end

        % compute Kalman gain K
        K = P * C' / (C * P * C' + W);			
        % update state x and covariance matrix P
        x = x + K * delta_y;
        P = (eye(3) - K * C) * P;                          
    end
end

function dx = vomega_model(x, v, omega)
    phi = x(3);
    dx = [v * cos(phi); ...
          v * sin(phi); ...
          omega];
end
