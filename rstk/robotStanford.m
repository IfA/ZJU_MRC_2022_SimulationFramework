%%
%   r = robotStanford(d1, d2, maxD3, d6)
% 
% Creates all links and joins of a 6DOF manipulator consisting of a spherical arm 
% and a spherical wrist (stanford manipulator). Each link is optionally accompanied 
% by a 'triade' object group indicating their coordinate frame origin.
% The arguments specify 
% - the length of the first join, 
% - the length of the second join,
% - the maximum extent of the third join (last in arm) 
% - and the distance between the intersection of all wrist rotation axes and the 
%   tool center point
% in this order.
% 
% The return value is a struct with the following fields and member functions:
% - link0 .. link6:          link subobjects
% - org0 .. org1:            triades for each link's coordinate frame
% - getTcp():	             returns the current tool center point in global coordinates.
% - setTransparency(transp): sets the transparency for subobjects link0 .. link6 to 'trans'.
% - colorLinks(...):         Assigns the given arguments to the link's face colors, starting 
%                            with the base (link0) up to the gripper (link6).
%                            If there are less than 7 entries, the argument list is repeated.
%                            The triades are given the same color as their associated links. 
% - showOrigins():			 Makes all triades visible.
% - hideOrigins():           Hides all triades.
% - setJoins(theta1, ..., theta6): Sets all join angles.
% 
function robot = robotStanford(d1, d2, maxD3, d6)
	if d1 < 1 || d2 < 1, warning('parameters will give bad geometry'); end		

	tcp = [0 0 0];		

	robot = struct();
	robot.org0 = triade();
	robot.link0 = createObject(geoRotateCurve([.5 .5 .3 .3 .4 .4], [0 .2 .2 (d1-.5) (d1-.5) (d1-.4)], 40));


	t = linspace(-pi, 0, 17);
	robot.org1 = triade();
	robot.link1 = createObject( ...
					combineGeometry( ...
					  transform(T_shift(0, 0, -0.5), geoExtrude(0.3 * [-1, 1; cos(t'), sin(t'); 1, 1], 1)), ...
					  transform(T_rot('X', pi / 2) * T_shift(0, 0, -0.4), geoCylinder(0.4, 0.1))));

	robot.org2 = triade();

	robot.link2 = createObject( ...
					combineGeometry( ...
					  transform(T_shift(0, 0, -0.5), geoExtrude([.3 .3; .3 -.3; -.3 -.3; -.3 -.2; .2 -.2; .2 .2; -.3 .2; -.3 .3], 1)), ...
					  transform(T_rot('X', -pi / 2) * T_shift(0, 0, -(d2 - 0.8) - 0.3), geoCylinder(0.2, d2 - 0.8))));


	robot.org3 = triade(T_unity(), [], 0.5, 0.02);
	robot.link3 = createObject(transform(T_shift(-.2, -.2, -(maxD3 + 0.5)), geoBox(0.4, 0.4, maxD3 + 0.2)));

	robot.org4 = triade(T_unity(), [], 1, 0.015);
	robot.link4 = createObject(...
					combineGeometry( ...
					  transform(T_rot('X', pi / 2) * T_shift(0, 0, -0.3), geoCylinder(0.1, 0.05, 10)), ...
					  transform(T_shift(0, 0, -.15), geoExtrude([0.15 * cos(t'), 0.15 * sin(t'); 0.15, 0.25; -0.15, 0.25], 0.3))));

	robot.org5 = triade(T_unity(), [], 0.5, 0.015);
	geo5Part = transform(T_rot('X', -pi / 2), geoExtrude([0.15 * cos(t'), -0.15 * sin(t'); 0.15, -0.2; -0.15, -0.2], 0.05));
	robot.link5 = createObject(...
					combineGeometry(...
					  transform(T_shift(0, 0.15, 0), geo5Part), transform(T_shift(0, -0.2, 0), geo5Part), ...
				      transform(T_shift(-0.15, -0.2, 0.2), geoBox(0.3, 0.4, 0.05)), ...
					  transform(T_shift(0, 0, 0.25), geoCylinder(0.1, d6 - 0.5, 10))));

	robot.org6 = triade(T_unity(), [], 0.5, 0.015);
	robot.link6 = createObject(...
					combineGeometry(...
					  transform(T_shift(0.05, 0, 0) * T_rot('Y', -pi / 2), geoExtrude([.1 .1; .1 .15; -.05 .25; -.2 .25; -.2 -.25; -.05 -.25; .1 -.15; .1 -.1; -.1 -.1; -.1 .1], 0.1)), ...
					  transform(T_shift(0, 0, -0.25), geoCylinder(0.2, 0.05, 20))));
				  
	robot.setJoins = @setJoins;

	robot.getTcp = @getTcp;
	function [out] = getTcp()
		out = tcp;
	end
	robot.setTransparency = @setTransparency;
	function setTransparency(t)
		robot.link0.setTransparency(t);
		robot.link1.setTransparency(t);
		robot.link2.setTransparency(t);
		robot.link3.setTransparency(t);
		robot.link4.setTransparency(t);
		robot.link5.setTransparency(t);
		robot.link6.setTransparency(t);
	end
	robot.colorLinks = @colorLinks;
	function colorLinks(varargin)
		if nargin < 1, return; end
		robot.link0.setFaceColor(varargin{1 + mod(0, nargin)});		
		robot.org0.setColor(varargin{1 + mod(0, nargin)});
		robot.link1.setFaceColor(varargin{1 + mod(1, nargin)});
		robot.org1.setColor(varargin{1 + mod(1, nargin)});
		robot.link2.setFaceColor(varargin{1 + mod(2, nargin)});
		robot.org2.setColor(varargin{1 + mod(2, nargin)});
		robot.link3.setFaceColor(varargin{1 + mod(3, nargin)});		
		robot.org3.setColor(varargin{1 + mod(3, nargin)});		
		robot.link4.setFaceColor(varargin{1 + mod(4, nargin)});		
		robot.org4.setColor(varargin{1 + mod(4, nargin)});		
		robot.link5.setFaceColor(varargin{1 + mod(5, nargin)});		
		robot.org5.setColor(varargin{1 + mod(5, nargin)});
		robot.link6.setFaceColor(varargin{1 + mod(6, nargin)});		
		robot.org6.setColor(varargin{1 + mod(6, nargin)});		
	end
	robot.showOrigins = @()cellfun(@(o)o.show(), {robot.org0, robot.org1, robot.org2, robot.org3, robot.org4, robot.org5, robot.org6});
	robot.hideOrigins = @()cellfun(@(o)o.hide(), {robot.org0, robot.org1, robot.org2, robot.org3, robot.org4, robot.org5, robot.org6});
	
	setJoins(0, 0, 0, 0, 0, 0);
	
	function setJoins(theta1, theta2, d3, theta4, theta5, theta6)
		if nargin == 1 && numel(theta1) == 6
			theta6 = theta1(6);
			theta5 = theta1(5);
			theta4 = theta1(4);
			d3 = theta1(3);
			theta2 = theta1(2);
			theta1 = theta1(1);
		end
		T_1_0 = T_rot('Z', theta1) * T_shift(0, 0, d1) * T_rot('X', -pi / 2);
		T_2_1 = T_rot('Z', theta2) * T_shift(0, 0, d2) * T_rot('X', pi / 2);
		T_3_2 = T_rot('Z', -pi / 2) * T_shift(0, 0, d3);
		T_4_3 = T_rot('Z', theta4) * T_rot('X', -pi / 2);
		T_5_4 = T_rot('Z', theta5) * T_rot('X', pi / 2);
		T_6_5 = T_rot('Z', theta6) * T_shift(0, 0, d6);
		
		robot.org1.place(T_1_0);
		robot.link1.place(T_1_0);
		T_2_0 = T_1_0 * T_2_1;
		robot.org2.place(T_2_0);
		robot.link2.place(T_2_0);
		T_3_0 = T_2_0 * T_3_2;
		robot.org3.place(T_3_0);
		robot.link3.place(T_3_0);
		T_4_0 = T_3_0 * T_4_3;
		robot.org4.place(T_4_0);
		robot.link4.place(T_4_0);
		T_5_0 = T_4_0 * T_5_4;
		robot.org5.place(T_5_0);
		robot.link5.place(T_5_0);
		T_6_0 = T_5_0 * T_6_5;
		robot.org6.place(T_6_0);
		robot.link6.place(T_6_0);
		
		tcp = transform(T_6_0, [0 0 0]);
	end
end
