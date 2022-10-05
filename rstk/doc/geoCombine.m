function geoTest

	createStage(2 * [-1 1 -1 1 -1 1]);
	rotate3d;
	grid off;

	box = createObject(geoBox([1 1 0.8]));
%  	box.setFaceColor([1, 1, 0.8]);
  	box.setFaceColor([1 0.7 0.3]);
	box.setWireframeColor([0 0 0]);
	box.place(T_shift(-0.5, -0.5, 0));

	pyramid = createObject(transform(T_scale(1.2) * T_shift(-0.5, -0.5, 0), geoGeneric([0 0 0; 1 0 0; 1 1 0; 0 1 0; 0.5 0.5 0.5], [1 2 3 4; 1 2 5 NaN; 2 3 5 NaN; 3 4 5 NaN; 4 1 5 NaN])));
%  	pyramid.setFaceColor([1 0.3 0.3]);
  	pyramid.setFaceColor([1 0.7 0.3]);
	pyramid.setWireframeColor([0 0 0]);
	pyramid.place(T_shift(0, 0, 0.8));
	
	waitForClick();
	pyramid.hide();
	waitForClick();
	pyramid.show();
	box.hide();
	

	
	
	
end