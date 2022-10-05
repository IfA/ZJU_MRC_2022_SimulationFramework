function const = block_const(data)
	if sum(size(data)) == 0
		error('sim:block_const', 'Constant data may not be empty');
	end
    const = block_base(inf, [], @func);
	
    function [state, out, debugOut] = func(block, varargin)
        state = [];
        debugOut = [];
        out = data;
    end
end