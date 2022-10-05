function geoTest

	createStage(6 * [-1 1 -1 1 -1 1]);
	rotate3d;
	grid off;
	triade;

	obj = createObject(transform(T_shift(1 * [-1 -1 0]), geoExtrude(2 * [0 0; 1 0; 1 1; 0 1], 5, 20)));
  	obj.setFaceColor([1 0.7 0.3]);
  	obj.setWireframeColor([0 0 0]);
	
	waitForClick();
	m = morphBend(10);
%	m.place(T_rot('Z', pi / 4));
	obj.setMorpher(m);
return;
	waitForClick();
	m = morphTwist(pi / 10);
	obj.setMorpher(m);
	
end