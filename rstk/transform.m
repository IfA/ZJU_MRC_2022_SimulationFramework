%%
%    transformedData = transform(trans, data)
%
% Applies the affine coordinate transformation 'trans' to 'data'.
%
% Parameters:
% - trans: 4x4 transformation matrix (see T_...-functions)
% - data: geometric data to transform. The following formats are supported:
%   - n x 3 matrix of coordinate (X, Y, Z)-triples
%   - mesh data as created by the geo...-functions (only the vertices-part
%     will be changed by this function)
% The return value will be in the same format as the input data
%
function out = transform(T, in)
	if isstruct(in) % assume geometry structure
		out	= in;
		Res = T * [in.v, ones(size(in.v, 1), 1)]';
		out.v = Res(1:3, :)';
	else
		Res = T * [in, ones(size(in, 1), 1)]';
		out = Res(1:3, :)';
	end
end