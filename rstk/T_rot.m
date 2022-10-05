%%
%   T = T_rot(...)
%
% Builds a transformation matrix for arbitrarily complex rotations.
% The argument list must contain parameter type specifications (e.g. axis sequences) interleaved 
% interleaved with their associated parameters (rotation angles, etc.).
% Examples (same rotation expressed by all variants):
%    T_rot('X', pi / 4, 'Y', pi, 'Z', pi / 3)
%    T_rot('XYZ', [pi / 4, pi, pi / 3]);
%	 T_rot('XYZ', pi / 4, pi, pi / 3);
%    T_rot('XY', pi / 4, pi, 'Z', pi / 3);
%    ...
% Each parameter type is specified by a single ascii character. Upper case characters
% denote rotations in global fixed coordinates, while lower case characters indicate
% rotated frames (consecutive rotations). The following types are supported:
% - 'x'/'X': rotate around X axis
% - 'y'/'Y': rotate around Y axis
% - 'z'/'Z': rotate around Z axis
%   --> a single rotation angle is expected as parameter.
%       You can combine angles for mutiple axes in one vector.
% - 'k'/'K': rotate around arbitrary axis
%   --> axis as 3-element vector k = [kx, ky, kz], rotation angle = norm(k)
%   --> axis + rotation angle as 4-element vector.
% - 'q'/'Q': Rotation specified by a quaternion with scalar component first
%   --> quaterion components as 4-element vector.
% - 'r'/'R' rotate according to a given rotation matrix
%   --> 3x3 rotation matrix
%
% See also: T_unity, T_shift, T_scale
%
function T = T_rot(varargin)
	R = eye(3);
	
	idx = 1;
	while idx <= nargin
		axes = varargin{idx};
		idx = idx + 1;
		if ~isempty(axes)
			if ischar(axes)
				params = [];
				for ax = axes
					newParams = isempty(params);
					if isempty(params)
						if idx > nargin, error('Missing axis parameter at end of argument list'); end
						params = varargin{idx};
						idx = idx + 1;
						if ~isnumeric(params) && ~isa(params, 'sym'), error('Invalid axis parameter type'); end
					end
					
					switch upper(ax)
						case {'X', 'Y', 'Z'}
							if upper(ax) == 'X'; R_part = rotX(params(1));
							elseif upper(ax) == 'Y'; R_part = rotY(params(1));
							elseif upper(ax) == 'Z'; R_part = rotZ(params(1));
							end
							params(1) = [];

						case 'K'
							if ~newParams, error('Please give arbitrary axis parameters as separate argument'); end
							if numel(params) == 3,
								nrm = norm(params);
								if nrm == 0
									warning('Axis has zero length, ignoring this rotation');
									R_part = [];
                                else R_part = rotAxis(params / nrm, nrm);
								end
							elseif numel(params) == 4 && any(size(params) == 1),
								nrm = norm(params(1:3));
								if nrm == 0
									warning('Axis has zero length, ignoring this rotation');
									R_part = [];
                                else R_part = rotAxis(params(1:3) / nrm, params(4));
								end
                            else error('Arbitrary axis parameters must be given as 3- or 4-element vector');
							end
						case 'Q'
							if ~newParams, error('Please give quaternion parameters as separate argument'); end
							if numel(params) == 4 && any(size(params) == 1),
								% quaternion formula
								nrm = norm(params);
								if nrm == 0
									warning('Quaternion has zero norm, ignoring this rotation');
									R_part = [];
								else
									q = params / nrm;
									R_part = [q(1)^2 + q(2)^2 - q(3)^2 - q(4)^2, 2 * q(2) * q(3) - 2 * q(1) * q(4), 2 * q(2) * q(4) + 2 * q(1) * q(3);
										      2 * q(2) * q(3) + 2 * q(1) * q(4), q(1)^2 - q(2)^2 + q(3)^2 - q(4)^2, 2 * q(3) * q(4) - 2 * q(1) * q(2);
											  2 * q(2) * q(4) - 2 * q(1) * q(3), 2 * q(3) * q(4) + 2 * q(1) * q(2), q(1)^2 - q(2)^2 - q(3)^2 + q(4)^2];
								end
                            else error('Quaterion parameters must be given as 4-element vector');
							end

						case 'R'							
							if ~newParams, error('Please give rotation matrix as separate argument'); end
							if all(size(params) == 3), 
								R_part = params;
								params = [];
                            else error('Rotation matrix parameter must be a 3x3 matrix');
							end
							
						otherwise, error('unsupported axis specifier ''%c''', ax);
					end
					
					if ~isempty(R_part)
						if ax < 'a' % upper case -> global axis
							R = R_part * R;
						else % lower case -> rotated axis
							R = R * R_part;
						end
					end
				end				
            else error('Invalid argument: Axis specifier expected');
			end
		end		
	end
	
	T = blkdiag(R, 1);
	
	% Helpers
	
	function R = rotX(a)
		c = cos(a);	s = sin(a);
		R = [1 0 0; 0 c -s; 0 s c];
	end
	function R = rotY(a)
		c = cos(a); s = sin(a);
		R = [c 0 s; 0 1 0; -s 0 c];
	end
	function R = rotZ(a)
		c = cos(a); s = sin(a);
		R = [c -s 0; s, c, 0; 0 0 1];
	end
	function R = rotAxis(k, angle)
		c = cos(angle);
		nc = 1 - c;
		s = sin(angle);
		R = [k(1)^2 * nc + c, k(1) * k(2) * nc - k(3) * s, k(1) * k(3) * nc + k(2) * s; ...
			 k(1) * k(2) * nc + k(3) * s, k(2)^2 * nc + c, k(2) * k(3) * nc - k(1) * s; ...
			 k(1) * k(3) * nc - k(2) * s, k(2) * k(3) * nc + k(1) * s, k(3)^2 * nc + c];
	end
end
