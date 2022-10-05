%%
%   T = T_dh(theta, d, a, alpha)
%   T = T_dh([theta, d, a, alpha])
%
% Builds a transformation matrix from Denavit Hartenberg parameters theta,
% d, a, alpha.
% This is a convenience function and is equivalent to
%
% T_rot('Z', theta) * T_shift([a 0 d]) * T_rot('X', alpha)
%
% See also: T_rot, T_shift
%
function T = T_dh(varargin)
    if nargin == 1
        vec = varargin{1};        
        if numel(vec) ~= 4
            error('Invalid argument vector: expected 4-element vector');
        end
    elseif nargin == 4
        vec = [varargin{1}, varargin{2}, varargin{3}, varargin{4}];
    else
        error('Invalid number of arguments');
    end
    
    T = T_rot('Z', vec(1)) * T_shift([vec(3), 0, vec(2)]) * T_rot('X', vec(4));    
end
