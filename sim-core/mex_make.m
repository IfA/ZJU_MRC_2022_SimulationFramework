% Generate mex files from source(s)
%
function mex_make(varargin)    
	
    originalDirectory = pwd();
    try 
        ext = mexext();
        for i = 1:nargin
            spec = varargin{i};
            if isempty(spec); continue; end

            if ischar(spec)
                spec = struct('file', spec);
            elseif isstruct(spec) && numel(spec) == 1
                if ~isfield(spec, 'file')
                    error('mex_make:input', 'Structure missing required field "file"');
                end
            else error('mex_make:input', 'Invalid input format. Use either a string (character array) or a one-element struct');
            end


            dependencies = {};
            if isfield(spec, 'dependencies')
                if ischar(spec.dependencies)
                    dependencies = {spec.dependencies};
                elseif iscell(spec.dependencies)
                    if any(cellfun(@(c)~ischar(c), spec.dependencies))
                        error('mex_make:input', 'At least one dependency is not a string.');                
                    end
                    dependencies = spec.dependencies;
                else error('mex_make: input', 'Invalid  format for dependencies. Expected string or cell array of strings');
                end            
            end

            [sourcePath, sourceFileBase, sourceExt] = fileparts(spec.file);
            cd(sourcePath);
            sourceFileName = [sourceFileBase sourceExt];
            mexFile = [sourceFileBase, '.', ext];

			bInfo = dir(mexFile);
			recompile = isempty(bInfo);
			if ~recompile
				sInfo = dir(sourceFileName);
				if isempty(sInfo)
					error('mex_make:make', 'Source file "%s" not found', sourceFileName);
				else
					if sInfo.datenum > bInfo.datenum
						recompile = true;
					end
					for iDep = 1:length(dependencies)
						dInfo = dir(dependencies{iDep});
						if isempty(dInfo)
							warning('mex_make:make', 'Dependency "%s" for "%s" not found', dependencies{iDep}, mexFile);
						else
							if dInfo.datenum > bInfo.datenum
								recompile = true;
							end
						end
					end                
				end            
			end

            if isfield(spec, 'forceRecompile')
                if spec.forceRecompile
                    recompile = true;
                end                    
            end
            
            if recompile
                fprintf('mex_make: (re)building %s\n', mexFile);

                scanOptions = ~isfield(spec, 'options');
                if ~scanOptions
                    options = spec.options;
                    if isempty(options)
                        options = {};
                    elseif ischar(options)
                        options = {options};
                    elseif iscell(options)
                        if any(cellfun(@(c)~ischar(c), options))
                            error('mex_make:input', 'All options must be strings');
                        end
                    else error('mex_make:input', 'Invalid format for options. Expected string or cell array of strings');
                    end
                    
                    mex(sourceFileName, options{:});
                else
                    % scan file for command line
                    fid = fopen(spec.file, 'r');
                    l = fgetl(fid);
                    cmdline = [];
                    while ischar(l)
                        cmdline = regexp(l, '(?x)//\$\s*mex\s*([^\#]*)\s*\#?.*', 'tokens');
                        if ~isempty(cmdline);
                            break; 
                        end
                        l = fgetl(fid);
                    end                    
                    fclose(fid);
                    if ~isempty(cmdline)
                        while iscell(cmdline); cmdline = cmdline{1}; end
                        eval(['mex ' cmdline]);
                    else
                        warning('mex_make:make', 'No command line found in file "%s" - compiling with defaults.', sourceFileName);
                        mex(sourceFileName);
                    end
                end    
            end
        end
    catch exeption
        cd(originalDirectory);
        rethrow(exeption);
    end
    cd(originalDirectory);
end