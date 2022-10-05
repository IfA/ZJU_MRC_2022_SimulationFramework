%%
%   morphGroup = createMorphGroup(morpher1, morpher2, ...)
%
% Combines several nonlinear transformations (morphs) to a more
% complex nonlinear transformation. Applying the morph group will result
% in consecutively applying the elementary morphs in the given order.
%
% See also: morph, createObject
%
function mg = createMorphGroup(varargin)
	morphs = varargin;
	
	mg = struct();
	mg.apply = @apply;
	function out = apply(in)
		if isempty(morphs), out = in;
		else
			out = morph(morphs{1}, in);
			for i = 2:numel(morphs)
				out = morph(morphs{i}, out);
			end
		end
	end
end