% This file implements all non-gui functions of the simulator framework, i.e.
% functionality shared by simulate and simulate_unattended
% An instance can be created from either an experiment specification or a
% saved experiment (for replay or further computation)
function engine = simulator_engine(param)
    saveFormatVersion = 1.0;
    
    if isempty(param)
        error('Experiment specification or path to stored experiment data required');
    end
    
    engine = struct();
    
    if ischar(param)
        % experiment given by file path. Load data structures from the
        % appropriate *.mat file
        load(param, 'version', 'experiment', 'blocks', 'logs', 'experimentFinished', 'stopBlockIndex');
        if version > saveFormatVersion
            warning('Sim:File:TooNew', 'The experiment was saved in a newer file version. This might possibly cause problems');
        elseif version < saveFormatVersion
            % If the save format ever changes in an incompatible way,
            % conversion code based on the 'version' variable can be placed
            % here.
        end        
        clear version;

    	% Restore simulation time and log positions
        t = max([0, blocks.lastTime]);
        logPositions = [logs.nUsed];
        logTCurrent = t;        
    else
        % param is expected to be the experiment specification
        experiment = param;
        
        blocks = [];
        stopBlockIndex = 0;
        % detect all blocks in the experiment specification
        fields = setdiff(fieldnames(experiment), {'name', 'path', 'depends', 'display'});
        for i = 1:numel(fields)
            [experiment.(fields{i}), blocks] = extractRuntimeBlocks(experiment.(fields{i}), blocks, fields{i});            
        end        
        
        % generate a block parameter 'ABC' from each field 'default_ABC',
        % if it does not already exist (e. g. from a group parameter)
        for i = 1:length(blocks)
            fields = fieldnames(blocks(i).spec);
            for j = 1:length(fields)
                if strncmp(fields{j}, 'default_', 8)
                    fName = fields{j}(9:end);
                    if ~isfield(blocks(i).spec, fName)
                        blocks(i).spec.(fName) = blocks(i).spec.(fields{j});
                    end
                end
            end
        end
        
        % figure out where the inputs come from, increment useCount on each
        % block providing input and/or trigger signal(s) to another block
        for i = 1:length(blocks)                        
            for j = 1:numel(blocks(i).spec.depends)
                newInputs = getBlocksFromPattern(blocks, blocks(i).name, blocks(i).spec.depends{j});                
                if isempty(newInputs); 
                    error('dependent block(s) ''%s'' not found, required by ''%s''', blocks(i).spec.depends{j}, blocks(i).name);
                end            
                blocks(i).depends = [blocks(i).depends, newInputs];                
            end
            if any(blocks(i).depends == i)
                error('Invalid dependency: block ''%s'' depends on itself!', blocks(i).name);
            end
            
            if blocks(i).spec.timing.deltaT > 0
                triggers = [];
                if ischar(blocks(i).spec.timing.triggers); blocks(i).spec.timing.triggers = {blocks(i).spec.timing.triggers}; end
                for j = 1:numel(blocks(i).spec.timing.triggers)            
                    newTriggers = getBlocksFromPattern(blocks, blocks(i).name, blocks(i).spec.timing.triggers{j});
                    if isempty(newTriggers);
                        warning('Sim:Trigger:NotFound', 'Trigger ''%s'' for block ''%s'' not found', blocks(i).spec.timing.triggers{j}, blocks(i).name);
                        continue;
                    end
                    triggers = [triggers, newTriggers];
                end
                triggers = unique(triggers);
                selfTriggers = (triggers == i);
                if any(selfTriggers)
                    warning('Sim:Trigger:Self', 'block ''%s'' triggers itself, trigger ignored', blocks(i).name);
                    triggers(selfTriggers) = [];
                end
                blocks(i).triggeredBy = triggers;

            elseif ~isempty(blocks(i).spec.timing.triggers)
                warning('Sim:Trigger:Continuous', 'Continuous blocks cannot have triggers. Ignoring trigger(s) for continuous block ''%s''.', blocks(i).name);
            end
                        
            for iUsed = normalizeEmptyArray([blocks(i).depends blocks(i).triggeredBy])
                blocks(iUsed).useCount = blocks(iUsed).useCount + 1;
            end
        end

        % increment useCount on blocks mentioned in the 'depends' field
        for i = 1:length(experiment.depends)
            depBlocks = getBlocksFromPattern(blocks, '', experiment.depends{i});
            if isempty(depBlocks)
                warning('Sim:Depends:BlocksNotFound', 'Block ''%s'' mentioned in the ''depends'' array not found', experiment.depends{i});
            else
                for iBlock = normalizeEmptyArray(depBlocks)
                    if blocks(iBlock).spec.timing.deltaT <= 0
                        error('Sim:Depends:Continuous', 'Block ''%s'' mentioned in the ''depends'' array is continuous, This is not supported.', blocks(iBlock).name);
                    end
                    blocks(iBlock).useCount = blocks(iBlock).useCount + 1;
                end
            end
        end
        
        % increment useCount on the 'stop' block, if any.
        % (It is no problem, if this block was already mentioned in 'depends',
        % we only have to make sure, that its useCount won't be zero)
        if isfield(experiment, 'stop')
            blocks(experiment.stop.index).useCount = blocks(experiment.stop.index).useCount + 1;
            stopBlockIndex = experiment.stop.index;
        end
        
        % now check for unused blocks and remove them from the array    
        for iUnused = normalizeEmptyArray(find([blocks(:).useCount] <= 0))
            blocks = markUnused(blocks, iUnused);
        end
        unusedMask = ([blocks(:).useCount] <= 0);

        % correct indices in blocks array (sinks) and original experiment
        % specification
        translateIndices = 1:length(blocks);
        for i = length(unusedMask):-1:1
            if ~unusedMask(i); continue; end
            translateIndices(i:end) = translateIndices(i:end) - 1;
        end
        translateIndices(unusedMask) = 0;
        blocks(unusedMask) = [];
        if isempty(blocks)
            error('No active blocks remain in this experiment after dependency analysis (Use ''depends'' for open loop simulations)');
        end
        for iBlock = 1:length(blocks)
            blocks(iBlock).depends = arrayfun(@(a)translateIndices(a), blocks(iBlock).depends);
            blocks(iBlock).triggeredBy = arrayfun(@(a)translateIndices(a), blocks(iBlock).triggeredBy);            
        end
        if stopBlockIndex > 0; stopBlockIndex = translateIndices(stopBlockIndex); end
                
        experiment = blockfun(@substituteBlockIndex, experiment, translateIndices);

        % (re)compile mex files used by the remaining blocks
        for iBlock = 1:length(blocks)
            mexFiles = blocks(iBlock).spec.mexFiles;
            if isempty(mexFiles); continue; end
            if ~iscell(mexFiles); mexFiles = {mexFiles}; end
            mex_make(mexFiles{:});
        end
        
        
        % complete the remaining block structures by adding the 'dependees' 
        % array and preparing the inputBuffers and the logs array        
        for iBlock = 1:length(blocks)
            for iIn = 1:length(blocks(iBlock).depends)                
                iInBlock = blocks(iBlock).depends(iIn);
                blocks(iInBlock).dependees(end + 1) = struct('block', iBlock, 'index', iIn);
            end
            for iTrig = normalizeEmptyArray(blocks(iBlock).triggeredBy)
                blocks(iTrig).triggers(end + 1) = iBlock;
            end

            resetBlock(iBlock);        
        end        
                
        % Keep log data from separated from runtime blocks.
        % This allows saving them to a different file and thus throwing them
        % away without loosing the experiment specification.
        logs = repmat(struct('nUsed', 0, 'times', [], 'allocIncrement', 0, 'out', [], 'debugOut', [], 'state', [], ...
                            'inputs', {{}}, 'cache', [], 'cacheOrder', [], 'load', [], 'unload', []), ...
                      size(blocks));

        % Format of the logs array - one struct per block
        % .nUsed - number of array elements occupied by meaningful data
        % .times - time series (linear array)
        % .allocIncrement - number of entries to allocate, whenever the arrays
        %                   must grow. This number is automatically determined
        %                   according to the expected execution rate of the
        %                   block.
        % .out, .debugOut, .state - cell or standard standard with the appropriate
        %                        data from the block. For uniform output, the
        %                        type is determined by the first block
        %                        iteration, The first dimension (if any) is
        %                        governed by the block data, the second
        %                        dimension is the iteration.
        %                        For non-uniform output, .debugOut and .state are 
        %                        allocated on the first non-empty return value, 
        %                        thus saving the overhead with empty cells (For
        %                        uniform output, this optimization is not used,
        %                        since holding a 0 x whatever array does not
        %                        occupy any memory.
        % .outSize, .debugOutSize, .stateSize - In uniform logs, each record is
        %                                    stored as a column vector (beause
        %                                    the horizontal direction is time).
        %                                    These fields are used to store the
        %                                    original data size. Data is
        %                                    automatically converted back to
        %                                    the original format when requested
        %                                    from the log, thus the internal
        %                                    storage format should be
        %                                    transparent to the user.
        % .inputs - cell array of size nInputs. Each cell stores the input 
        %           sequence for the particular input of the block as indices
        %           into the log of the providing block (thus not duplicating 
        %           the data). To yield the best memory efficiency, the
        %           framework tries to store the index data in a linear array 
        %           as long as there is only one input per iteration (the 
        %           <no inputs>-situation is coded by a zero). As soon as a log 
        %           entry with more than one data record for an input arrives, 
        %           the array beloging to this input is converted to a cell 
        %           array to support a variable number of input records per 
        %           call.
        % .cache - struct array, cache for holding full log records. This array
        %          is always allocated to its maximum size (see block's 
        %          log.maxCached entry). Each entry is a struct with fields
        %          .iteration, .out, .debugOut and .state, holding the full data
        %          An empty cell can be identified by .iteration == 0
        % .cacheOrder - linear array of size(full) describing which entry of
        %               full is evicted next.
        % .load/.unload - copy of the function handles for loading/unloading
        %                 from the block specification

        % logPositions are used in conjunction with setLogPos and inc/decLogPos
        % to keep track of which record to return from getLogRecord
        % (They are separated from the log, to allow modifying the log access
        % policy without changing the logging code, if necessary)
        logPositions = zeros(size(logs));
        logTCurrent = 0;
            
        % Prepare the logs (cannot be merged with the previous loop over
        % all blocks, since we are using the 'dependees' arrays, which have
        % to be initialized first
        for iBlock = 1:length(blocks)
            logs(iBlock).enabled = ~blocks(iBlock).spec.log.disabled; % TODO: check for global log deactivation
            logs(iBlock).nUsed = 0;
            logs(iBlock).inputs = cell(length(blocks(iBlock).depends), 1); % dimension of input arrays associated on first log entry

            if logs(iBlock).enabled
                logs(iBlock).uniform = blocks(iBlock).spec.log.uniform;

                if ~isempty(blocks(iBlock).spec.log.load) || ~isempty(blocks(iBlock).spec.log.unload)
                    if isa(blocks(iBlock).spec.log.load, 'function_handle') && isa(blocks(iBlock).spec.log.unload, 'function_handle')
                        logs(iBlock).load = blocks(iBlock).spec.log.load;
                        logs(iBlock).unload = blocks(iBlock).spec.log.unload;
                    else
                        warning('Sim:Core:LogNoHandles', 'Missing/invalid load/unload function handle(s) log records of block ''%s''', blocks(iBlock).name);
                        % if someone uses unified logs and load/unload handles,
                        % it is very certain, that the full data will not have
                        % unified format (or at least the overhead for
                        % non-unified storage will be negligable)
                        logs(iBlock).unified = false;
                    end
                end

                logs(iBlock).allocIncrement = calcAllocIncrement(blocks, iBlock);
                if logs(iBlock).uniform
                    logs(iBlock).out = [];   % dimension associated on first log entry
                    logs(iBlock).debugOut = []; % dimension associated on first log entry
                    logs(iBlock).state = []; % dimension associated on first log entry
                else
                    logs(iBlock).out = cell(1, logs(iBlock).allocIncrement);
                    logs(iBlock).debugOut = cell(1, logs(iBlock).allocIncrement);
                    logs(iBlock).state = cell(1, logs(iBlock).allocIncrement);
                    logs(iBlock).cache = repmat(struct('iteration', 0, 'out', [], 'debugOut', [], 'state', []), max(1, blocks(iBlock).spec.log.maxCached), 1);
                    logs(iBlock).cacheOrder = 1:length(logs(iBlock).cache);                                
                end
            end
        end

        % === Now the initial data structures have been prepared ==============                        
        fprintf('Initialization complete. Simulating blocks\n');
        for iBlock = 1:length(blocks)
            if isempty(blocks(iBlock).name); continue; end
            fprintf('%3d: %s(', iBlock, blocks(iBlock).name);
            comma = '';
            for iIn = normalizeEmptyArray(blocks(iBlock).depends)
                fprintf([comma '%s'], blocks(iIn).name);
                comma = ', ';
            end
            fprintf(')\n');
        end    

    	% calculate the initial timesteps
        experimentFinished = false;
        t = 0;     
    end
        
    % initialized variables for doStep
    [tNext, nextBlock] = min([blocks(:).nextTime]);
        
    engine.getExperimentSpecification = @getExperimentSpecification;
    engine.getBlocks = @getBlocks;
    engine.getLogs = @getLogs;
    engine.doStep = @doStep;
    engine.setLogPosition = @setLogPosition;
    engine.incLogPosition = @incLogPosition;
    engine.decLogPosition = @decLogPosition;
    engine.getLogRecords = @getLogRecords;
    engine.recomputeFromHere = @recomputeFromHere;
    engine.getExperimentState = @getExperimentState;
    engine.saveExperiment = @saveExperiment;
    
    % some getters
    function ret = getBlocks()
        ret = blocks;
    end
    function ret = getExperimentSpecification()
        ret = experiment;
    end
    function [retLogs, retLogPositions] = getLogs()
        retLogs = logs;
        retLogPositions = logPositions;
    end    
    function [tSim, finished] = getExperimentState()
        tSim = t;
        finished = experimentFinished;
    end        
    
    % Propagate simulation to a tNew > t
    function [tNew, changed] = doStep()        
        changed = [];
        if experimentFinished
            tNew = t;
            return;
        end
        
        % propagate simulation until t has incremented at least a bit
        while(true)
            if isinf(tNext)
                error('Cannot determine next block due to an unsupported combination of block timings.');
            end
            [blocks, logs, newChanged] = processBlock(blocks, logs, nextBlock, tNext);
            changed = [changed newChanged];
            t = tNext;
            [tNext, nextBlock] = min([blocks(:).nextTime]);
            if tNext > t; break; end
        end
        tNew = t;
        
        % check if experiment finished
        if stopBlockIndex > 0 && ismember(stopBlockIndex, changed)
            if islogical(blocks(stopBlockIndex).out)
                if blocks(stopBlockIndex).out; experimentFinished = true; end
            else warning('Sim:Stop:InvalidBlockOutput', '''stop'' block produced invalid output. Boolean value expected');                
            end
        end
        if ~experimentFinished
            for iBlock = normalizeEmptyArray(changed)
                if blocks(iBlock).lastTime >= blocks(iBlock).spec.timing.maxT || ...
                   blocks(iBlock).iteration >= blocks(iBlock).spec.timing.maxIterations
                    experimentFinished = true;
                    break;
                end
            end
        end
    end

    % init / move all log pointers to the most recent record, whose time is
    % smaller than or equal to t
    function [tNew, changed] = setLogPosition(t)
		fprintf('setLogPosition(%f)\n', t);
		oldLogPositions = logPositions;
        tNew = 0;
        for iBlock = 1:length(logs)
            pos = find(logs(iBlock).times(1:(logs(iBlock).nUsed)) <= t, 1, 'last');
            if isempty(pos) || pos > logs(iBlock).nUsed
                logPositions(iBlock) = 0;
            else
                logPositions(iBlock) = pos;
                if logs(iBlock).times(pos) > tNew; tNew = logs(iBlock).times(pos); end
            end
        end
        logTCurrent = tNew;
		changed = find(logPositions ~= oldLogPositions);
    end
    % increment log pointers to the next time step (this will change at
    % least one element in logPositions as long as the log's end is not
    % reached
    function [tNew, changed] = incLogPosition()        
        minTime = logTCurrent + 1e-7; % add some minimum increment to accomodate rounding errors
        tNew = inf;
        % first determine the smallest time larger than the new logPosition
        for iBlock = 1:length(logs)
            iFirst = max(1, logPositions(iBlock));
			iRec = find(logs(iBlock).times(iFirst:logs(iBlock).nUsed) >= minTime, 1);
            if isempty(iRec); continue; end
            iRec = iRec + iFirst - 1;
			if logs(iBlock).times(iRec) < tNew; tNew = logs(iBlock).times(iRec); end
		end		
        if ~isinf(tNew)            
            logTCurrent = tNew;
            % now advance logPositions as far as neccessary to fulfil the
            % condition that all log timestampts are nearest but not above
            % logTCurrent
            oldLogPositions = logPositions;
            for iBlock = 1:length(logs)
                iFirst = max(1, logPositions(iBlock));
				iRec = find(logs(iBlock).times(iFirst:logs(iBlock).nUsed) > tNew, 1);
				if isempty(iRec); logPositions(iBlock) = logs(iBlock).nUsed;
				else logPositions(iBlock) = iRec + iFirst - 2; 
				end
            end
            changed = find(logPositions ~= oldLogPositions);
        else
            % at end of log
            tNew = logTCurrent;
            changed = [];
        end
	end

    % similar to incLogPos: will move all logPointers so that at least one
    % time
    function [tNew, changed] = decLogPosition()
        maxTime = logTCurrent - 1e-7;
        tNew = 0;
        for iBlock = 1:length(logs)
			iRec = find(logs(iBlock).times(1:logPositions(iBlock)) <= maxTime, 1, 'last');
            if isempty(iRec); continue; end
            if logs(iBlock).times(iRec) > tNew; tNew = logs(iBlock).times(iRec); end
        end
        logTCurrent = tNew;
		
        oldLogPositions = logPositions;
        for iBlock = 1:length(blocks)
            iRec = find(logs(iBlock).times(1:logPositions(iBlock)) <= tNew, 1, 'last');
            if ~isempty(iRec); logPositions(iBlock) = iRec; end
		end
        changed = find(logPositions ~= oldLogPositions);
    end
    
    % return a structure of records, each element corresponds to one
    % element in indices. The structure has the following fields:
    % .t - timestamp
    % .iteration - cycle number for the block
    % .out, .debugOut, .state - the blocks record data
    % .inputs - cell array with struct arrays with fields .t and .data
    %           (same format as required by all the block callbacks)
    function records = getLogRecords(indices)
        records = repmat(struct('iteration', [], 't', [], 'out', [], 'debugOut', [], 'state', [], 'inputs', []), size(indices));
        for i = 1:numel(indices)
            iBlock = indices(i);
			[logs, records(i)] = loadLogRecord(blocks, logs, iBlock, logPositions(iBlock));
			% convert from inputIndices in .inputs to the full input data
            records(i).inputs = expandInputs(iBlock, records(i).inputs);            
        end
    end

    % Reset simulator position to current log position and throw away all
    % data after that
    function recomputeFromHere()
        for iBlock = 1:length(blocks)
            logPos = logPositions(iBlock);
            if logPos > 0 && logPos <= logs(iBlock).nUsed
                record = getLogRecords(iBlock);
                blocks(iBlock).iteration = record.iteration;
                blocks(iBlock).lastTime = record.t;
                blocks(iBlock).out = record.out;
                blocks(iBlock).debugOut = record.debugOut;
                blocks(iBlock).state = record.state;
                blocks(iBlock).lastInputs = record.inputs;
                % prepare .inputBuffers, .inputIndicesBuffers and .nextTime
                if logPos < logs(iBlock).nUsed
                    blocks(iBlock) = determineNextBlockTimeStep(blocks(iBlock), blocks(iBlock).lastTime);
                    for iIn = 1:numel(blocks(iBlock).depends)
                        if ~iscell(logs(iBlock).inputs{iIn})
                            inIdx = logs(iBlock).inputs{iIn}(logPos + 1);
                            if inIdx == 0; blocks(iBlock).inputIndicesBuffers{iIn} = [];
                            else blocks(iBlock).inputIndicesBuffers{iIn} = inIdx;
                            end                            
                        else blocks(iBlock).inputIndicesBuffers{iIn} = logs(iBlock).inputs{iIn}{logPos + 1};
                        end
                    end
                % else: data is already valid
                end
                
                % remove data from inputBuffers, that has not yet been
                % computed
                for iIn = 1:numel(blocks(iBlock).depends)
                    firstInvalid = find(logs(blocks(iBlock).depends(iIn)).times(blocks(iBlock).inputIndicesBuffers{iIn}) > logTCurrent, 1);
                    if ~isempty(firstInvalid); blocks(iBlock).inputIndicesBuffers{iIn}(firstInvalid:end) = []; end
                end
                blocks(iBlock).inputBuffers = expandInputs(iBlock, blocks(iBlock).inputIndicesBuffers);
            else resetBlock(iBlock); % usually logPos == 0 -> perform complete reinitialization of block                
            end
        end
        % Clear data from end of log (do not clear it in the above loop, as
        % restoring the inputBuffers array accesses logs.times beyond the
        % current log position, to determine, which inputs are already
        % available at logTCurrent.
        for iBlock = 1:length(blocks)            
            logPos = logPositions(iBlock);
            logs(iBlock).nUsed = logPos;
            logs(iBlock).times((logPos + 1):end) = [];
            logs(iBlock).out(:, (logPos + 1):end) = [];
            logs(iBlock).debugOut(:, (logPos + 1):end) = [];
            logs(iBlock).state(:, (logPos + 1):end) = [];
            for iIn = 1:length(logs(iBlock).inputs)
                logs(iBlock).inputs{iIn}((logPos + 1):end) = []; % works for uniform arrays and cell arrays
            end                
        end
        
        % finally restore the simulation time
        experimentFinished = false;
        t = logTCurrent;
        [tNext, nextBlock] = min([blocks(:).nextTime]);        
    end    
    
    % Prepare a block for simulation (used during initialization and from
    % recomputeFromHere() )
    function resetBlock(iBlock)
        blocks(iBlock).lastTime = -inf;
        if blocks(iBlock).spec.timing.deltaT > 0
            if ~isempty(blocks(iBlock).spec.timing.getNextT)
                blocks(iBlock).nextTime = blocks(iBlock).spec.timing.getNextT(blocks(iBlock).spec, 0, 1); % for time 0, iteration #1
                if isscalar(blocks(iBlock).nextTime) && blocks(iBlock).nextTime >= 0
                    % updating the offset is not really required, but on
                    % the other hand it does not harm to keep everything up
                    % to date...                    
                    blocks(iBlock).spec.timing.offset = blocks(iBlock).nextTime;
                else
                    error('Sim:Core:InvalidTiming', 'Could not determine initial time step for block ''%s''. The user callback returned an invalid value', blocks(iBlock).name);
                end
            else blocks(iBlock).nextTime = blocks(iBlock).spec.timing.offset;
            end
        else blocks(iBlock).nextTime = inf;
        end
        blocks(iBlock).iteration = 0;
        blocks(iBlock).out = [];
        blocks(iBlock).debugOut = [];
        blocks(iBlock).state = [];    
        blocks(iBlock).lastInputs = repmat({repmat(struct('t', [], 'data', []), 0)}, size(blocks(iBlock).depends));
        blocks(iBlock).inputBuffers = repmat({repmat(struct('t', [], 'data', []), 0)}, size(blocks(iBlock).depends));        
        blocks(iBlock).inputIndicesBuffers = repmat({[]}, size(blocks(iBlock).depends));
    end

    % Expand input data stored as indices inputIndices to its full
    % representation as an array of structs with .t and .data.
    % Both inputIndices and expanded are cell arrays with the number (and
    % order) of cells equal to the iBlock's depends array.
    function expanded = expandInputs(iBlock, inputIndices)
        expanded = cell(size(inputIndices));
        for iIn = 1:length(inputIndices)
            inExpanded = repmat(struct('t', [], 'data', []), size(inputIndices{iIn}));
            for iInEntry = 1:length(inputIndices{iIn})
                [logs, tempRec] = loadLogRecord(blocks, logs, blocks(iBlock).depends(iIn), inputIndices{iIn}(iInEntry));
                inExpanded(iInEntry).t = tempRec.t;
                inExpanded(iInEntry).data = tempRec.out;
            end
            expanded{iIn} = inExpanded;
        end
    end

    function success = saveExperiment(path)
        success = true;
        version = saveFormatVersion;
        try
            save(path, 'version', 'experiment', 'blocks', 'logs', 'experimentFinished', 'stopBlockIndex');
        catch ME
            success = false;
            warning('Sim:Save:Failed', 'Could not save experiment to ''%s'': %s', path, ME.message);
        end
    end
end


% generate an allocation increment based on the expected frequency of 
% computations for a single block. This routine merges the block's own
% interval time (if not continuous) as well as triggers and requests
% generated from depending blocks.
function incr = calcAllocIncrement(blocks, iBlock)
    deltaT = getShortestInterval(blocks, iBlock, false(size(blocks)));
    
    if deltaT > 0
        incr = 1 / deltaT; % should be sufficient for one second (replace '1' with the number of seconds desired until reallocation)
    else incr = 10; % default value
    end
    incr = round(incr);
    
    if incr < 1; incr = 1;
    elseif incr > 100; incr = 100;
    end    
end
function [deltaT, ignore] = getShortestInterval(blocks, iBlock, ignore)
    deltaT = blocks(iBlock).spec.timing.deltaT;
    if deltaT <= 0; deltaT = inf; end
    ignore(iBlock) = true;
    if blocks(iBlock).spec.timing.deltaT > 0
        peers = blocks(iBlock).triggeredBy;
    else peers = unique([blocks(iBlock).dependees.block]);
    end
    
    for iPeer = normalizeEmptyArray(peers)
        if ~ignore(iPeer)
            [deltaTPeer, ignore] = getShortestInterval(blocks, iPeer, ignore);
            if deltaTPeer < deltaT; deltaT = deltaTPeer; end
        end
    end    
end

function [block] = determineNextBlockTimeStep(block, t)
    if block.spec.timing.deltaT > 0
        if ~isempty(block.spec.timing.getNextT)
            block.nextTime = block.spec.timing.getNextT(block.spec, t, block.iteration + 1);
            if block.nextTime > t
                % update deltaT from user function. The function may return
                % inf to indicate that the block should not be called
                % anymore (e. g. internal data sequence exhausted).
                block.spec.timing.deltaT = block.nextTime - t;
            else
                error('Sim:Core:InvalidTiming', 'Could not determine next time step for block ''%s''. The user callback returned an invalid value', block.name);
            end
        else block.nextTime = t + block.spec.timing.deltaT;
        end
    else block.nextTime = inf;
    end
end

function [blocks, logs, changed] = processBlock(blocks, logs, iBlock, t)
    changed = [];    
    % prevent endless loops (should not happen, just to be sure)
    if blocks(iBlock).locked; 
        %fprintf('block %s is locked\n', blocks(iBlock).name);
        return; 
    end
    if blocks(iBlock).lastTime >= t; 
        %fprintf('block %s has already been computed\n', blocks(iBlock).name);
        return; 
    end

    blocks(iBlock).locked = true;
    %fprintf('locking %s\n', blocks(iBlock).name);
    % prepare inputs (calculate all blocks we depend on)
    for i = blocks(iBlock).depends        
        if (blocks(i).spec.timing.deltaT > 0 && blocks(i).nextTime <= t) || ...
           (blocks(i).spec.timing.deltaT == 0 && blocks(i).lastTime < t)
            %fprintf('need to compute block %s before\n', blocks(i).name);
            [blocks, logs, newChanged] = processBlock(blocks, logs, i, t);
            changed = [changed, newChanged];
        end        
    end
    
    % process block
    fprintf('[%10.5f] processing ''%s''\n', t, blocks(iBlock).name);    
    iteration = blocks(iBlock).iteration + 1;
    [newState, out, debugOut] = blocks(iBlock).spec.process(blocks(iBlock).spec, t, blocks(iBlock).state, blocks(iBlock).inputBuffers{:});
    
    blocks(iBlock).locked = false;
        
    % remove processed data from our own input buffers
    lastInputs = blocks(iBlock).inputBuffers; % ...but save them for log
    lastInputIndices = blocks(iBlock).inputIndicesBuffers;
    
    discrete = (blocks(iBlock).spec.timing.deltaT > 0);
    for iIn = 1:length(blocks(iBlock).depends)
        iInBlock = blocks(iBlock).depends(iIn);
        if blocks(iInBlock).spec.timing.deltaT > 0 && ...
           (~discrete || isinf(blocks(iInBlock).spec.timing.deltaT))
            if ~isempty(blocks(iBlock).inputBuffers{iIn})
                blocks(iBlock).inputBuffers{iIn} = blocks(iBlock).inputBuffers{iIn}(end);
                blocks(iBlock).inputIndicesBuffers{iIn} = blocks(iBlock).inputIndicesBuffers{iIn}(end);
            end
        else
            blocks(iBlock).inputBuffers{iIn} = repmat(struct('t', [], 'data', []), 0); % input is continuous, will be computed automatically before next iteration
            blocks(iBlock).inputIndicesBuffers{iIn} = [];
        end
    end

    % Store the next iteration time    
    blocks(iBlock) = determineNextBlockTimeStep(blocks(iBlock), t);    

    % leave here, if the module did not create any output
    % Note: An empty output is allowed if a size is specified, i. e.
    % zeros(0, 2). This might be useful for blocks that create matrices
    % (sensors, path planners), where an empty matrix is valid.
    if all(size(out) == 0); return; end

    blocks(iBlock).iteration = iteration;
    blocks(iBlock).lastTime = t;
    blocks(iBlock).out = out;
    blocks(iBlock).debugOut = debugOut;
    blocks(iBlock).state = newState;
    % We store the full data here, although it would be more efficient to
    % just use indices into the log. This will allow full visualization
    % even with logging (partially) disabled
    blocks(iBlock).lastInputs = lastInputs; 

    changed = [changed, iBlock];    
    
    % add generated output to inputBuffers of connected blocks
    for iOut = 1:length(blocks(iBlock).dependees)
        in = blocks(iBlock).dependees(iOut);
        %fprintf('adding output to ''%s''\n', blocks(in.block).name);
        
        if discrete
            % we are a discrete block - add most recent output

            % if the connected block is continuous and our newly calculated
            % output's timestamp is exactly the same as the last processing
            % timestamp of that block, we have to remove the old entry from
            % the inputBuffer (if any)
            if blocks(in.block).spec.timing.deltaT <= 0 && ...
               t <= blocks(in.block).lastTime % should always be equal
                blocks(in.block).inputBuffers{in.index}(:) = [];
                blocks(in.block).inputIndicesBuffers{in.index} = [];
            end
            % Now add this record to input buffer
            blocks(in.block).inputBuffers{in.index}(end + 1) = struct('t', t, 'data', out);
            blocks(in.block).inputIndicesBuffers{in.index}(end + 1) = blocks(iBlock).iteration;
        else
            % We are a continuous block - always set connected inputs to 
            % the most recent output
            blocks(in.block).inputBuffers{in.index} = struct('t', t, 'data', out);
            blocks(in.block).inputIndicesBuffers{in.index} = iteration;
        end
    end  

    % fire triggers
    for trigger = normalizeEmptyArray(blocks(iBlock).triggers)
        if blocks(trigger).spec.timing.deltaT > 0 && blocks(trigger).lastTime < t
            blocks(trigger).nextTime = t;
        end
    end

    % save out into log and inputBuffers of depending blocks    
    if logs(iBlock).enabled
        
        % if available, use unload to reduce log data size
        if ~isempty(logs(iBlock).unload)
            [outRecord, debugOutRecord, stateRecord] = ...
                logs(iBlock).unload(blocks(iBlock).spec, iteration, origOut, blocks(iBlock).debugOut, blocks(iBlock).state);
        else [outRecord, debugOutRecord, stateRecord] = deal(blocks(iBlock).out, blocks(iBlock).debugOut, blocks(iBlock).state);            
        end
        
        % store the current record
        if logs(iBlock).uniform
            % in a uniform log...
            if logs(iBlock).nUsed > 0
                if length(logs(iBlock).times) < iteration
                    % resize
                    logs(iBlock).times(end + logs(iBlock).allocIncrement) = 0;
                    logs(iBlock).out(:, end + logs(iBlock).allocIncrement) = logs(iBlock).out(:, 1);
                    logs(iBlock).debugOut(:, end + logs(iBlock).allocIncrement) = logs(iBlock).debugOut(:, 1);
                    logs(iBlock).state(:, end + logs(iBlock).allocIncrement) = logs(iBlock).state(:, 1);
                end
                
                try
                    % store
                    logs(iBlock).out(:, iteration) = outRecord(:);
                    logs(iBlock).debugOut(:, iteration) = debugOutRecord(:);
                    logs(iBlock).state(:, iteration) = stateRecord(:);
                catch ME
                    warning('Sim:Core:LogConcatFailure', 'Could not append record to uniform log of block ''%s''. Either use ''normal'' logging or return consistent data', blocks(iBlock).name);
                    rethrow(ME);
                end                
            else
                % store original data size
                % (e.g. original data might be a MxN matrix -> xxxSize = [M, N],
                % However, it is stored as an M*N x 1 column in the uniform
                % log array.)
                logs(iBlock).outSize = size(outRecord);
                logs(iBlock).debugOutSize = size(debugOutRecord);
                logs(iBlock).stateSize = size(stateRecord);
                logs(iBlock).out = outRecord(:);
                logs(iBlock).debugOut = debugOutRecord(:);
                logs(iBlock).state = stateRecord(:);
            end
        else
            % non-uniform log
            if length(logs(iBlock).times) < iteration
                logs(iBlock).times(end + logs(iBlock).allocIncrement) = 0;
                logs(iBlock).out{end + logs(iBlock).allocIncrement} = [];
                logs(iBlock).debugOut{end + logs(iBlock).allocIncrement} = [];
                logs(iBlock).state{end + logs(iBlock).allocIncrement} = [];
            end
            % no load/unload functions - store in full format
            logs(iBlock).out{iteration} = outRecord;
            logs(iBlock).debugOut{iteration} = debugOutRecord;
            logs(iBlock).state{iteration} = stateRecord;
        end
        
        logs(iBlock).times(iteration) = t;
        
        % add input indices to log record
        for iIn = 1:length(blocks(iBlock).depends)
            if ~iscell(logs(iBlock).inputs{iIn})
                % try to be memory efficient and avoid cell arrays, if
                % possible
                if length(lastInputIndices{iIn}) <= 1
                    inIdx = lastInputIndices{iIn};
                    if isempty(inIdx); inIdx = 0; end;
                    if length(logs(iBlock).inputs{iIn}) < iteration; 
                        logs(iBlock).inputs{iIn}(end + logs(iBlock).allocIncrement) = 0; 
                    end
                    logs(iBlock).inputs{iIn}(iteration) = inIdx;
                    continue;
                else
                    % convert log to cell array
                    logs(iBlock).inputs{iIn} = num2cell(logs(iBlock).inputs{iIn});
                end
            end
            
            % linear array not possible, use cell array instead
            if length(logs(iBlock).inputs{iIn}) < iteration; 
                logs(iBlock).inputs{iIn}{end + logs(iBlock).allocIncrement} = []; 
            end
            logs(iBlock).inputs{iIn}{iteration} = lastInputIndices{iIn};
        end
        
        logs(iBlock).nUsed = logs(iBlock).nUsed + 1; % == iteration
    end    
end

% restore a single log record
% record is a struct with fields
% .iteration, .t, .out, .debugOut, .state - nothing special
% .inputs - cell array with indices into the logs of input blocks
function [logs, record] = loadLogRecord(blocks, logs, iBlock, iteration)
    record = struct();
    record.iteration = iteration;
    if logs(iBlock).enabled && iteration > 0 && iteration <= logs(iBlock).nUsed
        record.t = logs(iBlock).times(iteration);
        		
		if logs(iBlock).uniform
			record.out = reshape(logs(iBlock).out(:, iteration), logs(iBlock).outSize);
			record.debugOut = reshape(logs(iBlock).debugOut(:, iteration), logs(iBlock).debugOutSize);
			record.state = reshape(logs(iBlock).state(:, iteration), logs(iBlock).stateSize);          
		else
			record.out = logs(iBlock).out{iteration};
			record.debugOut = logs(iBlock).debugOut{iteration};
			record.state = logs(iBlock).state{iteration};
		end
		
        nInputs = length(logs(iBlock).inputs);
        record.inputs = cell(nInputs, 1);
		for iIn = 1:nInputs
			if ~iscell(logs(iBlock).inputs{iIn})
                inIdx = logs(iBlock).inputs{iIn}(iteration);
                if inIdx == 0; record.inputs{iIn} = [];
                else record.inputs{iIn} = inIdx;
                end                
            else record.inputs{iIn} = logs(iBlock).inputs{iIn}{iteration};
			end
		end
		
        if ~isempty(logs(iBlock).load)
            % this block uses the load/unload mechanism
            % search cache for the requested record
            cacheIdx = find([logs(iBlock).cache.iteration] == iteration, 1);
            if isempty(cacheIdx)
                % record not in cache, reload it (this evicts the oldest
                % cache entry)
                cacheIdx = logs(iBlock).cacheOrder(1);
                logs(iBlock).cacheOrder = [logs(iBlock).cacheOrder(2:end), cacheIdx];
                
                logs(iBlock).cache(cacheIdx).iteration = iteration;                
                [logs(iBlock).cache(cacheIdx).out, logs(iBlock).cache(cacheIdx).debugOut, logs(iBlock).cache(cacheIdx).state] = ...
                    logs(iBlock).load(blocks(iBlock).spec, iteration, record.out, record.debugOut, record.state);
            else
                % record is in cache, load it from there and reorder cache
                order = logs(iBlock).cacheOrder;
                logs(iBlock).cacheOrder = [order(1:(cacheIdx - 1)), order((cacheIdx + 1):end), cacheIdx];
            end

            record.out = logs(iBlock).cache(cacheIdx).out;
            record.debugOut = logs(iBlock).cache(cacheIdx).debugOut;
            record.state = logs(iBlock).cache(cacheIdx).state;
        end
        
    else
        if iteration > logs(iBlock).nUsed
            warning('Sim:Log:IndexOutOfRange', 'Accessing a non-existing log entry. This is an internal BUG!');
        end
        % log disabled or invalid index, create dummy record
        record.t = 0;
        record.out = []; record.debugOut = []; record.state = [];
        record.inputs = cell(length(blocks(iBlock).depends), 1);
    end
end

function s = blockfun(handle, s, varargin)
    if iscell(s)
        for i = 1:numel(s); s{i} = blockfun(handle, s{i}, varargin{:}); end
    elseif isstruct(s)
        numEntries = numel(s);        
        if numEntries > 1;
            for i = 1:numel(s); s(i) = blockfun(handle, s(i), varargin{:}); end
        elseif isBlock(s)
            s = handle(s, varargin{:});
        else
            fields = fieldnames(s);
            for i = 1:length(fields); s.(fields{i}) = blockfun(handle, s.(fields{i}), varargin{:}); end
        end
    end
    
end
function s = substituteBlockIndex(s, substitutionTable)
    s.index = substitutionTable(s.index);
end

function [blocks] = markUnused(blocks, iBlock)
    for i = normalizeEmptyArray([blocks(iBlock).depends blocks(iBlock).triggeredBy])
        blocks(i).useCount = blocks(i).useCount - 1;
        if blocks(i).useCount == 0; 
            blocks = markUnused(blocks, i); 
        end
    end
end

function [indices] = getBlocksFromPattern(blocks, basePath, path)
    indices = [];    
    basePaths = regexp(basePath, '/', 'split');
    pathPattern = regexptranslate('wildcard', path);
    for basePathComponents = (length(basePaths)-1):-1:0
        currentBasePath = '';
        if basePathComponents > 0; currentBasePath = regexprep(sprintf('%s/', basePaths{1:basePathComponents}), '([\(\)\{\}\[\]])', '\\$1'); end
        for iBlock = 1:length(blocks)
            if isempty(blocks(iBlock).name); continue; end
            match = regexp(blocks(iBlock).name, [currentBasePath, pathPattern], 'match', 'once');            
            if ~strcmp(match, blocks(iBlock).name); continue; end
            indices(end + 1) = iBlock;
        end
        if ~isempty(indices); break; end        
    end
end


function res = isBlock(block)
    res = numel(block) == 1 && isstruct(block) ...
          && all(isfield(block, {'isBlock', 'timing', 'process', 'graphicElements', 'figures', 'log', 'mexFiles'})) ...
          && block.isBlock;
end

function block = createRuntimeBlock(s, name)
    block.spec = s;
    block.lastTime = -inf;
    block.nextTime = [];
    block.depends = [];
    block.dependees = repmat(struct('block', [], 'index', []), 0);
    block.useCount = 0;
    block.iteration = 0;
    block.locked = false;
    block.name = name;
    block.inputBuffers = {}; % cell array with one cell per input channel
                             % each cell contains a struct [array] with
                             % members .t and .data, i.e. the same format
                             % as expected by the 'process' function.
    block.inputIndicesBuffers = {}; % This field complements inputBuffers 
                                    % by storing the indices from the log,
                                    % where the inputs were taken from.
                                    % (Actually this is required to create
                                    % the logs :-)
                                    % Each cell contains a linear array of
                                    % indices. The number of cells is equal
                                    % to the number of inputs
    block.triggeredBy = [];
    block.triggers = [];
    block.out = [];
    block.debugOut = [];
    block.state = [];    
    block.lastInputs = {};    
end

function [s, runtimeBlocks] = extractRuntimeBlocks(s, runtimeBlocks, name)
    if isempty(s); return; end
    if iscell(s)
        numCells = numel(s);
        for i = 1:numCells
            [s{i}, runtimeBlocks] = extractRuntimeBlocks(s{i}, runtimeBlocks, [name, sprintf('{%d}', i)]);
        end
    elseif isstruct(s)
        numEntries = numel(s);
        if numEntries > 1
            for i = 1:numEntries
                [s(i), runtimeBlocks] = extractRuntimeBlocks(s(i), runtimeBlocks, [name, sprintf('(%d)', i)]);
            end
        elseif isBlock(s) 
            % a 'leaf' in the hierarchy tree: we found a block
            newBlock = createRuntimeBlock(s, name);
            if isempty(runtimeBlocks); runtimeBlocks = newBlock; else runtimeBlocks(end + 1) = newBlock; end
            s.index = length(runtimeBlocks);
        else
            % this is a structure, probably containing one or more blocks
            % and maybe other parameters, too           
            firstBlock = length(runtimeBlocks) + 1;
            groupParams = struct();
            fields = fieldnames(s);
            for i = 1:length(fields)
                blockCountBefore = length(runtimeBlocks);
                [s.(fields{i}), runtimeBlocks] = extractRuntimeBlocks(s.(fields{i}), runtimeBlocks, [name, '/', fields{i}]);
                if length(runtimeBlocks) == blockCountBefore
                    groupParams.(fields{i}) = s.(fields{i});
                end
            end
            groupParamNames = fieldnames(groupParams);
            for i = 1:length(groupParamNames)
                for j = firstBlock:length(runtimeBlocks)
                    if strncmp(groupParamNames{i}, 'override_', 9)
                        % case 1: if a group parameter is 'override_ABC',
                        % override a possibly existing block parameter
                        % 'ABC'
                        runtimeBlocks(j).spec.(groupParamNames{i}(10:end)) = groupParams.(groupParamNames{i});
                    else
                        % case 2: add the group parameter if does not
                        % already exist in the block definition
                        if ~isfield(runtimeBlocks(j).spec, groupParamNames{i})
                            runtimeBlocks(j).spec.(groupParamNames{i}) = groupParams.(groupParamNames{i});

                        end
                    end
                end
            end
        end
    end
end

function o = normalizeEmptyArray(i)
    if isempty(i); o = [];
    else o = i;
    end
end
