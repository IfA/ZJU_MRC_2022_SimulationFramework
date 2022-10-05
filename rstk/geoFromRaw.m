function s = geoFromRaw(fileName)
	raw = textread(fileName, '', 'emptyvalue', NaN);
	
	vertices = [];
	faces = [];
	for i = 1:size(raw, 1)
		line = raw(i, :);
		line(isnan(line)) = [];
		NVertices = size(vertices, 1);
		if numel(line) == 9			
			if norm(cross(line(4:6) - line(1:3), line(7:9) - line(1:3))) > 0
				vertices = [vertices; line(1:3); line(4:6); line(7:9)];
				faces = [faces; NVertices + [1 2 3]];
			end
		elseif numel(line == 12)
			valid = 0;
			if norm(cross(line(4:6) - line(1:3), line(7:9) - line(1:3))) > 0, valid = valid + 1; end
			if norm(cross(line(10:12) - line(1:3), line(7:9) - line(1:3))) > 0, valid = valid + 2; end
			if valid == 1,
				vertices = [vertices; line(1:3); line(4:6); line(7:9)];
				faces = [faces; NVertices + [1 2 3]];
			elseif valid == 2,
				vertices = [vertices; line(1:3); line(7:9); line(10:12)];
				faces = [faces; NVertices + [1 2 3]];				
			elseif valid == 3,
				vertices = [vertices; line(1:3); line(4:6); line(7:9); line(10:12)];
				faces = [faces; NVertices + [1 2 3]; NVertices + [3 4 1]];							
			end			
		else
			warning(sprintf('Invalid line %d in file -- ignoring', i));
		end
	end	
	s = geoGeneric(vertices, faces);
end