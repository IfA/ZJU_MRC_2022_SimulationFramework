% This function creates the base "class" for all blocks
%
% A block is a MATLAB structure with the following fields:
% - [state, out, debugData] = process(block, t, state[, in1[, in2[, ...]]]):
%       This is a function handle that is called whenever the block is 
%       executed by the simulation framework. The number of inputs is
%       automatically determined according to the number of blocks this
%       block depends on (after expanding the 'depends' array). As multiple
%       records may be passed in each input and block execution is
%       basically asynchronous, each input is formatted as an array of
%       structs with members 
%       .t - timestamp when the data has been generated and
%       .data - the data as returned (as output) by the generating block
% - timing: 
%       A structure defining the blocks timing requirements. It has the
%       following subfields:
%       .deltaT: interval for discrete blocks. A value of 0 indicates a
%                continuous block that is calculated "on demand", i.e. when 
%                a dependent block request an updated value. A value of
%                'inf' on the other hand is intended for a constant block, 
%                that is calculated just once (e.g. the environment.)
%       .offset: This is the time, the block is run the first time 
%                (zero by default)
%       .triggers: names of other blocks (see 'depends'), that trigger
%                  recalculation of this block
%       .getNextT: If not empty, a function handle of the block that is
%                  called to query the next sample time with the current
%                  simulation time given as argument
% - depends:
%       Cell array of strings naming other blocks this block depend on. The
%       framework ensures that outputs of dependent blocks are calculated 
%       before running this block. The most recent outputs are passed as
%       inputs to the 'process' function.
% - graphicElements:
%       array of structures. Each element represents a single graphic
%       object or a group of related objects and has the following fields:
%       - name: name of this object/group. An empty name indicates an
%               'always-on' group, i.e. that cannot be disabled by the user
%       - hideByDefault: bool, show or hide this object/group by
%                        default
%       - [handles] = draw(block, ax, handles, out, debugOut, state, inputs):
%               Function handle that draws/updates this object/group. The
%               'handles' parameter may be an array or a (possibly nested)
%               structure with Matlab graphic object handles. The function
%               is expected to always first check the existence of a
%               certain handle, because the framework might delete handles
%               on the user's request (show/hide graphics).
%       - useLogs: if true, this element may visualize not the
%                  instantaneous state of the block, but its trajectory,
%                  gathered from the log data. The signature of the draw
%                  function changes to
%                  [handles] = draw(block, ax, handles, iteration, times, outs, debugOuts, states)
%                  The last four parameters are taken directly from the log,
%                  i.e. they may (and usually will) have more entries than
%                  the function should display. The current index (and 
%                  therefore most recent index to display) is passed in
%                  'iteration'. Keep also in mind, that if the log is 
%                  stored in unified format, each column of 'out' and the 
%                  further correspond to one record and therefore
%                  might not match the format returned by your block. In
%                  addition, if the block uses the load/unload mechanism,
%                  the passed log is residues only. No expansion takes
%                  place before invoking the draw handler.
%
% - figures:
%       array of additional debug ouput figure specifications. Each figure
%       is represented by a struct with the following fields:
%       - name: descriptive text to show to the user.
%       - icon: optional, for use in toolbars/menus to show/hide this
%               figure
%       - [fh, userData] = init(block): 
%               create and return figure. Note that this
%               function is not intended to draw anything
%               (see 'draw' member for this), but only to
%               create the figure and its axe(s).
%       - [userData] = draw(block, fh, userData, out, debugData, state, in{:}):
%               Do the actual drawing. The use is similar to the 'draw'
%               member of graphicElements, except that the block is
%               completely responsible for the management of handles (i.e.
%               has to keep track of them in an internal data structure,
%               possibly in the private workspace attached to the function
%               handle). The framework may delete the figure on user
%               request, therefore the 'init' member should reset all
%               internal data structures used by 'draw'.
%       - [userData] = drawLog(block, fh, userData, iteration, times, out, debugData, states)
%               Draw something that needs access to the log records and not
%               only the instantaneous data. Please refer to
%               graphiceElements.useLogs for further description of the
%               function parameters.
%               Each figure must specify at least one of the draw or
%               drawLog function handles (otherwise a warning is generated)
%       Note: The same 'userData' is used in init, draw and drawLog
%               
% - logging:
%       Structure to define the logging behavior.
%       - disabled: bool, set to true to completely disable logging for 
%                   this block
%       - uniform: bool; if set to true, output, debugOut and state records
%                  are expected to be the same format for each and every
%                  iteration. This allows storing the data in linear arrays
%                  instead of cell arrays, which is much more space
%                  effective, especially for small records. If a block has
%                  load/unload function handles (see below), the original
%                  outputs may be non-uniform, but the residues returned
%                  from unload must be uniform. If the block consistently
%                  returns empty ([]), then a uniform log consumes no
%                  memory at all (but keep in mind that returning empty for
%                  out is considered invalid, causing no log record at all.
%                  However, the unload function might return empty for out)
%       - unload: If set to a function handle, this function is called on
%                 creation of each log entry to reduce the entrie's size.
%                 The function can use whatever method is appropriate, e.g.
%                 writing data to disk, to a database, use a compression
%                 algorithm or a combination of the aforementioned. The
%                 function returns a "residue", that is stored instead of 
%                 the original log entry. This residue might contain a file 
%                 path, or database index or whatever is necessary to
%                 restore the original data on demand.
%       - load: Counterpart to .unload, which takes the residue as input 
%               should return the original log entry, if requested by the
%               simulation framework. 
%       - maxCached: per-block size of the cache holding loaded log entries
%                    (3 per default)
% - mexFiles:
%       Cell array of mexFiles used by this block and instructions on how
%       to compile then from source(s). Each field is either a string with
%       the absolute(!) path of the main source file (including extension)
%       or a struct with the following fields:
%       - file: absolute path to the main source file (including extension)
%               and is equivalent to giving a string instead of a struct
%       - dependencies: Optional string or a cell array of strings. Files 
%                       that should be checked for modification when 
%                       determining if a recompilation is necessary. Add 
%                       additional source and/or header files here if you 
%                       change them frequently.
%       - options: A cell array of command line options that will be passed
%                  to the mex command after the initial source file name.
%                  If this filed is missing, the main source file is
%                  scanned for a line starting with '//$ mex ...' and this
%                  is used for invocation of the mex command. Add this
%                  option with an empty string/cell array to prevent
%                  scanning the source file for command line options.
%
% Each block may be accompanied by a (sub-)workspace with "private"
% variables by making the functions subfunctions of the appropriate block
% creator.
%
function block = block_base(deltaT, depends, funcHandle)
    % provide some defaults            
    if isempty(deltaT); deltaT = 0; end
        
    % argument checking
    if ~isempty(funcHandle) && ~isa(funcHandle, 'function_handle')
        error('Invalid argument "funcHandle": not a function handle');        
    end
    
    % create block struct
    block.isBlock = true; % special block marker (for sanity checking)
    % timing specification
    block.timing.deltaT = 0;
    block.timing.offset = 0;
    block.timing.maxT = inf;
    block.timing.maxIterations = inf;
    block.timing.triggers = [];
    block.timing.getNextT = [];
    if iscellstr(deltaT)
        block.timing.triggers = deltaT;
        block.timing.deltaT = inf;
    elseif ischar(deltaT)
        block.timing.triggers = {deltaT};
        block.timing.deltaT = inf;
    elseif isa(deltaT, 'function_handle')
        block.timing.getNextT = deltaT;
        block.timing.deltaT = eps; % placeholder value that is > 0 (to indicate a discrete block), but < inf to indicate a nonconstant block
    else
        if ~isnumeric(deltaT) || ~isscalar(deltaT) || ~(deltaT >= 0)
            error('Invalid argument "deltaT": scalar nonzero value required');
        end
        block.timing.deltaT = deltaT;
    end

    block.index = []; % index in runtime structure
    
    if isempty(depends), block.depends = {};
    elseif ischar(depends), block.depends = {depends};
    elseif iscell(depends), block.depends = depends;
    else error('Invalid argument for "depends": string or cell array of strings expected.');
    end
    
    if isempty(funcHandle), block.process = @defaultProcess;
    else block.process = funcHandle; end
    block.graphicElements = repmat(struct('name', [], 'hideByDefault', false, 'draw', [], 'useLogs', false), 0);
    block.figures = repmat(struct('name', [], 'icon', [], 'init', [], 'draw', [], 'drawLog', []), 0);
        
    block.log = struct('disabled', false, 'uniform', false, 'unload', [], 'load', [], 'maxCached', 3);
    
    block.mexFiles = {};
    
    function [out, debug] = defaultProcess(varargin)
        out = [];
        debug = [];
    end
end