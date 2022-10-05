function [envGroup, obstacleMap] = grp_obstacles_and_landmarks_from_image(path, varargin)
    args = struct(varargin{:});
    if ~isfield(args, 'obstacleColor')
        args.obstacleColor = [0 0 0];
    end
    if ~isfield(args, 'landmarkColor')
        args.landmarkColor = [0 1 0];
    end
    if ~isfield(args, 'scale')
        args.scale = 0.01;
    end    
    
    info = imfinfo(path);
    if info.BitDepth > 8,
        error('Invalid image format. Only images with indexed colors supported!');
    end
    mapImg = imread(path);        
    obst_idx = find(sum(abs(info.Colormap - repmat(args.obstacleColor, size(info.Colormap, 1), 1)), 2) == 0, 1, 'first') - 1;
    if isempty(obst_idx), 		
        warning('grp_obstacles_and_landmarks_from_image:not_found', 'obstacle color not found in image'); 
        obst_idx = -1;
    end
    lm_idx = find(sum(abs(info.Colormap - repmat(args.landmarkColor, size(info.Colormap, 1), 1)), 2) == 0, 1, 'first') - 1;
    if isempty(lm_idx), 		
        warning('grp_obstacles_and_landmarks_from_image:not_found', 'landmark color not found in image'); 
        lm_idx = -1;
    end
    
    obstacleMap = (mapImg == obst_idx);
    envGroup.obstacles = env_gridmap(obstacleMap);
    envGroup.obstacles.scale = args.scale;
    
    landmarks = zeros(0, 2);
    if ~isempty(args.landmarkColor)
        temp = which('bwlabel');
        if ~isempty(temp)
            [labelMap, numLm] = bwlabel(mapImg == lm_idx);

            if numLm > 0
                sumX = zeros(numLm, 1);
                sumY = zeros(numLm, 1);
                N = zeros(numLm, 1);

                for x = 1:size(labelMap, 2)
                    for y = 1:size(labelMap, 1)
                        label = labelMap(y, x);
                        if label > 0
                            sumX(label) = sumX(label) + x;
                            sumY(label) = sumY(label) + y;
                            N(label) = N(label) + 1;
                        end
                    end
                end				
                landmarks = args.scale * ([sumX ./ N, sumY ./ N] + 0.5);
            end
        else
            warning('grp_obstacles_and_landmarks_from_image:toolbox', 'Image processing toolbox not installed. Could not extract landmarks.');
        end
    end    
    envGroup.landmarks = const_points(landmarks);
    envGroup.landmarks.format = {'Marker', 'd', 'MarkerFaceColor', 0.7 * [1 1 1], 'MarkerSize', 8, 'MarkerEdgeColor', 0.2 * [1 1 1]};

end