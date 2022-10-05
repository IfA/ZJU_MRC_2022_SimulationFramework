%%
%   s = geoArrowTurn(R, r1, range, r2, l2, N, N2)
%
% Creates a threedimensional rotation arrow mesh (partial torus with cone at one end)
% in the xy plane, centered around the z axis.
% Parameters (all optional)
% R:     torus radius (default = 1)
% r1:    tube radius of torus part (default = 0.1)
% range: torus range in radians (0..2 * pi). Torus starts in the xz plane and extends up to 
%        this value (default = 3/2 * pi -> three-quarter circle)
% r2:    tip (cone part) radius (default = 3 * r1)
% l2:    tip (cone part) length (default = min(0.5, R / 2))
% N:     subdivisions around the Z axis
% N2:    subdivisions into the radial direction (default = 10)
%
% See also: geoArrowTurn, geoTorus, geoCone
%
function s = geoArrowTurn(R, r1, range, r2, l2, N, N2)
	if nargin < 1, R = 1; end
	if nargin < 2, r1 = 0.1; end
	if nargin < 3, range = 3 * pi / 2; end
	if nargin < 4, r2 = 3 * r1; end
	r2 = mod(r2, 2 * pi);
	if nargin < 5, l2 = min(0.5, R / 2); end
	if nargin < 6, N = ceil(range / (2 * pi) * 24); end
	if nargin < 7, N2 = 10; end
	
	s = combineGeometry(geoTorus(R, r1, N, [0 range], N2), transform(T_rot('XZ', -pi / 2, range) * T_shift(R, 0, 0), geoCone(r2, l2, N2)));
end
		