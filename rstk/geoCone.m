%%
%   s = geoCone(r, h, N)
%
% Create a mesh for a cone starting in the xy plane centered around the z axis
% Paramteres:
% r: radius
% h: height
% N: number of divisions (optional, default = 10)
%
% See also: geoBox, geoEllipsoid, geoCylinder
%
function s = geoCone(varargin)
	N = 10; % default value;
	if nargin < 2 || nargin > 3, error('invalid number of arguments'); end
	
	if nargin == 3, N = varargin{3}; end
	r = varargin{1};
	h = varargin{2};
	
	dt = 2 * pi / N;
	t = 0:dt:(2 * pi - dt);
	
	s = geoGeneric([r * cos(t'), r * sin(t'), zeros(N, 1); 0 0 0; 0 0 h], ...
			       [repmat([(1:N)', circshift((1:N)', 1)], 2, 1), [repmat(N + 1, N, 1); repmat(N + 2, N, 1)]]);
end