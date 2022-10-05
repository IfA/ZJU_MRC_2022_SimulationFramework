function mapper = map_occupancy_grid(varargin)
    mapper = block_base('sensors/rangefinder', {'platform', 'sensors/rangefinder'}, @process);    
    mapper.log.disabled = true;
    
    mapper.mexFiles{end + 1} = fullfile(fileparts(mfilename('fullpath')), 'mex_occupancy_grid_rangefinder_model.cpp');
    
    mapper.graphicElements(end + 1).draw = @drawMap;    
    mapper.default_size = 1; % size as [w, h] or same value for both    
    if nargin == 1
        sz = varargin{1};
        if ~isnumeric(sz) || ~isreal(sz) || numel(sz) < 1 || numel(sz) > 2 || any(sz <= 0)
            error('Invalid size argument: Expected scalar or two-element vector of positive elements');
        end
        mapper.default_size = sz;
    elseif nargin > 1
        error('Too many input arguments');
    end
    mapper.default_scale = 0.02; % m/cell
    mapper.default_offset = [0 0];    
    mapper.default_color = [1 0 0];
    
    mapper.default_rangeError = 0.01; % in % of the measured distance
    mapper.default_maxRange = 4; % in m (should match with rangefinder.maxRange)
    mapper.default_rayWidth = 1 * pi / 180;
    mapper.default_prior = 0.5;
    mapper.default_pFree = 0.3;
    mapper.default_pOccupied = 0.7;
    
    
    function handles = drawMap(block, ax, handles, out, debugOut, state, varargin)
        if isempty(handles) 
            handles = image('Parent', ax);
        end        
        set(handles, 'CData', repmat(zeros(size(out.map)), [1 1 3]), ...
                     'AlphaData', out.map, ...
                     'XData', out.offset(1) + out.scale * ((1:size(out.map, 2)) - 0.5), ...
                     'YData', out.offset(2) + out.scale * ((1:size(out.map, 1)) - 0.5));
    end
end

function [state, out, debugOut] = process(block, t, state, poseProvider, rangefinder)
    debugOut = [];
    if ~isempty(poseProvider)
        logPrior = log(block.prior / (1 - block.prior));
        if isempty(state)
            sz = block.size;
            if numel(sz) == 1; sz = [sz, sz]; end            
            sz = round(sz / block.scale);
            sz(sz <= 1) = 1;
            state = logPrior * ones(sz(2), sz(1));
        end
        
        pose = poseProvider(end).data;
        [bearings, idxs] = sort(mod(rangefinder(end).data.bearing + pose(3) + pi, 2 * pi) - pi);
        ranges = rangefinder(end).data.range(idxs);
                
        args.size = [size(state, 2), size(state, 1)];
        args.scale = block.scale;
        args.offset = block.offset;
        args.maxRange = block.maxRange;
        args.rangeError = block.rangeError;
        args.rayWidth = block.rayWidth;
        args.prior = block.prior;
        args.pFree = block.pFree;
        args.pOccupied = block.pOccupied;
        args.pos = pose(1:2);
        args.bearings = bearings;
        args.ranges = ranges;

        % compute the rectangle inside the 
        xRange = pose(1) + (1 + 3 * block.rangeError) * args.maxRange * [-1, 1];
        yRange = pose(2) + (1 + 3 * block.rangeError) * args.maxRange * [-1, 1];
                
        xRangeMap = round((xRange - block.offset(1)) / block.scale);
        yRangeMap = round((yRange - block.offset(2)) / block.scale);

        xRangeMap(xRangeMap < 1) = 1;
        xRangeMap(xRangeMap > size(state, 2)) = size(state, 2);
        yRangeMap(yRangeMap < 1) = 1;
        yRangeMap(yRangeMap > size(state, 1)) = size(state, 1);        
        
        xRange = xRangeMap * block.scale + block.offset(1);
        yRange = yRangeMap * block.scale + block.offset(2);
        
        args.size = [xRangeMap(2) - xRangeMap(1) + 1, yRangeMap(2) - yRangeMap(1) + 1];
        args.offset = [xRange(1), yRange(1)];
        
        % call the mex file
        logUpdate = mex_occupancy_grid_rangefinder_model(args);
        % update the occupancy grid
        state(yRangeMap(1):yRangeMap(2), xRangeMap(1):xRangeMap(2)) = state(yRangeMap(1):yRangeMap(2), xRangeMap(1):xRangeMap(2)) - logPrior + logUpdate;
    end
    
    % convert from log-likelihoods (state) to probabilities (out)
    out.map = 1 - (1 ./ (1 + exp(state)));
    out.scale = block.scale;
    out.offset = block.offset;
end