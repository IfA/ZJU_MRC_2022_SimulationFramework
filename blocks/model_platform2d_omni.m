% Implementation of a kinematic model of an omnidirectional robot 
%
% Expected input format:
% - column vector [vx; vy; omega]
%
% Output format:
% - struct with field .pose = [r_x; r_y; phi]
%
function model = model_platform2d_omni(varargin)   
    model = model_platform2d(@move, 'controller');    
    
    if nargin >= 1; model.default_initialPose = varargin{1}; end
    
    function [state, out, debugOut] = move(block, t, state, in)
        debugOut = [];
        [state, out] = continuous_integration(@model_equations, block.initialPose, t, state, in);
    
        function dX = model_equations(~, X, u)
            % Input format:
            % X = [x, y, phi]'
            % u = [vx, vy, omega]'
            
            phi = X(3);
            
            % Transformation from body-fixed velocities to inertial velocities
            J = [cos(phi), -sin(phi), 0; ...
                 sin(phi),  cos(phi), 0; ...
                        0,         0, 1];

            % see MR01 -> compute state derivatives
            dX = J * u;
        end
    end
end
