%%
%   s = geoGeneric(vertices, faces)
%
% Generate a mesh structure from the given 'vertices' and 'faces'.
% For a description of the parameter formats, please refer to the MATLAB documentation 
% of the patch object properties 'Vertices' and 'Faces'.
%
% See also: patch
%
function s = geoGeneric(vertices, faces)
	s = struct('v', vertices, 'f', faces);
end