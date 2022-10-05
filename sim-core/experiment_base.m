% Description of the 'experiment' structure.
% 
% An experiment is completely defined by a more or less complex nested
% struct. This struct mainly consists of fields representing blocks. It is
% also possible to group blocks by putting them into substructs. The
% simulation environment will automatically detect blocks within
% substructs. 
% further fields are:
% - depends: mark blocks as 'used' if their outputs are not connected to
%            any other block. This is required for open loop experiments.
%            Otherwise the automatic dependency detection will remove
%            entire chains due to their results seem unused to the
%            simulation environment.
% - stop: special block that is capable of stopping the simulation
%         environment on behalf of a certain condition. Stop must be set to
%         a block and is in most cases treated like any other block
%         (timings, graphical output, etc.) with two execptions:
%         1) it is always computed, i.e. implicitely contained in
%         'depends'.
%         2) Its output value must be (convertible to) a bool. A value of
%         'true' will stop the simulation experiment.
% - path: where to store experiment data (relative to the basepath provided
%         in config.m
% - name: name of the experiment. Used as figure caption and for file names
% - storeMode: How to store experimental results on disk. Three modes are
%              supported:
%              - 'none': store nothing.
%              - 'flat': store everything in the 'path' folder. Two files
%                        <experiment-name>-out.mat and
%                        <experiment-name>-debug.mat are created with all
%                        the output and debug data from active blocks.
%                        Additional files from the outFiles and debugFiles
%                        mechanism are stored in the same folder. Be
%                        careful to prevent name clashes with these files.
%              - 'normal': create a folder hierarchy below 'path' that
%                          resembles the block hierarchy from the
%                          experiment specification (one folder per block).
%                          The two files out.mat and debug.mat are stored
%                          per block (i.e. per folder), possibly
%                          accompanied with more data from the outFiles and
%                          debugFiles mechanism.
% 'Group' paramenters:
% Besides the fields common to each block, all blocks may have additional
% parameters and settings that are specific to their function. The
% framework also supports a 'group parameter' feature, that works as 
% follows: If a grouping structure contains fields, that are not blocks by
% itself, these fields are propagated to all blocks down the hierarchy iff
% the block does not contain a similar-named field by itself. Note however,
% that this mechanism works only on grouping substructures of the
% experiment specification, not on the experiment structure itself. If you
% desire to set a certain parameter for all blocks, you can easily do so by
% grouping all blocks in a single substructure.
%
function exp = experiment(name, path)
    exp = struct();
    
    if nargin < 1; name = []; end
    if nargin < 2; path = []; end
    
    if ~isempty(name) && ~ischar(name), error('Argument "name" has invalid format. String expected.'); end
    if ~isempty(path) && ~ischar(path), error('Argument "path" has invalid format. String expected.'); end
    
    if isempty(name), warning('Sim:Exp:NoName', 'Experiment has no name.'); end

    exp.name = name;
    exp.path = path;
    
    if isempty(exp.path), exp.storeMode = 'none';
    else exp.storeMode = 'normal'; end

    exp.depends = {};
end