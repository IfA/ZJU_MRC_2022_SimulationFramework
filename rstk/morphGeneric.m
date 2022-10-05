%%
%   m = morphGeneric(T)
%
% Creates a generic morpher object. The optional parameter 'T' is a transformation
% matrix specifying the location morpher. If left out, T_unity is assumed.
% The return value is a struct with the following members:
% - getPlacement(): returns the placement transformation matrix
% - place(T):       Changes the placement to the given argument.
% 
% The returned object is kind of an abstract base class, lacking the 'apply' member 
% function that will do the actual morphing.
% This member function must be added manually as described below:
% 
%    m.apply = @apply
%    function [out] = apply(in)
%       ...
%    end
%
% The function should take an array of XYZ triples and return their morphed counterparts 
% in the same arrangement. The internal morphing operation has not to cope with the morpher's
% placement, since the calling context will always carry out all neccessary transformations. 
% 
% See also: morph, morphBend, morphTwist
%
function m = morphGeneric(T)
	if nargin < 1, T = T_unity(); end

	m = struct();
	
	m.getPlacement = @getPlacement;
	function placement = getPlacement
		placement = T;
	end
	m.place = @place;
	function place(placement)
		T = placement;
	end
	
end