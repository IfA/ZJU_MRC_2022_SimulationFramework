%%
%   m = morphTwist(amount)
%
% Creates a morpher will rotate each point around the Z axis by the angle 
%                 'amount' * z_coordinate_of_point
% (i.e. the 'amount' parameter specifies the rotation angle for z = 1).
% 
% See also: morph, morphBend, morphGeneric
%
function m = morphTwist(amount)
	
	m = morphGeneric();
	
	m.apply = @apply;
	function out = apply(in)
		rads = sqrt(sum(in(:, 1:2) .^ 2, 2));
		phis = atan2(in(:, 2), in(:, 1)) + amount * in(:, 3);
		out = [rads .* cos(phis), rads .* sin(phis), in(:, 3)];
	end	
end