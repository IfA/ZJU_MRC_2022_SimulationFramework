%%
%  complexGeo = combineGeometry(geo1, geo2, ...)
%
% Combines several geometries into a more complex one.
%
function s = combineGeometry(varargin)
	if nargin == 0; error('no inputs given'); end
		
	V = zeros(0, 3);
	F = zeros(0, 3);

	offset = size(V, 1);
	for i = 1:nargin
		for j = 1:numel(varargin{i})
			V_new = varargin{i}(j).v;
			F_new = varargin{i}(j).f;

			V = [V; V_new];
			if size(F_new, 2) > size(F, 2), F = [F, NaN(size(F, 1), size(F_new, 2) - size(F, 2))]; end
			if size(F_new, 2) < size(F, 2)
				F = [F; offset + F_new, NaN(size(F_new, 1), size(F, 2) - size(F_new, 2))];
			else, F = [F; offset + F_new];
			end

			offset = offset + size(V_new, 1);
		end
	end

	s = geoGeneric(V, F);
end