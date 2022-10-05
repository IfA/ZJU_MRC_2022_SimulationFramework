function sink = block_sink(inputs, varargin)
    if length(varargin) >= 1
        deltaT = varargin{1};
    else deltaT = 1/10;
    end
    sink = block_base(deltaT, inputs, @dummyFunc);
       
    function [state, out, debugOut] = dummyFunc(varargin)
        state = [];
        debugOut = [];
        out = 0;
    end
end