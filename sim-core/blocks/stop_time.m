function block = stop_time(tEnd, varargin)
	if ~isscalar(tEnd) || ~isnumeric(tEnd) || ~isreal(tEnd) || ~(tEnd > 0)
		error('sim:stop_distance', 'Invalid input format. expected scalar numeric value > 0');
	end

	if ~isempty(varargin)
		timingInfo = varargin{1};
	else timingInfo = 1;
	end
	
    block = block_base(timingInfo, [], @checkCondition);
    block.log.uniform = true;

    function [state, out, debug] = checkCondition(block, t, state)
        debug = [];
		state = [];
        out = (t < tEnd);
    end    
end