% Steer a differential drive robot on a square path.
% For correct operation, this block has to use the same wheelRadius and
% wheelDistance parameters as the robot 
% 
function guidance = guidance_ddrive_square()   
    guidance = block_base(1/10, [], @guide);
    guidance.default_length = 2;
    guidance.default_cw = true;
    guidance.default_transVelocity = 0.75;
    guidance.default_rotVelocity = 45 * pi / 180;
    guidance.default_wheelRadius = 0.025;
    guidance.default_wheelDistance = 0.2;
    
    function [state, out, debugOut] = guide(block, t, state)
        debugOut = [];
        if isempty(state)
            state = [1, t];
            out = [0; 0];
        else
            mode = state(1);
            tStart = state(2);                        
            if mode == 1
                % '+ 1e-6' to compensate rounding errors
                if (t - tStart + 1e-6) >= (block.length / block.transVelocity)
                    mode = 2;
                    tStart = t;
                end
            else
                % '+ 1e-6' to compensate rounding errors
                if (t - tStart + 1e-6) >= (pi / 2 / block.rotVelocity)
                    mode = 1;
                    tStart = t;
                end
            end
            state = [mode, tStart];
            if mode == 1
                vOmega = [block.transVelocity; 0];
            else vOmega = [0; -(2 * block.cw -1) * block.rotVelocity];
            end
            
            if numel(block.wheelRadius) > 1
                R_right = block.wheelRadius(1);
                R_left = block.wheelRadius(2);
            else
                R_right = block.wheelRadius(1);
                R_left = block.wheelRadius(1);
            end
            out = [1 / R_right, 0.5 * block.wheelDistance / R_right; 1 / R_left, -0.5 * block.wheelDistance / R_left] * vOmega;                   
        end
    end
end
