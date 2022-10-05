function geoTest

	createStage(10 * [-1 1 -1 1 -1 1]);
	rotate3d;
	grid off;

%  	box = createObject(transform(T_shift(-1, -2, -1.5), geoBox([2 4 3])), 'FaceAlpha', 0.7);
%  	box.setFaceColor([0.5 0.5 1]);
%  	box.setWireframeColor([0 0 0]);
%  	box.setVertexColor([1 0 0]);

% 	cylinder = createObject(transform(T_shift([-1 -1 -1.5]), geoCylinder(1, 3, 15)), 'FaceAlpha', 0.8);
% 	cylinder.setFaceColor([0.5 0.5 1]);
% 	cylinder.setWireframeColor([0 0 0]);

%  	ball = createObject(transform(T_shift(-1, -1, -1), geoEllipsoid(1, 15)), 'FaceAlpha', 1);
%  	ball.setFaceColor([0.5 0.5 1]);
%  	ball.setWireframeColor([0 0 0]);

% 	torus = createObject(transform(T_shift(-2, -2, -.25), geoTorus(2, 0.5)), 'FaceAlpha', 1);
%  	torus.setFaceColor([0.5 1 1]);
%  	torus.setWireframeColor([0 0 0]);

% 	cone = createObject(transform(T_shift(-1.5, -1.5, -1), geoCone(1.5, 3, 16)), 'FaceAlpha', 0.7);
%  	cone.setFaceColor([0.5 1 1]);
%  	cone.setWireframeColor([0 0 0]);
% 	cone.setVertexColor([1 0 0]);

% 	N = 5;
% 	t = linspace(0, 2 * pi, 2 * N + 1)';
% 	t = t(1:(end - 1));
% 	r = repmat([2; 1], N, 1);
% 	XY = [r .* cos(t), r .* sin(t)];
% 	star = createObject(transform(T_shift(-2, -2, 0), geoShape(XY)));
%  	star.setFaceColor([0.5 1 1]);
%  	star.setWireframeColor([0 0 0]);
% 	star.setVertexColor([1 0 0]);

	cont = [1, 0; 2, 0; 2, 1; 2.2, 1; 1.5, 1.5; 0.8, 1; 1, 1];
	rot = createObject(transform(T_shift(0, 0, -0.5), geoRotateContour(cont, 50, [0, 270 * pi / 180], 'both')));
	rot.setFaceColor([1 1 0.3]);
	rot.setWireframeColor([0 0 0]);

	t = linspace(0.1 * pi, 1.75 * pi, 12);
	rot = createObject(transform(T_shift(0, 0, -1), geoRotateCurve([1 + 0.3 * sin(t), NaN], 2, 16)), 'FaceAlpha', 0.8);
	rot.setFaceColor([1 1 0.3]);
	rot.setWireframeColor([0 0 0]);

% 	N = 12;
% 	t = linspace(0, 2 * pi, 2 * N + 1)';
% 	t = t(1:(end - 1));
% 	r = repmat([2; 1.8], N, 1);
% 	XY = [r .* cos(t), r .* sin(t)];
% 	ext = createObject(transform(T_shift(0, 0, -0.5), geoExtrude(XY, 1)), 'FaceAlpha',1);
% 	ext.setFaceColor([1 1 0.3]);
% 	ext.setWireframeColor([0 0 0]);
% 	ext.setVertexColor([1 0 0]);

end