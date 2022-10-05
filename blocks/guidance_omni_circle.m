% Steer an omnidirectional robot on a circular path
%
% By setting the parameter rotVelocity unequal zero, the robot changes
% and moves simultaneously
%
function guidance = guidance_omni_circle()   
    guidance = block_base(1/10, [], @guide);
    guidance.default_radius = 2;
    guidance.default_cw = true;
    guidance.default_transVelocity = 1;
    guidance.default_rotVelocity = 0 * pi / 180;
    
    function [state, out, debugOut] = guide(block, t, state)
        debugOut = [];
        state = [];
        if block.cw; v = -abs(block.transVelocity); else v = abs(block.transVelocity); end
        trigArg = t / block.radius * v - t * block.rotVelocity;
        out = [block.transVelocity * [cos(trigArg); sin(trigArg)]; block.rotVelocity];
    end
end
