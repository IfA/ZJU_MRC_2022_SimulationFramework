%%
%   object = createObject(geo, 'Property', value, ...)
%
% Creates an object from the geometry passed as 'geo'.  
% Objects will be displayed using the MATLAB function 'patch'. Property/value
% arguments after the initial 'geo'-parameter will be handed over to this internal 
% patch call. The return value is a struct with various fields and methods.
% After creation, the internal patch handle is accessible as field 'h'. This allows
% for arbitrary property changes of the underlying patch object, e.g.
% 
%     obj = createObject(...);
%     set(obj.h, 'EdgeAlpha', 0.5);
%
% Each object has support for linear (affine) and nonlinear (morphing) transformations.
% Both can be either directly applied to the mesh data stored inside the object
% (using the .transform and .morph members) or installed as filter (using .place and .setMorpher), 
% that will modify the data before display, but will not change the data itself.
% In the former case, multiple consecutive calls to the transformation functions will accumulate, where
% in The latter case, a new transformation will always replace the old one. This is especially
% useful for animations.
% 
% The following members are available in all objects:
% - show():               Displays the object if it was invisible before (Changes
%                         the underlying patch object's property 'Visible' to 'on')
% - hide():               Make the object invisible (Changes the 'Visible' property to 'off')
% - setVisibility(b)      call show() or hide() depending on argument
% - getVisibility()       Return true, if object is visible.
% - delete():             Destructor. Deletes the underlying patch object.
% - transform(T):         Applies the 4x4 transformation matrix T to the object's mesh data.
% - place(T):             Installs T as an affine transformation filter for the object's mesh data.
%                         (Displays a transformed object without changing the stored mesh data).
% - placement():          Returnes the transformation matrix previously set by place()
% - morph(m):             Applies a nonlinear morphing to the object's mesh data.
% - setMorpher(m):        Installs a morphing filter for the object.
%                         (Similarily to place(), the object will show up transformed, but the internal
%                         mesh data will remain unchanged).
% - setGeometry(geo):     Replaces the stored mesh data with 'geo'.
% - addGeometry(geo):     Adds the mesh data given by 'geo' to the one already stored inside the object
%                         using combineGeometry.
% - setShowFaces(b):      Toggles displaying of the object's faces.
% - setFaceColor(c):      Changes the object's faces color.
% - setShowWireframe(b):  Toggles displaying of the object's wireframe (edges).
% - setWireframeColor(c): Sets the object's wireframe color. This will enable wireframe display, if not enabled before.
% - setShowVertices(b):   Toggles displaying of the object's vertices.
% - setVertexColor(c):    Sets the vertex color of the object. This will enable vertex display, if not enabled before.
% - setTransparency(t):   Changes the object's transparency from t = 0 (opaque) to t = 1 (invisible)
%
% See also: createObjectGroup
%
function s = createObject(geo, varargin)

	faceColor = [0.5 0.5 0.5];

	% generate handle graphics object
	vertices = geo.v;
	T = T_unity();
	
	h = patch('Vertices', vertices, 'Faces', geo.f, 'FaceLighting', 'gouraud', 'EdgeLighting', 'none', 'FaceColor', faceColor, 'EdgeColor', [0 0 0], 'LineStyle', 'none', 'Marker', 'none', varargin{:});
	
	% initialize transformation (for placement)
	T = T_unity();
	
	% create "object"
	s = struct('handle', h);
	% morpherObject
	morpher = [];
	morphedVertices = [];
	
	% add "member functions"
	s.placement = @getPlacement;
	function placement = getPlacement
		placement = T;
	end
	s.show = @()set(h, 'Visible', 'on');
	s.hide = @()set(h, 'Visible', 'off');
	s.getVisibility = @()strcmp(get(h, 'Visible'), 'on');
    s.setVisibility = @(on)set(h, 'Visible', cond(on, 'on', 'off'));
    
	s.transform = @transformGeometry;
	function transformGeometry(trans)
		vertices = transform(trans, vertices);
		updateVertices(1);
	end
	s.morph = @morphGeometry;
	function morphGeometry(m)
		vertices = morph(m, vertices);
		updateVertices(1);
	end
	s.setGeometry = @setGeometry;
	function setGeometry(geo)
		vertices = geo.v;
		if ~isempty(morpher), morphedVertices = morph(morpher, vertices); end
		set(h, 'Vertices', transform(T, cond(isempty(morpher), vertices, morphedVertices)), 'Faces', geo.f);
	end
	s.addGeometry = @addGeometry;
	function addGeometry(varargin)
		setGeometry(combineGeometry(geoGeneric(vertices, get(h, 'Faces')), varargin{:}));
	end
	s.place = @place;
	function place(placement)
		T = placement;
		updateVertices(0);
	end
	s.setMorpher = @setMorpher;
	function setMorpher(newMorpher)
		morpher = newMorpher;
		if isempty(morpher), morphedVertices = []; end;
		updateVertices(1);
	end

	s.delete = @()delete(h);
	
	s.setShowFaces = @setShowFaces;
	function setShowFaces(b)
		set(h, 'FaceColor', cond(b, faceColor, 'none'));
	end
	s.setFaceColor = @setFaceColor;
	function setFaceColor(c)
		set(h, 'FaceColor', c);
		faceColor = c;		
	end
	s.setShowWireframe = @(b)set(h, 'LineStyle', cond(b, '-', 'none'));
	s.setWireframeColor = @(c)set(h, 'EdgeColor', c, 'LineStyle', '-');
	s.setShowVertices = @(b)set(h, 'Marker', cond(b, '.', 'none'));
	s.setVertexColor = @(c)set(h, 'MarkerEdgeColor', c, 'MarkerFaceColor', c, 'Marker', '.');	
	s.setTransparency = @(a)set(h, 'FaceAlpha', a, 'EdgeAlpha', a);
	
	% helpers
	function r = cond(expr, truepart, falsePart)
		if expr; r = truepart; else r = falsePart; end
	end

	function updateVertices(doMorph)
		if isempty(morpher), set(h, 'Vertices', transform(T, vertices));
		else
			if doMorph, morphedVertices = morph(morpher, vertices); end
			set(h, 'Vertices', transform(T, morphedVertices));
		end
	end
end