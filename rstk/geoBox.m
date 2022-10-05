%%
%   s = geoBox();
%   s = geoBox(w);
%   s = geoBox(wx, wy, wz);
%   s = geoBox([wx, wy, wz]);
%
% Creates a box mesh starting at the origin.
% Parameters:
% wx, wy, wz: separate edge lengths for the x, y and z direction
% w:          same edge for x, y and z direction (cube)
% The no argument variant will produce a unit cube.
%
% See also: geoCylinder, geoEllipsoid, geoCone
%
function s = geoBox(w, varargin)
	if nargin == 0
		w = [1 1 1];
	else
		if numel(w) == 3
			w = w(:)';
			% input is 3-element vector
		else
			if nargin < 3; error('Too few input arguments'); end;
			w = [w(1), varargin{1}, varargin{2}];
		end
	end

	s = transform(T_scale(w), geoGeneric([0 0 0; 1 0 0; 1 1 0; 0 1 0; 0 0 1; 1 0 1; 1 1 1; 0 1 1], ...
								         [1 2 3 4; 5 6 7 8; 1 2 6 5; 6 2 3 7; 7 3 4 8; 8 5 1 4]));
end