%%
%   s = geoRotateConcour(contour, N, range, caps)
%
% Rotates a closed contour around the z axis. As an illustrative example, 
% think of a torus as a circle in the XZ-plane is rotated around the Z axis.
% Parameters:
% - contour: Nx2 matrix of XZ coordinate tuples describing the contour.
%            The first and last tuple should not coincide, since the contour is
%            automatically closed. Depending on the caps argument, the contour
%            may or may not intersect itself.
% - N:       Number of divisions in the rotation direction (optional, default = 36)
% - range:   2-element vector specifying angle range for rotation in radians (0..2 * pi), 
%            measured in the XY plane (optional, default = full circle)
% - caps:    Optional. Controls the generation of cap surfaces if range is not a full circle.
%            Supported values are 'both' (default, caps at both ends), 'none' (no caps), 
%            'start' (cap at range(1) only) and 'end' (cap at range(2) only).
%
% See also: geoRotateCurve, geoTorus
%
function s = geoRotateContour(contour, N, range, caps)
	if nargin < 1, error('Too few arguments'); end

	if size(contour, 2) ~= 2 || size(contour, 1) < 3, error('contour must be a nx2 matrix with n > 2 (at least 3 contour points)'); end
	
	if nargin < 2, N = 36; end
	if nargin < 3, range = [0, 2 * pi]; end
	if nargin < 4, caps = 'both'; end

	if N < 2, N = 2; end

	range = mod(range, 2 * pi);
	reverse = (range(2) < range(1));
	closed = (range(1) == range(2));
	if reverse, range = [range(2) range(1)]; end
	
    if closed
		t = linspace(0, 2 * pi, N + 1);
		t(end) = [];
    else t = linspace(range(1), range(2), N);
    end

	k = size(contour, 1);

	vertices = [reshape(repmat(cos(t), k, 1), [], 1) .* repmat(contour(:, 1), N, 1), ...
				reshape(repmat(sin(t), k, 1), [], 1) .* repmat(contour(:, 1), N, 1), ...
				repmat(contour(:, 2), N, 1)];
	
	f = (1:k)';
	F1 = [f, circshift(f, 1), circshift(f, 1) + k, f + k];
	if closed, offsets = k * (0:(N - 2));
    else offsets = k * (0:(N - 2)); end
	faces = repmat(F1, length(offsets), 1) + repmat(reshape(repmat(offsets, k, 1), [], 1), 1, 4);
	if closed,
		faces = [faces; [(N - 1) * k + f, (N - 1) * k + circshift(f, 1), circshift(f, 1), f]];
	end
	
	s = geoGeneric(vertices, faces);
	
	if ~closed
		switch caps
			case 'none', sCap = false; eCap = false;
			case 'both', sCap = true; eCap = true;
			case 'start'
				if reverse, eCap = true; sCap = false; else eCap = false; sCap = true; end
			case 'end'
				if reverse, eCap = false; sCap = true; else eCap = true; sCap = false; end
			otherwise, error('Invalid value for ''caps'' argument');
		end
		
		if sCap || eCap
			shape = geoShape(contour);
			if sCap, s = combineGeometry(s, transform(T_rot('XZ', pi / 2, t(1)), shape)); end
			if eCap, s = combineGeometry(s, transform(T_rot('XZ', pi / 2, t(end)), shape)); end
		end
	end
end