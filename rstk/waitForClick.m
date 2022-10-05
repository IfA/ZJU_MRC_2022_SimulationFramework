%% 
%    waitForClick()
%
% Delays script execution until the next mouse event.
% (wrapper for waitforbuttonpress that ignores keyboard events.)
%
function waitForClick()
	while true
		if waitforbuttonpress() == 0, break; end
	end
end