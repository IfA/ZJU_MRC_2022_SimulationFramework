%%
%    t = triade(placement, color, length, thickness)
%
% This function will create an object group from three coloured orthogonal arrows ("triade")
% marking a coordinate frame origin.
% 
% Parameters (all optional):
% - placement: where to place the triade and therefore the coordinate frame origin. 
%   Supported formats:
%   - 4x4 tranformation matrix (see T_...-functions)
%   - 3 element vector: translation only
%   - 4 element vector: rotation only around arbitrary axis (see T_rot('K', ...))
%   (Default value: unit transform 'T_unity()')
% - color: nx3 matrix with coloring information. Supported formats:
%   - n = 0: default coloring (X = red, Y = green, Z = blue) for stroke and tips
%   - n = 1: same color for all strokes, default coloring for tips (recommended use)
%   - n = 3: separate colors for x/y/z strokes, default coloring for tips 
%   - n = 6: separate color for x/y/z strokes and x/y/z axis tips in this order.
% - length: arrow length. 
%   - 3 element vector: separate length for each arrow
%   - scalar value: same length for all axes
%   (Default value: 1)
% - thickness: arrow radius (cylinder part)
%   - 3 element vector: separate radius for each axis
%   - scalar value: same radius for all axes
%   (Default value: 0.03)
%
% The return value is an object group, extended by the following member functions:
% - highlight(axes):  highlighs one or more axes of the triade, e.g. to emphasize a certain 
%                     motion direction. The 'axes' parameter should be combination of the 
%                     letters 'X', 'Y' and 'Z'. If left out, all axes are highlighted.
% - resetHighlight(): resets all axes to their normal display state.
% - setColor(...):    Changes the axes and tip colors. The arguments must be specified in the
%                     same way as described above for the 'color' parameter.
%
% See also: geoArrow, createObjectGroup
%
function t = triade(placement, color, len, thickness)	
	if nargin < 2; color = []; end
	if nargin < 3; len = 1; end
	if nargin < 4; thickness = 0.03; end
	
	if nargin > 0; placement = normalizePlacement(placement);
    else placement = T_unity();
	end
	
	color = normalizeColor(color);
	
	if length(len) == 1; len = repmat(len, 1, 3); end;
	if length(thickness) == 1; thickness = repmat(thickness, 1, 3); end		
	
	r2 = 3 * thickness;
	l2 = 3 * r2;
	idx = l2 > (0.7 * len);
	l2(idx) = 0.7 * len(idx);
	
	N = 10;
	function [stroke, tip] = createArrow(T, len, thickness, l2, r2, N)
		stroke = createObject(transform(T, geoCylinder(thickness, len - l2, N)));
		tip = createObject(transform(T * T_shift(0, 0, len - l2), geoCone(r2, l2, N)));
	end
	[objXStroke, objXTip] = createArrow(T_rot('Y', pi / 2), len(1), thickness(1), l2(1), r2(1), N);
	[objYStroke, objYTip] = createArrow(T_rot('X', -pi / 2), len(2), thickness(2), l2(2), r2(2), N);
	[objZStroke, objZTip] = createArrow(T_unity(), len(3), thickness(3), l2(3), r2(3), N);
	
	highlightState = [0 0 0];
	colorize();
	
	t = createObjectGroup(objXStroke, objXTip, objYStroke, objYTip, objZStroke, objZTip);
	t.place(placement);
	
	t.highlight = @highlight;
	t.resetHighlight = @resetHighlight;
	t.setColor = @setColor;
	
	function setColor(clr)
		color = normalizeColor(clr);
		colorize();
	end

	function highlight(axes)
		if nargin == 0; axes = 'XYZ'; end
		
		if ~ischar(axes); error('argument must be a character array'); end
		axes = upper(axes);
		if ~all(ismember(axes, 'XYZ')); error('Argument contains invalid axis specifier(s).'); end;		
		highlightState = [0 0 0];
		highlightState(1 + axes - 'X') = 1;
		colorize();		
	end

	function resetHighlight()		
		highlightState = [0 0 0];
		colorize();		
	end

	% Helpers
	function colorize()
		objects = [objXStroke, objYStroke, objZStroke, objXTip, objYTip, objZTip];
		if any(highlightState)
			arrayfun(@(idx)set(objects(idx).handle, 'FaceColor', brighten(color(idx, :), 0.7), 'FaceLighting', 'none'), find([highlightState highlightState]));
			arrayfun(@(idx)set(objects(idx).handle, 'FaceColor', brighten(color(idx, :), -0.7), 'FaceLighting', 'gouraud'), find(~[highlightState highlightState]));
		else
			% no highlight
			arrayfun(@(idx)set(objects(idx).handle, 'FaceColor', color(idx, :), 'FaceLighting', 'gouraud'), 1:numel(objects));
		end
	end
	function clrOut = normalizeColor(clrIn)
		if isempty(clrIn),
			clrOut = repmat(0.8 * [1 0 0; 0 1 0; 0 0 1], 2, 1);
		else
			if size(clrIn, 2) == 3
				if size(clrIn, 1) == 1,
					clrOut = [repmat(clrIn, 3, 1); 0.8 * [1 0 0; 0 1 0; 0 0 1]];
				elseif size(clrIn, 1) == 3,
					clrOut = [clrIn; 0.8 * [1 0 0; 0 1 0; 0 0 1]];
				elseif size(clrIn, 1) == 6,
					clrOut = clrIn;
                else error('invalid number of colors given to color argument. 0, 1, 3 or 6 colors expected');
				end
            else error('invalid argument format for color: must be a matrix with three columns');
			end
		end	
	end

	function pl = normalizePlacement(pl)
		sz = size(pl);
		if numel(sz) ~= 2; error('Placement must be a matrix or a vector'); end
		
		if all(sz == 4);
			% is already a transformation matrix
		elseif all(sz == 3)
			% rotation matrix
			pl = T_rot('R', pl);
		elseif any(sz == 1);
			if numel(pl) == 3;
				% translation
				pl = T_trans(pl(1), pl(2), pl(3));
			elseif numel(pl) == 4;
				% rotation around axis ( to come)
				pl = T_rot('K', pl);
            else error('Invalid placement parameter: must be a 4x4 transformation matrix, 3x3 rotation matrix, 3-element translation vector or 4-element axis/angle rotation vector');
			end
        else error('Invalid placement parameter: must be a 4x4 transformation matrix, 3x3 rotation matrix, 3-element translation vector or 4-element axis/angle rotation vector');
		end		
	end

end
