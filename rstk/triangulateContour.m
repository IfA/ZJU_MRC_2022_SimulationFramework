%% 
%   [triangles, addedPoints] = triangulateContour(contour)
%
% Fills the given contour with triangles using the Matlab functions
% delaunay und inpolygon. 'contour' is a 2 column matrix with the X and Y 
% coordinates of the contour points in the first and second column respectively.
% The calculated triangles will be returned as <number_of_triangles>x3 matrix 
% in the first output argument. Each element in the matrix specify an index (= row) 
% of a point in the 'contour' argument.
%
% Falls die Kontur sich selbst schneidet (momentan nicht implementiert!), werden
% die Schnittpunkte berechnet und im zweiten Ausgabeargument 'addedPoints' �bergeben.
% If the contour describes a self-intersecting polygon (not supported yet), the
% intersection points will be calculated and returned in the second output
% argument 'newPoints'. The indices in triangles will refer to these new points as if 
% they were concatenated to the bottom of the input contour matrix.
%
% See also geoShape, delaunay, inpolygon
function [tris, newPoints] = triangulateContour(contour)
	newPoints = zeros(0, 2);
	
	% Quick and dirty variant, that does not support self-intersecting
	% contours -> planned to upgrade to openGL tesselation routine later
	% (that will support self-intersecting contours)
	tris = delaunay(contour(:, 1), contour(:, 2));
	tris(inpolygon((contour(tris(:, 1), 1) + contour(tris(:, 2), 1) + contour(tris(:, 3), 1)) / 3, ...
		           (contour(tris(:, 1), 2) + contour(tris(:, 2), 2) + contour(tris(:, 3), 2)) / 3, ...
				   contour(:, 1), contour(:, 2)) ~= 1, :) = [];
end