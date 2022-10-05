function sensor = sensor_odometer_wheelspeed()
    sensor = block_base(1/100, {'controller'}, @sample);

    sensor.default_odometryError = 5 * pi / 180; % sigma in rad/s
    
    function [state, out, debugOut] = sample(block, ~, state, controller)
        debugOut = [];
        if isempty(state)
            state = [0 0]';
        end
        if isempty(controller)
            speed = state;
        else
            speed = controller(end).data;
            state = speed;
        end
        
        out = speed + block.odometryError * randn(size(speed));
    end
end