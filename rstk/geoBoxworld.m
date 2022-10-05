function s = geoBoxworld(Mat, varargin)
	if nargin < 1, error('Too few arguments'); end
    
    if ~ismatrix(Mat) || ~isnumeric(Mat); error('Input argument 1 must be a matrix'); end
    
    sz = size(Mat);
    
    xRange = [];
    if nargin >= 2; xRange = checkRange(varargin{1}); end
    if isempty(xRange); xRange = [0 sz(2)]; end
    
    yRange = [];
    if nargin >= 3; yRange = checkRange(varargin{2}); end
    if isempty(yRange); yRange = [0 sz(1)]; end
    
    zRange = [];
    if nargin >= 4; zRange = checkRange(varargin{3}); end
    if ~isempty(zRange)
        % scale Height data in Z direction
        minVal = min(min(Mat));
        maxVal = max(max(Mat));
        Mat = zRange(1) + ((zRange(2) - zRange(1)) / (maxVal - minVal)) * (Mat - minVal);
    else zRange = [min(min(Mat)), max(max(Mat))];
    end
    
    
    xVec = reshape(repmat(xRange(1) + ((xRange(2) - xRange(1)) / sz(2)) * (0:1:sz(2)), 2, 1), 1, []);
    yVec = reshape(repmat(yRange(1) + ((yRange(2) - yRange(1)) / sz(1)) * (0:1:sz(1)), 2, 1), 1, []);
    
    [XGrid, YGrid] = meshgrid(xVec, yVec);
    
    Mat_T = Mat';
    
    ZGrid = reshape([Mat_T(:), Mat_T(:)]', 2 * sz(2), sz(1))';
    ZGrid = reshape([ZGrid(:), ZGrid(:)]', 2 * sz(1), 2 * sz(2));
    ZGrid = [zRange(1)*ones(size(ZGrid, 1) + 2, 1), [zRange(1)*ones(1, size(ZGrid, 2)); ZGrid; zRange(1)*ones(1, size(ZGrid, 2))], zRange(1)*ones(size(ZGrid, 1) + 2, 1)];
    
    vertices = [XGrid(:), YGrid(:), ZGrid(:)];
    nRows = size(ZGrid, 1);
    pattern1 = (2:2:(nRows - 2))';
    pattern1 = [pattern1, pattern1 + 1, pattern1 + nRows + 1, pattern1 + nRows];

    pattern2 = (1:2:nRows)';
    pattern2 = [pattern2, pattern2 + 1, pattern2 + nRows + 1, pattern2 + nRows];
    nRepeats1 = size(ZGrid, 2) - 1;   
    nRepeats2 = size(ZGrid, 2) / 2 - 1;
    faces = [repmat(pattern1, nRepeats1, 1) + repmat(reshape(repmat((0:(nRepeats1 - 1)) * nRows, size(pattern1, 1), 1), [], 1), 1, 4); ...
             repmat(pattern2, nRepeats2, 1) + repmat(reshape(repmat((1:2:(size(ZGrid, 2) - 3)) * nRows, size(pattern2, 1), 1), [], 1), 1, 4)];
    
    s = geoGeneric(vertices, faces);
end

function range = checkRange(range)
    if isempty(range); return; end
    
    if ~isvector(range) || ~isnumeric(range)
        error('Invalid range: expected numeric vector');
    end
    if isscalar(range); range = [0 range];
    elseif length(range) > 2
        error('Invalid number of elements for range');
    end
    if range(1) >= range(2),
        temp = range(1);
        range(1) = range(2);
        range(2) = temp;
    end
    if any(isinf(range)) || any(isnan(range))
        error('inf or nan in range');
    end        
end