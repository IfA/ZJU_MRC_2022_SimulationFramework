function geoTest

	createStage(2 * [-1 1 -1 1 -1 1]);
	rotate3d;
	grid off;
	triade;

 	box = createObject(geoBox(0.5 * [1 1 1]), 'FaceAlpha', 0.8);
  	box.setFaceColor([1 0.7 0.3]);
  	box.setWireframeColor([0 0 0]);
	waitForClick();
	box.transform(T_shift(-0.25, -0.25, -0.25));
	waitForClick();
	box.transform(T_rot('XYZ', pi / 4 * [1 1 1]));
end