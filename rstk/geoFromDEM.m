function s = geoFromDEM(DEM, XRange, YRange, ZRange)
	if nargin < 1, error('Too few arguments'); end
    
    if ischar(DEM)
        % try to load image and extract grayscale DEM data from it
        DEM = imread(DEM);                
    end
    sz = size(DEM);
    if numel(sz) == 3 && sz(3) >= 3
        DEM = (DEM(:, :, 1) * 11 + DEM(:, :, 2) * 16 + DEM(:, :, 3) * 5);
    end
    
    DEM = double(DEM); % no-op if DEM is already double
    
    sz = size(DEM);
    if numel(sz) ~= 2 || any(sz < 2), error('Invalid dimensions for first input argument'); end

    if nargin >= 2 && ~isempty(XRange)
        if numel(XRange) ~= sz(2)
            if numel(XRange) == 2
                XRange = linspace(XRange(1), XRange(2), sz(2));
            else error('Invalid XRange input');
            end
        end
    else XRange = 1:sz(2);
    end
    if nargin >= 3 && ~isempty(YRange)
        if numel(YRange) ~= sz(1)
            if numel(YRange) == 2
                YRange = linspace(YRange(1), YRange(2), sz(1));
            else error('Invalid YRange input');
            end
        end
    else YRange = 1:sz(1);
    end
    if nargin >= 4,
        if numel(ZRange) == 2
            maxZ = max(max(DEM));
            DEM = ZRange(1) + (ZRange(2) - ZRange(1)) / maxZ * DEM;            
        else error('Invalid ZRange input');
        end
    end
    
    [XData, YData] = meshgrid(XRange, YRange);    
    vertices = [reshape(XData, [], 1), reshape(YData, [], 1), reshape(DEM, [], 1)];
    N = sz(2);
    M = sz(1);
    pattern = reshape(repmat((1:(M - 1))', 1, N - 1) + repmat(0:M:((N - 1) * M - 1), M - 1, 1), [], 1);
    faces = [pattern, pattern + 1, pattern + M + 1; pattern, pattern + M + 1, pattern + M];
    
    s = geoGeneric(vertices, faces);
end