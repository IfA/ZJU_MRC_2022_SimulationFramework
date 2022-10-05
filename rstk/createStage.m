%%
%   ax = createStage(range, view, title)
%   ax = createStage(view, title)
%   ax = createStage(title)
%   ax = createStage()
%
% Convenience function for creating an axes object. The grid is switched on by default.
% Parameters (all optional):
% range: Values for properties 'XLim', 'YLim' and 'ZLim' in a single 6-element vector.
%        (default: [-1 1 -1 1 -1 1])
% view:  2-element vector [azimut, elevation] (elements in degree) as expected by the 'view' 
%        function. (default: [75, 25])
% title: figure title (default: no title);
%
% See also: axes, view, title
%
function ax = createStage(varargin)
	% defaults:
	range = [-1 1 -1 1 -1 1];
	view_spec = [75 25];
	title_string = '';
	
	iarg = 1;
	if nargin >= iarg
		arg = varargin{iarg};
		if isnumeric(arg) && numel(arg) == 6, iarg = iarg + 1; range = arg; end
	end
	if nargin >= iarg
		arg = varargin{iarg};
		if isnumeric(arg) && numel(arg) == 2, iarg = iarg + 1; view_spec = arg; end
	end
	if nargin >= iarg
		arg = varargin{iarg};
		if ischar(arg), iarg = iarg + 1; title_string = arg; end
	end
	
	figure('Renderer', 'OpenGl', 'toolbar', 'figure');
	ax = axes('XLim', range(1:2), 'YLim', range(3:4), 'ZLim', range(5:6), varargin{iarg:end});
	view(view_spec);
	camlight('headlight');
	axis equal;
	grid on;

	if ~isempty(title_string), title(title_string); end

	xlabel('X');
	ylabel('Y');
	zlabel('Z');
	
end
