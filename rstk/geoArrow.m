%%
%   s = geoArrow([direction], l, r1, l2, r2, N)
% 
% Creates a threedimensional arrow mesh (cylinder with cone at one end) aligned
% with the z axis starting at the origin.
% Parameters (all optional)
% direction: pointing direction as 3-element vector. If left out, the Z 
%            axis is used by default.
% l:  arrow length from cylinder bottom surface to cone tip (default = 1)
% r1: radius of cylinder part (default = 0.1)
% l2: tip (cone part) height (default = max(6 * r1, 0.3 * l))
% r2: tip (cone part) radius (default = 3 * r1)
% N:  subdivisions (default = 10)
%
% See also: geoArrowTurn, geoCone, geoCylinder
%
function s = geoArrow(varargin)
    argc = nargin;
    if argc > 0 && numel(varargin{1}) == 3; 
        direction = varargin{1};
        varargin = varargin(2:end);
        argc = argc - 1;
    else direction = [];
    end

    if argc < 1, l = 1; else l = varargin{1}; end
	if argc < 2, r1 = 0.1; else r1 = varargin{2}; end
	if argc < 3, l2 = max(6 * r1, 0.3 * l); else l2 = varargin{3}; end
	if argc < 4, r2 = 3 * r1; else r2 = varargin{4}; end
	if argc < 5, N = 10; else N = varargin{5}; end

	s = combineGeometry(geoCylinder(r1, l - l2, N), transform(T_shift(0, 0, l - l2), geoCone(r2, l2, N)));
    
    if ~isempty(direction)
        T = T_rot('zy', atan2(direction(2), direction(1)), -atan2(direction(3), norm(direction(1:2))) + pi / 2);
        s = transform(T, s);
    end
end
