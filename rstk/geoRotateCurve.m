%%
%   s = geoRotateCurve([rads, heights], N)
%   s = geoRotateCurve(rads, heights, N)
%   s = geoRotateCurve(rads, height, N)
%
% Rotates a profile in the XZ-plane around the Z axis.
% Parameters:
% - rads:    Column vector of radii (x coordinates of points constituting the curve).
%            By default, cap surfaces will be generated at both ends of the geometry.
%            Specifying NaN for the first and/or last element to disable this behavior.
% - heights: column vector of z coordinates. The vector length must be compatible
%            with rads, i.e. must be the same length as rads trimmed by trailing and/or 
%            leading NaNs.
% - height:  (instead of 'heights' vector) radii specified by 'rads' will be distributed 
%            equally between 0 and this value.
% - N:       Number of divisions in the rotation direction (optional, default = 10)
%
% See also: geoRotateContour, geoCylinder, geoExtude
%
function s = geoRotateCurve(varargin)
	N = 10; % default value

	if nargin == 1
		arg = varargin{1};		
		if size(arg, 1) ~= 2, error('First argument must be a matrix with 2 rows'); end
		r = arg(:, 1)';
		h = arg(:, 2)';
	elseif nargin == 2
		arg1 = varargin{1};
		if size(arg1, 1) == 2
			N = varargin{2};
			r = arg1(:, 1)';
			h = arg1(:, 2)';
		elseif size(arg1, 1) == 1
			r = arg1';
			h = varargin{2}';
		else, error('first argument has too many rows');
		end
	elseif nargin == 3
		r = varargin{1}';
		h = varargin{2}';
		N = varargin{3};
	else, error('invalid number of arguments');
	end
		
	if numel(N) ~= 1, error('''Number of segments'' must be a scalar'); end
	if size(r, 2) ~= 1 || size(h, 2) ~= 1, error('radius and height profiles must be row vectors'); end
	
	if numel(r) < 2, error('radius profile must have at least 2 entries'); end
		
	topcap = ~isnan(r(end));
	botcap = ~isnan(r(1));
	
	r(isnan(r)) = [];
	if numel(h) == 1
		h = linspace(0, h, numel(r))';
	elseif numel(h) ~= numel(r), error('radius and height profile must have the same number of elements');
	end

	dt = 2 * pi / N;
	t = 0:dt:(2 * pi - dt);

	k = numel(r);
	V = [repmat(reshape(repmat(r', N, 1), [], 1), 1, 2) .* repmat([cos(t'), sin(t')], k, 1), ...
		 reshape(repmat(h', N, 1), [], 1)];

	F = repmat([(1:N)', circshift((1:N)', 1), N + circshift((1:N)', 1), N + (1:N)'], k - 1, 1) + ...
		repmat(reshape(repmat((N * (0:(k - 2))), N, 1), [], 1), 1, 4);
	 
	if topcap
		V = [V; 0 0 h(end)];
		idxs = (1:N)' + N * (k - 1);
		F = [F; idxs, circshift(idxs, 1), repmat([size(V, 1), NaN], N, 1)];
	end
	if botcap		
		V = [V; 0 0 0];
		F = [F; (1:N)', circshift((1:N)', 1), repmat([size(V, 1), NaN], N, 1)];
	end
	
	s = geoGeneric(V, F);
end