function c = fileCache(basePath, maxFiles)
    if isempty(maxFiles) || ~isnumeric(maxFiles) || length(maxFiles) ~= 1
        maxFiles = 10;
    end
    
    c = struct();
    c.saveMat = @saveMat;
    
    cache = repmat(struct('path', '', 'content', []), maxFiles, 1);    
    
    imfs = imformats;
    imgExts = [imfs.ext];
    clear imfs;
    
    % save data to file and cache
    function res = save(path, data, format, varargin)
        path = [basePath, '/', path];
        if isempty(format)
            try save(path, data, varargin{:});
            catch ME
                warning(ME.identifier, ME.message);
                res = false;
                return;
            end                
        else
            try imwrite(data, path, format, varargin{:});
            catch ME
                warning(ME.identifier, ME.message);
                res = false;
                return;
            end
        end
        
        % remove old occurences, if any
        iCache = strmatch(path, {cache.path}, 'exact');
        if isempty(iCache)        
            cache = [struct('path', path, 'content', data), cache(1:(end - 1))];
        else cache = [struct('path', path, 'content', data), cache(1:(iCache(1) - 1)), cache((iCache(1) + 1):end)];
        end         
        res = true;
    end

    % load data from cache, if possible, otherwise from file
    function [data, res] = load(path, format)        
        path = [basePath, '/', path];
        iCache = strmatch(path, {cache.path}, 'exact');
        if ~isempty(iCache)
            data = cache(iCache).content;
            res = true;
        else
            if isempty(format)
                try load(path, data);
                catch ME
                    warning(ME.identifier, ME.message);
                    res = false;
                    data = [];
                    return;
                end
            else 
                try data = imread(path, format);
                catch ME
                    warning(ME.identifier, ME.message);
                    res = false;
                    data = [];
                    return;
                end                
            end
            
            res = true;
            cache = [struct('path', path, 'content', data), cache(1:(end - 1))];            
        end
    end
end