%%
%   out = morph(morpher, in)
%
% Applies the morphing operation determined by 'morpher' to the given input.
% The following formats are supported for the input data 'in':
% - n x 3 matrix of XYZ coordinate triples
% - mesh data as created by the geo...-functions (only the vertices-part
%   will be changed by this function)
% The return value will be in the same format as the input data
%
% See also: morphBend, morphTwist, morphGeneric
%
function out = morph(m, in)
	if isfield(m, 'getPlacement'), T = m.getPlacement();
	else T = []; end
	
	if isstruct(in)
		%geometry
		out = in;
		if ~isempty(T), out.v = transform(T, m.apply(transform(inv(T), in.v)));
		else, out.v = m.apply(in.v); end
	else
		% vertex array
		if ~isempty(T), out = transform(T, m.apply(transform(inv(T), in)));
		else, out = m.apply(in); end
	end
end
