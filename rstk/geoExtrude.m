%%
%   s = geoExtrude(contour, height, N, caps)
%
% Extrudes a contour in the XY plane along the Z axis.
% Parameters:
% - contour: Nx2 matrix of XZ coordinate tuples describing the contour.
%            The first and last tuple should not coincide, since the contour is
%            automatically closed. Depending on the 'caps' argument, the contour
%            may or may not intersect itself.
% - height:  Object height from the xy plane into the z direction (optional, default = 1).
% - N:       Divisions along the height direction (optional, default = 1).
% - caps:    Optional. controls the generation of cap surfaces.
%            Supported values are 'both' (default, caps at top and bottom), 'none' (no caps), 
%            'start' (bottom cap only) and 'end' (top cap only).
% 
% See also: geoBox, geoRotateContour, geoRotateCurve
%
function s = geoExtrude(contour, height, N, caps)
	if nargin < 1, error('Too few arguments'); end
	if nargin < 2, height = 1; end
	if nargin < 3, N = 1; end
	if nargin < 4, caps = 'both'; end
	
	if size(contour, 2) ~= 2, error('first argument has invalid format'); end
	k = size(contour, 1);
	if k < 3, error('Contour has too few points. At least 3 points are required'); end
	
	if N < 1
		warning('N < 1 not allowed');
		N = 1;
	end

	Z = 0:(height / N):height;
	vertices = [repmat(contour, (N + 1), 1), reshape(repmat(Z, k, 1), [], 1)];
	
	f = (1:k)';
	F = [f, circshift(f, -1), k + circshift(f, -1), k + f];
	offsets = k * (0:(N - 1));
	faces = repmat(reshape(repmat(offsets, k, 1), [], 1), 1, 4) + repmat(F, N, 1);
	
	switch(caps)
		case 'both', cEnd = true; cStart = true;
		case 'start', cEnd = false; cStart = true;
		case 'end', cEnd = true; cStart = false;
		case 'none', cEnd = false; cStart = false;
		otherwise, error('Invalid value for caps argument. Supported values are ''both'', ''start'', ''end'' and ''none''.');
	end
	if cEnd || cStart
		[fCap, capPoints] = triangulateContour(contour);
		idxNew = find(fCap > k);
		
		sOffset = size(vertices, 1) - size(contour, 1);		
		eOffset = 0;
		if cStart
			vertices = [vertices; capPoints, zeros(size(capPoints, 1), 1)];
			sCapFaces = fCap;
			sCapFaces(idxNew) = sCapFaces(idxNew) + sOffset;
			faces = [faces; sCapFaces, NaN(size(sCapFaces, 1), 1)];
			eOffset = size(capPoints, 1);
		end
		if cEnd
			vertices = [vertices; capPoints, repmat(height, size(capPoints, 1), 1)];
			eCapFaces = fCap + k * N;
			eCapFaces(idxNew) = eCapFaces(idxNew) + eOffset;
			faces = [faces; eCapFaces, NaN(size(eCapFaces, 1), 1)];			
		end
	end
	
	s = geoGeneric(vertices, faces);
end