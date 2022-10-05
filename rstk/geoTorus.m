%%
%   s = geoTorus(r1, r2, N1, range, N2)
%
% Constructs a torus mesh in the X-Y-plane around the Z-axis.
% Parameters:
% - r1:    ring radius
% - r2:    tube radius
% - N1:    Number of divisions along the ring (optional, default = 36)
% - range: 2-element vector of angle range in radians (0..2 * pi), measured in the 
%          XY plane (optional, default = full circle)
% - N2:    Number of divisions of the tube circle (optional, default = 10)
% 
% See also: geoRotateContour
%
function s = geoTorus(r1, r2, N1, range, N2)
	if nargin < 2, error('Too few arguments'); end
	if nargin < 3, N1 = 36; end
	if nargin < 4, range = [0 0]; end
	if nargin < 5, N2 = 10; end
	
	t = linspace(0, 2 * pi, N2 + 1); t(end) = [];
	s = geoRotateContour([r1 + r2 * cos(t'), r2 * sin(t')], N1, range);

end