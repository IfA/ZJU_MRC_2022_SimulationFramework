%%
%   m = morphBend(amount)
%
% Creates a morpher will bend the YZ-Plane to an infinite cylinder of radius 'amount'.
% 
% See also: morph, morphTwist, morphGeneric
%
function m = morphBend(radius)

	m = morphGeneric();
	
	m.apply = @apply;
	function out = apply(in)
		rads = radius - in(:, 1);
		phis = (pi / 2) * in(:, 3) / radius;
		
		out = [radius - rads .* (cos(phis)), in(:, 2), rads .* sin(phis)];
	end	
end