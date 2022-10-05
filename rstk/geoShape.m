%%
%   s = geoShape(poly)
%
% Constructs a flat mesh in the X-Y-plane by triangulating the polygon contour
% specified by 'poly' using the 'triangulate' function. 
% 'poly' must be a Nx2-matrix of XY tuples. The first and last
% point should not coincide, since the function will automatically close the contour.
% Due to a constraint in triangulate, the contour may not intersect itself.
%
% See also: triangulate
%
function s = geoShape(poly)
	if size(poly, 2) ~= 2 || size(poly, 1) < 3, error('argument must be a nx2-matrix with n > 2 (at least 3 points)'); end
	
	[faces, ptAdd] = triangulateContour(poly);
	poly = [poly; ptAdd];
	
	s = geoGeneric([poly, zeros(size(poly, 1), 1)], faces);
end