%%
%   T = T_scale(sx, sy, sz)
%   T = T_scale([sx, sy, sz])
%
% Builds a transformation matrix for scaling.
% Negative scaling factors cause mirroring.
%
% See also: T_unity, T_rot, T_shift
%
function T = T_scale(sx, sy, sz)
	if nargin == 1
		if numel(sx) == 3; T = diag([sx(:)', 1]);
		else T = diag([repmat(sx(1), 1, 3), 1]);
		end
	elseif nargin == 3;
		T = diag([sx, sy, sz, 1]);
    else error('Invalid arguments');
	end
end