%%
%   group = createObjectGroup(object1, object2, object3, ...)
%
% Creates a group object from the objects given as arguments.
% A group object combines several objects connected in some way into a single entity.
% The return value is a structure with the following fields and members:
% - objects:          cell Array containing the grouped objects
% - add(...):         Adds more objects to the group.
% - show(), hide(), place(), delete(), 
%   setShowFaces(), setFaceColor(), setShowWireframe(), setWireframeColor(), 
%   setShowVertices(), setVertexColor(), setTransparency():
%                     Invokes the identically named functions of each object in 
%                     the group. Refer to the object's method documentations for a 
%                     description of the parameters.
% Because group objects expose much of the same functionality as
% single objects do, most code written for single objects will be able to handle
% group objects in the expected way without modifications. 
% Therefore recursive grouping should be possible, too.
% 
% See also: createObject
%
function s = createObjectGroup(varargin)
	s = struct('objects', cell2mat(cellfun(@(a)reshape(a, 1, []), varargin, 'UniformOutput', false)));	
	
	if ~isempty(s.objects)
		foreach(@(o)o.place(s.objects(1).placement()));
	end
	
	s.show = @()foreach(@(o)o.show());
	s.hide = @()foreach(@(o)o.hide());
    s.getVisibility = @()(mean(arrayfun(@(o)o.getVisibility(), s.objects)) > 0.5);
    
	s.place = @(placement)foreach(@(o)o.place(placement));
	s.delete = @()foreach(@(o)o.delete());

	s.setShowFaces = @(b)foreach(@(o)o.setShowFaces(b));
	s.setFaceColor = @(c)foreach(@(o)o.setFaceColor(c));
	s.setShowWireframe = @(b)foreach(@(o)o.setShowWireframe(b));
	s.setWireframeColor = @(c)foreach(@(o)o.setWireframeColor(c));
	s.setShowVertices = @(b)foreach(@(o)o.setShowVertices(b));
	s.setVertexColor = @(c)foreach(@(o)o.setVertexColor(c));
	s.setTransparency = @(a)foreach(@(o)o.setTransparency(a));
	
	s.add = @addObjects;
	function addObjects(varargin)
		nOld = numel(s.objects);
		s.objects = [s.objects, cell2mat(cellfun(@(a)reshape(a, 1, []), varargin, 'UniformOutput', false))];
		if ~isempty(s.objects)
			for i = (nOld + 1):numel(s.objects), s.objects(i).place(s.objects(1).placement()); end
		end
	end
	
	function foreach(fun)
		for i = 1:numel(s.objects)
			fun(s.objects(i));
		end
	end
end
