% Implementation of a kinematic model of a ground robot with differential
% drive locomotion system
%
% Expected input format:
% - column vector [theta_r_dot; theta_l_dot] - wheel rotational rates
%
% Output format:
% - struct with field .pose = [r_x; r_y; phi]
%
function model = model_platform2d_ddrive(varargin)   
    model = model_platform2d(@move, 'controller');    
    
    if nargin >= 1
        model.initialPose = varargin{1}; 
    else model.default_initialPose = [0 0 0]';
    end
    
    
    model.default_wheelRadius = [0.03 0.03]; % default wheel diameter = 6 cm
    model.default_wheelDistance = 0.2;
    
    function [state, out, debugOut] = move(block, t, state, in)
        debugOut = [];
        [state, out] = continuous_integration(@model_equations, block.initialPose, t, state, in);
    
        function dX = model_equations(~, X, u)
            % Input format:
            % X = [x, y, phi]'
            % u = [omega_r, omega_l]'
            
            phi = X(3);
            
            % Transformation from body-fixed velocities to inertial velocities
            J = [cos(phi), -sin(phi), 0; ...
                 sin(phi),  cos(phi), 0; ...
                        0,         0, 1];
            
            % Transformation of the inputs into (generalized) body-fixed velocities
            if numel(block.wheelRadius) > 1
                R_rightWheel = block.wheelRadius(1);
                R_leftWheel = block.wheelRadius(2);
            else
                R_rightWheel = block.wheelRadius(1);
                R_leftWheel = block.wheelRadius(1);
            end
            V = [R_rightWheel / 2, R_leftWheel / 2; ...
                                0,               0; ...
                 R_rightWheel / block.wheelDistance, -R_leftWheel / block.wheelDistance];
            
            % see MR01 -> compute state derivatives
            dX = J * V * u(:);
        end
    end
end
