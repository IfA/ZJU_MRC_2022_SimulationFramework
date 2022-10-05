%%
%   s = geoEllipsoid();
%   s = geoEllipsoid(r);
%   s = geoEllipsoid(r, N);
%   s = geoEllipsoid([rx, ry, rz]);
%   s = geoEllipsoid([rx, ry, rz], N);
%   s = geoEllipsoid(rx, ry, rz);
%   s = geoEllipsoid(rx, ry, rz, N);
%
% Creates an ellipsoid mesh centered around the origin using the matlab function 'ellipsoid'. 
% Parameters:
% - rx, ry, rz: separate radii along x, y and z axis
% - r:          same radius for x, y and z axis
% - N:          Number of divisions. (optional, default = 10)
% The no argument variant will produce a unit sphere.
%
% See also: ellipsoid
%
function s = geoEllipsoid(varargin)
	N = 10; % default value;
	if nargin == 0,
		r = [1 1 1];
	elseif nargin == 1 || nargin == 2,
		arg = varargin{1};
		if numel(arg) == 3, r = arg;
		elseif numel(arg) == 1, r = repmat(arg, 1, 3);
		else, error('first argument must be a 3-element vector or a scalar');
		end
		if nargin == 2, N = varargin{2}; end
	elseif nargin == 3 || nargin == 4		
		r = [varargin{1:3}];
		if nargin == 4, N = varargin{4}; end
	else, error('Invalid additional arguments. Must be ''Property''/Value-Pairs');
	end
	[X, Y, Z] = ellipsoid(0, 0, 0, r(1), r(2), r(3), N);

	ind = reshape(sub2ind(size(X), repmat((1:(size(X, 1) - 1))', 1, size(X, 2) - 1), repmat(1:(size(X, 2) - 1), size(X, 1) - 1, 1)), [], 1);
	s = geoGeneric([reshape(X, [], 1), reshape(Y, [], 1), reshape(Z, [], 1)], ...
				   [ind, ind + 1, ind + size(X, 1) + 1, ind + size(X, 1)]);
end