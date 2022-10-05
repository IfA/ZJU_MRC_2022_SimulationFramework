%%
%   animate(sequence, function, delta_t)
%
% Simple Helper function for animations. 
% Parameters:
% - sequence: Vector containing a parameter completely defining an animation step.
% - function: Handle to a function putting the parameter determined by 'sequence' into effect.
%             The function should expect a single parameter, where the element of 'sequence'
%             corresponding to the current animation step will be passed.
% - delta_t:  Optional time interval between steps in seconds. May be a scalar (same interval
%             for all steps or a vector of the same length as 'sequence'. (Default: 0.1s)
%
% During the animation, the display will be updated using 'drawnow', therefore callbacks
% might execute between animation steps.
% The following example will move an object along the T axis:
%   
%    obj = createObject(...);
%    animate(linspace(0, 5, 20), @(p)obj.place(T_shift(0, 0, p)));
%
function b = animate(seq, fun, dt)
	if nargin < 2, error('Too few arguments'); end
	if nargin < 3, dt = 0.1; end
	if isempty(dt), dt = 0.1; end
	
	if isempty(seq), return; end
	if numel(dt) ~= 1 && numel(dt) ~= numel(seq), error('sequence (first argument) and time intervals (3rd argument) must have the same number of elements'); end

	for i = 1:numel(seq)
		fun(seq(i));
		drawnow;
		if i > numel(dt), pause(dt(1)); else, pause(dt(i)); end
	end
end
