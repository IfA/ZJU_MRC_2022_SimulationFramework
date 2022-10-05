% Generate control inputs from a gamepad/joystick
%
% The output format is an array of floating point values.
% If a parameter is given, it must be a structure of which the dimension 
% determines the dimension of the output array. The fields control the 
% gamepad axis mappings and scalings in the following way:
% - axis: index of gamepad axis (zero-based)
% - range: [max], [min, max] or [min, neutral, max] of the output value
%
function input = input_gamepad(varargin)    
    input = block_base(1/10, [], @read);
    input.mexFiles{end + 1} = fullfile(fileparts(mfilename('fullpath')), '../tools/input/joyread.c');
    if nargin > 1; error('input_gamepad:args', 'Too many input arguments'); end
    if nargin == 1
        input.mapping = varargin{1};
        if ~isstruct(input.mapping); error('input_gamepad:args', 'Argument must be a struct'); end
        if ~isfield(input.mapping, 'axis'); error('input_gamepad:args', 'Struct misses field "axis"'); end        
    else
        input.mapping(1, 1).axis = 1;
        input.mapping(2, 1).axis = 2;
    end
    if ~isfield(input.mapping, 'range')        
        input.mapping(1).range = [];
    end
        
    function [state, out, debugOut] = read(block, varargin)
        debugOut = [];
        state = [];
        axisData = joyread();
        out = zeros(size(block.mapping));
        if ~isempty(axisData)
            for i = 1:numel(out)
                iAx = block.mapping(i).axis;
                if iAx < 1 || iAx > numel(axisData)
                    val = NaN;
                else val = axisData(iAx);
                end
                out(i) = scaleAxis(block.mapping(i).range, val);
            end
        else             
            for i = 1:numel(out)
                out(i) = scaleAxis(block.mapping(i).range, 0);
            end
        end
    end    
end

function o = scaleAxis(range, in)
    if numel(range) == 0
        range = [-1 0 1];
    elseif numel(range) == 1
        range = [-range(1), 0, range(1)];
    elseif numel(range) == 2
        range = [range(1), 0, range(2)];
    end
    
    if in < 0
        o = range(2) - (range(1) - range(2)) * in;
    else
        o = range(2) + (range(3) - range(2)) * in;
    end
end
