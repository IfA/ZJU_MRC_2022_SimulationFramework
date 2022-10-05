function geoTest

	createStage(6 * [-1 1 -1 1 -1 1]);
	rotate3d;
	grid off;
	t = triade
	waitForClick();
	t.highlight('Y');
%	triade(T_unity(), 0.5 * [1 1 1])
	
%	triade(T_unity(), repmat([1 1 0; 1 0 1; 0 1 1], 2, 1), [1 2 0.5])
	animate(linspace(bla), ... % Zeitreihe
		    @fun(sdfsdf), ... % Animationsfunktion
			0.1); % Zeitintervall
end