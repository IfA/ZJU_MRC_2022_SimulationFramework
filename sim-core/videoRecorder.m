% On Linux the 'best' method for video recording seems to be using the
% Motion JPEG 2000 codec with CompressionRation set to a pretty low value
% (e.g. 10) and transcoding the resulting file to H.264 afterwards using
% the ffmpeg command line utility:
% 
% ffmpeg -i <inputfile>.mj2 -vcodec h264 -qp 26  -aspect <width>:<height> <outputfile>.avi
% 
% Since Matlab does not store correct Display-Aspect-Ratio information, we
% have to override them using the -aspect command line option.
function [v, defaults] = videoRecorder(defaults, showConfigurationDialog)
    if nargin < 1; 
        defaults = struct(); 
        showConfigurationDialog = true;
    elseif nargin < 2; showConfigurationDialog = false;
    end
    
    % description of supported codecs (can be extended, when Matlab
    % supports more codecs (or at least supports more codecs on specific
    % platforms)
    codecs          = struct('name', 'Uncompressed',     'profile', 'Uncompressed AVI', 'extensions', 'avi', 'parameters', []);
    codecs(end + 1) = struct('name', 'Lossless',         'profile', 'Archival',         'extensions', 'mj2', 'parameters', []);
    codecs(end + 1) = struct('name', 'Motion JPEG',      'profile', 'Motion JPEG AVI',  'extensions', 'avi', 'parameters', ...
                                                            struct('name', 'Quality', 'range', [0 100], 'value', 50, 'type', 'linear'));
    codecs(end + 1) = struct('name', 'Motion JPEG 2000', 'profile', 'Motion JPEG 2000', 'extensions', 'mj2', 'parameters', ...
                                                            struct('name', 'CompressionRatio', 'range', [1 1000], 'value', 50, 'type', 'log'));    
    if ispc() || ismac()
        codecs(end + 1) = struct('name', 'MPEG4 (H.264)', 'profile', 'MPEG-4', 'extensions', {{'mp4', 'm4v'}}, 'parameters', ...
                                                            struct('name', 'Quality', 'range', [0 100], 'value', 50, 'type', 'linear'));
    end
    
    % prepare default settings
    settings.fileName = '';
    settings.frameRate = 10;
    settings.codecIdx = find(strcmp({codecs.name}, 'Motion JPEG'), 1);
    if isempty(settings.codecIdx); settings.codecIdx = 1; end

    % take parameters from defaults
    if isfield(defaults, 'fileName') && ischar(defaults.fileName)
        settings.fileName = defaults.fileName;
    end
    if isfield(defaults, 'frameRate') && isnumeric(defaults.frameRate) && ~isempty(defaults.frameRate) && defaults.frameRate(1) > 0
        settings.frameRate = defaults.frameRate(1);
    end
    if isfield(defaults, 'codec') && ischar(defaults.codec)
        desiredIdx = find(strcmp({codecs.name}, defaults.codec), 1);
        if ~isempty(desiredIdx); settings.codecIdx = desiredIdx; end
    end
    for iCodec = 1:length(codecs)
        for iParam = 1:length(codecs(iCodec).parameters)
            pName = codecs(iCodec).parameters(iParam).name;
            if isfield(defaults, pName) && strcmp(class(codecs(iCodec).parameters(iParam).value), class(defaults.(pName)))
                codecs(iCodec).parameters(iParam).value = defaults.(pName);                
                if codecs(iCodec).parameters(iParam).value < codecs(iCodec).parameters(iParam).range(1)
                    codecs(iCodec).parameters(iParam).value = codecs(iCodec).parameters(iParam).range(1);
                elseif codecs(iCodec).parameters(iParam).value > codecs(iCodec).parameters(iParam).range(2)
                    codecs(iCodec).parameters(iParam).value = codecs(iCodec).parameters(iParam).range(2);
                end                
            end
        end
    end
    
    if showConfigurationDialog
        [settings, codecs, codecSettings]= configDialog(settings, codecs);
        if isempty(settings)
            % user pressed cancel
            v = [];
            return;
        end
        
        fNames = fieldnames(codecSettings);
        for iParam = 1:length(fNames)
            defaults.(fNames{iParam}) = codecSettings.(fNames{iParam});
        end
        defaults.fileName = settings.fileName;
        defaults.codec = codecs(settings.codecIdx).name;
    end

    v = struct();
    
    writer = VideoWriter(settings.fileName, codecs(settings.codecIdx).profile);
    writer.FrameRate = settings.frameRate;
    for iParam = 1:length(codecs(settings.codecIdx).parameters)
        writer.(codecs(settings.codecIdx).parameters(iParam).name) = codecs(settings.codecIdx).parameters(iParam).value;
    end
    isOpen = false;
    tStart = [];
    lastFrame = [];
    lastFrameIndex = [];
    
    v.getFileName = @()settings.fileName;
    v.getFrameRate = @()settings.frameRate;
    v.addFrame = @addFrame;
    v.startChapter = @startChapter;
    v.delete = @deleteThis;    
    
    function [errMsg] = addFrame(frame, time)
        if isempty(writer)
            errMsg = 'videoRecorder object not initialized';
            return;
        end
        errMsg = [];
        try
            if ~isOpen
                open(writer);
                isOpen = true;            
            end
            if isempty(tStart) 
                tStart = time; 
                lastFrameIndex = 1; % necessary to ensure frameIndex < lastFrameIndex
            end
            frameIndex = round((time - tStart) * settings.frameRate);
            if frameIndex < lastFrameIndex
                tStart = time;
                frameIndex = 0;
                writeVideo(writer, frame);
            else
                for i = (lastFrameIndex + 1):(frameIndex - 1)
                    writeVideo(writer, lastFrame);
                end
                if frameIndex > lastFrameIndex; writeVideo(writer, frame); end
            end
            lastFrame = frame;
            lastFrameIndex = frameIndex;
        catch ME
            errMsg = ME.message;
        end        
    end
    % This resets the counters for automatic frame-rate adaption
    function startChapter()
        tStart = [];
    end
    function deleteThis()
        if isOpen
            close(writer);
            writer = [];
            isOpen = false;
        end
    end    
end

function [settings, codecs, codecSettings] = configDialog(settings, codecs)
    warning('off','MATLAB:HandleGraphics:ObsoletedProperty:JavaFrame');	    
    
    sw.handle = dialog('Name', 'Video Recorder Settings', 'WindowStyle', 'modal', 'Resize', 'off');
    jframe = get(sw.handle, 'javaframe');
    jframe.setFigureIcon(javax.swing.ImageIcon('res/video.png'));	

    spacing = 8;
    rowHeight = 24;
    paramRowHeight = 16;
    nParams = max(arrayfun(@(c)length(c.parameters), codecs));
    buttonSz = [80 32];    
    columnWidth = [120, 280];
    
    overwriteConfirmed = false;
    codecSettings = struct();
    
    sz = [sum(columnWidth) + spacing * (1 + length(columnWidth)), ...
          3 * rowHeight + nParams * paramRowHeight + buttonSz(2) + (5 + nParams) * spacing]; % dialog width, height
    currentPos = get(sw.handle, 'Position');
    set(sw.handle, 'Position', [currentPos(1), currentPos(2) - sz(2) + currentPos(4), sz(1), sz(2)]);

    columnX = [0 columnWidth(1:(end - 1))] + spacing * (1:length(columnWidth));        
    y = sz(2) - spacing - rowHeight;

    sw.fileLabel = uicontrol(sw.handle, 'Style', 'Text', 'String', 'Output file:', 'HorizontalAlignment', 'left', ...
                             'Units', 'pixels', 'Position', [columnX(1), y, columnWidth(1), rowHeight - 4]);

    sw.fileEdit = uicontrol(sw.handle, 'Style', 'edit', 'String', '', 'BackgroundColor', [1 1 1], 'HorizontalAlignment', 'left', 'Callback', @fileEdited, ...
                            'Units', 'pixels', 'Position', [columnX(2), y, columnWidth(2) - spacing - rowHeight, rowHeight]);
    sw.fileButton = uicontrol(sw.handle, 'Style', 'pushbutton', 'String', '...', 'Callback', @selectFile, ...
                              'Units', 'pixels', 'Position', [columnX(2) + columnWidth(2) - rowHeight, y, rowHeight, rowHeight]);
    y = y - rowHeight;
    sw.warnLabel = uicontrol(sw.handle, 'Style', 'Text', 'HorizontalAlignment', 'left', ...
                             'Units', 'pixels', 'Position', [columnX(2), y, columnWidth(2), rowHeight]);

    y = y - spacing - rowHeight;
    sw.codecLabel = uicontrol(sw.handle, 'Style', 'Text', 'String', 'Codec:', 'HorizontalAlignment', 'left', ...
                              'Units', 'pixels', 'Position', [columnX(1), y, columnWidth(1), rowHeight - 4]);
    sw.codecBox = uicontrol(sw.handle, 'Style', 'popupmenu', 'String', {codecs.name}, 'Callback', @codecChanged, ...
                            'Units', 'pixels', 'Position', [columnX(2), y, columnWidth(2), rowHeight]);

    for iParam = 1:nParams
        y = y - spacing - paramRowHeight;
        sw.paramLabels(iParam) = uicontrol(sw.handle, 'Style', 'Text', 'String', '', 'HorizontalAlignment', 'left', 'Enable', 'off', ...
                                           'Units', 'pixels', 'Position', [columnX(1), y, columnWidth(1), paramRowHeight]);
        sw.paramSliders(iParam) = uicontrol(sw.handle, 'Style', 'slider', 'Min', 0, 'Max', 100, 'Value', 50, 'Enable', 'off', 'Callback', @(varargin)paramSliderChanged(iParam), ...
                                            'Units', 'pixels', 'Position', [columnX(2), y, columnWidth(2) - rowHeight - spacing, paramRowHeight]);
        sw.paramNumberLabels(iParam) = uicontrol(sw.handle, 'Style', 'Text', 'String', '---', 'HorizontalAlignment', 'right', 'Enable', 'off', ...
                                                'Units', 'pixels', 'Position', [columnX(2) + columnWidth(2) - rowHeight - spacing, y, rowHeight + spacing, paramRowHeight]);
    end

    y = y - 2 * spacing - buttonSz(2);        

    sw.okButton = uicontrol(sw.handle, 'Style', 'PushButton', 'String', 'Ok', 'Callback', @ok, ...
                            'Units', 'pixels', 'Position', [sz(1) - 2 * spacing - 2 * buttonSz(1), y, buttonSz]);
    sw.cancelButton = uicontrol(sw.handle, 'Style', 'PushButton', 'String', 'Cancel', 'Callback', @cancel, ...
                                'Units', 'pixels', 'Position', [sz(1) - spacing - buttonSz(1), y, buttonSz]);       
    filePath = fileparts(mfilename('fullpath'));
    
    labelStr = ['<html><center>Recording will start, when you press <img src="file://' filePath '/res/play_green.png">&nbsp;or&nbsp;<img src="file://' filePath '/res/play_blue.png"></center></html>'];
    jLabel = javaObjectEDT('javax.swing.JLabel',labelStr);
    javacomponent(jLabel, [spacing, y, sz(1) - 2 * buttonSz(1) - 4 * spacing, buttonSz(2)], sw.handle);                        
    
    setFile(settings.fileName);        
    set(sw.codecBox, 'Value', settings.codecIdx);
    codecChanged();
    
    uiwait(sw.handle);
    
    function codecChanged(varargin)
        idx = get(sw.codecBox, 'Value');
        settings.codecIdx = idx;
        for iParam = 1:length(codecs(idx).parameters)
            set(sw.paramLabels(iParam), 'String', [codecs(idx).parameters(iParam).name ':'], 'Enable', 'on');
            range = codecs(idx).parameters(iParam).range;
            val = codecs(idx).parameters(iParam).value;
            if strcmp(codecs(idx).parameters(iParam).type, 'log'); 
                range = log10(range); 
                val = log10(val);
            end                
            set(sw.paramSliders(iParam), 'Min', range(1), 'Max', range(2), 'Value', val, 'Enable', 'on');
            set(sw.paramNumberLabels(iParam), 'String', sprintf('%0.0f', codecs(idx).parameters(iParam).value), 'Enable', 'on');
        end
        
        offRange = (length(codecs(idx).parameters) + 1):length(sw.paramLabels);
        set(sw.paramLabels(offRange), 'String', '', 'Enable', 'off');
        set(sw.paramSliders(offRange), 'Min', 0, 'Max', 1, 'Value', 0, 'Enable', 'off');
        set(sw.paramNumberLabels(offRange), 'String', '---', 'Enable', 'off');
        
        setFile(correctExtension(get(sw.fileEdit, 'String'), codecs(idx).extensions));
    end

    function paramSliderChanged(iParam)
        iCodec = get(sw.codecBox, 'Value');
        val = get(sw.paramSliders(iParam), 'Value');
        if strcmp(codecs(iCodec).parameters(iParam).type, 'log');
            val = 10^val;
        end
        val = round(val);
        set(sw.paramNumberLabels(iParam), 'String', sprintf('%0.0f', val));
        codecs(iCodec).parameters(iParam).value = val;
        codecSettings.(codecs(iCodec).parameters(iParam).name) = val;
    end

    function selectFile(varargin)
        idx = get(sw.codecBox, 'Value');
        if ~ischar(codecs(idx).extensions)
            temp = cellfun(@(s)sprintf('*.%s;', s), codecs(idx).extensions(1:(end - 1)), 'UniformOutput', false);
            filters = [temp{:}, '*.', codecs(idx).extensions{end}];            
        else filters = ['*.' codecs(idx).extensions];            
        end        
        [fileName, pathName] = uiputfile({filters, ['Video files (' filters ')']}, 'Select Video Output File', get(sw.fileEdit, 'String'));
        if ischar(fileName) 
            overwriteConfirmed = true;            
            setFile(correctExtension([pathName fileName], codecs(idx).extensions));            
        end        
    end

    function fileName = correctExtension(fileName, extensions)
        if isempty(fileName); return; end            
        [path, name, ext] = fileparts(fileName);
        if ~isempty(ext); ext = ext(2:end); end
        if ischar(extensions)
            ext = extensions;
        else
            found = false;
            for i = 1:numel(extensions)
                if strcmp(ext, extensions{i}); found = true; break; end
            end
            if ~found; ext = extensions{1}; end
        end
        if ~isempty(path); path = [path filesep]; end
        fileName = [path name '.' ext];
    end
    function fileEdited(varargin)
        setFile(correctExtension(get(sw.fileEdit, 'String'), codecs(get(sw.codecBox, 'Value')).extensions));
    end
    function setFile(fileName)
        if isempty(fileName); return; end
        set(sw.fileEdit, 'String', fileName);        
        settings.fileName = fileName;
        if exist(fileName, 'file') == 2,
            set(sw.warnLabel, 'String', 'File exists and will be overwritten!', 'ForegroundColor', [0.8 0 0]);
        else set(sw.warnLabel, 'String', 'New file will be created.', 'ForegroundColor', [0 0.4 0]);            
        end
    end

    function ok(varargin)
        % check for filename
        if isempty(settings.fileName)
            uiwait(helpdlg('Please select an output file!', 'Settings incomplete'));
        else
            if ~overwriteConfirmed && exist(settings.fileName, 'file') == 2
                if ~strcmp(questdlg(sprintf('Do you want to overwrite the Video file ''%s''?', settings.fileName), 'File exists', 'Yes', 'No', 'No'), 'Yes')
                    return;
                end
            end
            delete(sw.handle);
        end        
    end
    function cancel(varargin)
        settings = [];
        delete(sw.handle);
    end    
end
