% Utility block that applies a user-defined transformation function on its
% inputs. The block will pass the most recent data from all its inputs to
% the transformFunc. The return value of the transformFunc is used as the
% block's output

function block = block_transform(inputs, transformFunc)
    block = block_base(0, inputs, @func);
	
    function [state, out, debugOut] = func(~, ~, ~, varargin)
        state = [];
        debugOut = [];
        latestInputs = cellfun(@(c)c(end).data, varargin, 'UniformOutput', false);
        out = transformFunc(latestInputs{:});
    end
end