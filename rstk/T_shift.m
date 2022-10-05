%%
%   T_shift(dx, dy, dz)
%   T_shift([dx, dy, dz])
%
% Builds a transformation matrix for a translation operation.
%
% See also: T_unity, T_rot, T_scale
%
function T = T_shift(dx, dy, dz)
	if nargin == 1
		if numel(dx) == 3; T = [1 0 0 dx(1); 0 1 0 dx(2); 0 0 1 dx(3); 0 0 0 1];
        else error('The one argument variant requires a 3-element vector');
		end
	elseif nargin == 3;
		T = [1 0 0 dx; 0 1 0 dy; 0 0 1 dz; 0 0 0 1];
    else error('Invalid arguments');
	end
end