%%
%   s = geoCylinder(r, h, N)
%
% Creates the mesh for a cylinder starting in the xy plane centered around the z axis.
% Parameters:
% r: radius
% h: height
% N: number of divisions (optional, default = 10)
%
% See also: geoBox, geoEllipsoid, geoRotateCurve
% 
function s = geoCylinder(varargin)
	N = 10; % default value;
	if nargin < 2 || nargin > 3, error('invalid number of arguments'); end
	
	if nargin == 3, N = varargin{3}; end
	r = varargin{1};
	h = varargin{2};
	
	dt = 2 * pi / N;
	t = 0:dt:(2 * pi - dt);
	
	s = geoRotateCurve([r r], h, N);
end