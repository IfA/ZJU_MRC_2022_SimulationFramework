function setupPaths(varargin)
    myPath = fileparts(mfilename('fullpath'));
    
    relPaths = {'blocks/', 'sim-core/', 'sim-core/blocks/', 'tools/input/', 'tools/mex/matlab/', 'rstk/'};

    doSave = false;
    op = 'add';
    
    for i = 1:nargin
        arg = varargin{i};
        switch(arg)
        case {'add', 'setup', 'install'}
            op = 'add';
        case {'rm', 'del', 'remove', 'uninstall', 'delete'}
            op = 'rm';
        case 'save'
            doSave = true;
        otherwise
            error('sim:setupPaths', 'Invalid parameters');
        end
    end
    
    switch(op)
        case 'add'
            for i = 1:length(relPaths)
                p = fullfile(myPath, relPaths{i});
                fprintf('add "%s" to search path\n', p);
                addpath(p);
            end
        case 'rm'
            for i = 1:length(relPaths)
                p = fullfile(myPath, relPaths{i});
                fprintf('remove "%s" from search path\n', p);
                rmpath(p);
            end
    end
    
    if doSave
        savepath();
    end    
end