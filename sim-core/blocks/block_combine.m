% Utility block that combines multiple inputs into a single output struct
% Usage example:
% ... = block_combine('input1', 'field1', 'input2', 'field2', ...)
% The resulting output will be a struct with fields '.field1', '.field2', ...

function block = block_combine(varargin)
    if nargin < 2 || mod(nargin, 2) ~= 0
        error('sim:block_combine', 'Invalid number of input arguments');
    end
    
    inputList = cell(nargin / 2, 1);
    fieldList = cell(nargin / 2, 1);
    for i = 1:(nargin / 2)
        in = varargin{2 * i - 1};
        field = varargin{2 * i};
        if ~isvarname(in)
            error('sim:block_combine', 'Invalid input name');
        end        
        if ~isvarname(field)
            error('sim:block_combine', 'Invalid field name');
        end
        inputList{i} = in;
        fieldList{i} = field;
    end
    
    block = block_transform(inputList, @func);
    
    function o = func(varargin)
        o = struct();
        for iField = 1:length(fieldList)
            o.(fieldList{iField}) = varargin{iField};
        end
    end
end