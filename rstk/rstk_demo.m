%%
%    rstk_demo
%
% simple demonstration of some rstk features.
%
function rstk_demo
	clc;
	clear all;
	close all;

	createStage(5 * [-1 1 -1 1 -1 1], [55 19]);

	core = createObject(geoEllipsoid(1, 20), 'FaceColor', [0.3 0.3 1]);
	core.setTransparency(0.5);
	
	electrons(1) = createElectron(3, T_rot('X', 10 * pi / 180, 'Y', 25 * pi / 180));
	electrons(2) = createElectron(3.5, T_rot('X', -45 * pi / 180, 'Y', 35 * pi / 180), -pi / 4);
	electrons(3) = createElectron(4, T_rot('X', 15 * pi / 180, 'Y', 70 * pi / 180), pi);
	
	t = linspace(0, 2 * pi, 50);
	t = t(1:(end - 1));
	rotate3d;
	while true
		animate(t, @animStep, 0.05);
	end
	
	function animStep(phase)
		electrons(1).setPhase(phase);
		electrons(2).setPhase(3 * phase);
		electrons(3).setPhase(2 * phase);		
	end
	
	function e = createElectron(r, T, phase_offset)
		if nargin < 3, phase_offset = 0; end
		e = struct;
		e.r = r;
		e.T = T;
		e.phase_offset = phase_offset;
		e.electron = createObject(transform(T_shift(r, 0, 0), geoEllipsoid(0.5, 10)), 'FaceColor', [1 1 0]);		
		e.torus = createObject(geoTorus(r, 0.1), 'FaceColor', 0.8 * [1 1 1]);
		e.electron.place(T * T_rot('Z', phase_offset));
		e.torus.place(T);
		e.setPhase = @(phase)e.electron.place(T * T_rot('Z', phase_offset + phase));
	end
end
