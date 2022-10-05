function simulate(param)
    
    mfilePath = fileparts(mfilename('fullpath'));
    
    % create instance of simulator engine 
    if ischar(param)
        dialog = showProgressMessage('Loading experiment from ''%s''...', param);
        simCtrl = simulator_engine(param);
        dialog.close();
    else simCtrl = simulator_engine(param);
    end
    
    experiment = simCtrl.getExperimentSpecification();
    
    dirty = false; % will be set after every computation step
    % On exit, the experiment will be saved only if dirty is true
    
    warning('off','MATLAB:HandleGraphics:ObsoletedProperty:JavaFrame');	
	if isprop(0, 'HideUndocumented')
		set(0,'HideUndocumented','off');
	end

	% load settings (window positions etc.)
	try
		load('workspace.mat');
    catch ME
		% Default-Werte
		settings.mainWindow = struct('isMaximized', true, 'position', []);
        settings.viewControl = struct('position', [], 'visible', false);
        settings.viewControl.settings = repmat(struct('name', [], 'on', true), 0);
        settings.figures = repmat(struct('name', [], 'visible', false, 'position', [], 'maximized', false), 0);
		
		settings.stepping.interval = 0.1;
		settings.stepping.selected = [];
    end

    % create figure for mainWindow
    mw.handle = figure('Name', ['Simulation: ', experiment.name], 'NumberTitle', 'off', 'CloseRequestFcn', @cleanup, 'ToolBar', 'figure', 'Renderer', 'OpenGL');
	if ~isempty(settings.mainWindow.position), set(mw.handle, 'Position', settings.mainWindow.position); end
	if settings.mainWindow.isMaximized, maximizeFigure(mw.handle); end
	set(mw.handle, 'ResizeFcn', @resizeCallback);
    
    % set window icon
    jframe = get(mw.handle, 'javaframe');
	jframe.setFigureIcon(javax.swing.ImageIcon(fullfile(mfilePath, 'res/appicon.png')));	
    
    timelineSlider = uicontrol('style', 'slider', 'Units', 'pixels', 'Position', [0 0 100 16], 'Enable', 'off'); 
    timeLabel = uicontrol('Style', 'text', 'Units', 'pixels', 'Position', [100 0 100 16], 'String', '--- / 0');
    set(timelineSlider, 'Callback', @sliderMoved);    
    
    % extract display settings from experiment structure and setup main
    % axes
    display = struct();
    if isfield(experiment, 'display')
        if isstruct(experiment.display); display = experiment.display; 
        else warning('Sim:Display:InvalidDisplaySettings', 'Invalid display settings - using defaults');
        end
    end    
    if isfield(display, 'settings'); axProps = experiment.display.settings; else axProps = {}; end;
    mw.ax = axes('Parent', mw.handle, 'DataAspectRatio', [1 1 1], axProps{:}, 'Units', 'pixels', 'ActivePositionProperty', 'outerposition');
    hold(mw.ax, 'on');
    if isfield(display, 'xLabel'); 
        if iscell(display.xLabel); xlabel(display.xLabel{:}); else xlabel(display.xLabel); end
    end
    if isfield(display, 'yLabel');
        if iscell(display.yLabel); ylabel(display.yLabel{:}); else ylabel(display.yLabel); end
    end
    if isfield(display, 'zLabel');
        if iscell(display.zLabel); zlabel(display.zLabel{:}); else zlabel(display.zLabel); end
    end
    if isfield(display, 'title');
        if iscell(display.title); title(display.title{:}); else title(display.title); end
    end
    if isfield(display, 'view'); view(display.view); end        
    if isfield(display, 'axis'); axis(display.axis); end
    if isfield(display, 'camlight')
        if iscell(display.camlight); camlight(display.camlight{:}); else camlight(display.camlight); end
    end
    rotate3d();    

	% configure display update interval
    updateInterval = 0.1; % default value = 10Hz
	if isfield(display, 'updateInterval')
        if isnumeric(display.updateInterval) && numel(display.updateInterval) == 1; updateInterval = display.updateInterval;
        else warning('Sim:Display:InvalidDisplaySettings', 'Invalid value for display.updateInterval - using default');
        end
    end
	% structure for separate window for enabling/disabling graphic elements
	viewControl.windowHandle = [];
	
	% add new menu for simulation environment
	simMenu = uimenu('Label', 'Simulation');
	
	stepBackAction.menuHandle = uimenu(simMenu, 'Label', 'Step back', 'enable', 'off', 'Callback', @doStepBack);
	pauseAction.menuHandle = uimenu(simMenu, 'Label', 'Pause', 'Callback', @toggleRunPause, 'Checked', 'on');
	runAction.menuHandle = uimenu(simMenu, 'Label', 'Run', 'Accelerator', ' ', 'Callback', @toggleRunPause);
	stepAction.menuHandle = uimenu(simMenu, 'Label', 'Step forward', 'Accelerator', char(10), 'Callback', @doStep);
	steppingSelectionMenu = uimenu(simMenu, 'Label', 'Select Step size');
	stepping.autoMenuHandle = uimenu(steppingSelectionMenu, 'Label', 'Automatic', 'Callback', @(varargin)selectStepping(0));
	stepping.fixedMenuHandle = uimenu(steppingSelectionMenu, 'Label', sprintf('Fixed interval (%0.3f s)...', settings.stepping.interval), 'Callback', @(varargin)selectStepping(NaN));	
	
	recomputeAction.menuHandle = uimenu(simMenu, 'Label', 'Recompute from here', 'enable', 'off', 'separator', 'on', 'Callback', @prepareRecompute);	
		
	videoAction.menuHandle = uimenu(simMenu, 'Label', 'Record Video...', 'separator', 'on', 'Callback', @toggleVideo);
    viewControl.toggleAction.menuHandle = uimenu(simMenu, 'Label', 'Show/Hide', 'Callback', @showHideViewControlWindow, 'Accelerator', '8');
	% add figure entries from blocks
    
	% setup toolbar
	ht = findall(mw.handle, 'tag', 'FigureToolBar');
	children = allchild(ht);
    %for i = 1:length(children); fprintf('tag = %s\n', get(children(i), 'tag')); end
    keepList = {'Standard.SaveFigure', 'Standard.PrintFigure', 'Standard.EditPlot', ...
                'Exploration.DataCursor', 'Exploration.Rotate', 'Exploration.ZoomIn', 'Exploration.ZoomOut', 'Exploration.Pan', ...
                };
    keepBtn = [];
    for i = 1:length(keepList)
        keepBtn = [keepBtn findall(ht, 'tag', keepList{i})];
    end    
    delete(setdiff(children, keepBtn));	
	% Add new tool buttons for simulation environment
	videoAction.buttonHandle = uitoggletool(ht, 'CData', loadIcon(fullfile(mfilePath, 'res/video.png')), 'ClickedCallback', @toggleVideo);
	    
    stepBackAction.buttonHandle = uipushtool(ht, 'separator', 'on', 'ToolTipString', 'Step backwards', 'ClickedCallback', @doStepBack, 'Enable', 'off');    
    pauseAction.buttonHandle = uitoggletool(ht, 'ToolTipString', 'Pause Simulation', 'ClickedCallback', @toggleRunPause, 'State', 'on');
    runAction.buttonHandle = uitoggletool(ht, 'ToolTipString', 'Run Simulation', 'ClickedCallback', @toggleRunPause);
    stepAction.buttonHandle = uipushtool(ht, 'ToolTipString', 'Step forward', 'ClickedCallback', @doStep);
    recomputeAction.buttonHandle = uipushtool(ht, 'ToolTipString', 'Recompute from here', 'enable', 'off', 'ClickedCallback', @prepareRecompute);
	drawnow(); % trigger creating the java objects from matlab toolbuttons, so we can get a reference to them
    jToolBar = get(get(ht, 'JavaContainer'), 'ComponentPeer');
    stepBackAction.jButton = jToolBar.getComponent(jToolBar.getComponentCount() - 5);
    pauseAction.jButton = jToolBar.getComponent(jToolBar.getComponentCount() - 4);
    runAction.jButton = jToolBar.getComponent(jToolBar.getComponentCount() - 3);
    stepAction.jButton = jToolBar.getComponent(jToolBar.getComponentCount() - 2);
	recomputeAction.jButton = jToolBar.getComponent(jToolBar.getComponentCount() - 1);
    % load the icons and save them in the buttons
	stepBackAction.replayIcon = javax.swing.ImageIcon(fullfile(mfilePath, 'res/prev_blue.png'));
    stepBackAction.computeIcon = javax.swing.ImageIcon(fullfile(mfilePath, 'res/prev_green.png'));
    pauseAction.replayIcon = javax.swing.ImageIcon(fullfile(mfilePath, 'res/pause_blue.png'));
    pauseAction.computeIcon = javax.swing.ImageIcon(fullfile(mfilePath, 'res/pause_green.png'));
    runAction.replayIcon = javax.swing.ImageIcon(fullfile(mfilePath, 'res/play_blue.png'));
    runAction.computeIcon = javax.swing.ImageIcon(fullfile(mfilePath, 'res/play_green.png'));    
    stepAction.replayIcon = javax.swing.ImageIcon(fullfile(mfilePath, 'res/next_blue.png'));
    stepAction.computeIcon = javax.swing.ImageIcon(fullfile(mfilePath, 'res/next_green.png'));
	
    stepBackAction.jButton.setIcon(stepBackAction.replayIcon);
    pauseAction.jButton.setIcon(pauseAction.computeIcon);
    runAction.jButton.setIcon(runAction.computeIcon);
    stepAction.jButton.setIcon(stepAction.computeIcon);
	recomputeAction.jButton.setIcon(javax.swing.ImageIcon(fullfile(mfilePath, 'res/repeat_blue.png')));
	
	viewControl.toggleAction.buttonHandle = uitoggletool(ht, 'CData', loadIcon(fullfile(mfilePath, 'res/showhide.png')), 'separator', 'on', 'ClickedCallback', @showHideViewControlWindow);

	stepping.interval = settings.stepping.interval;
	stepping.block = [];
	stepping.auto = true;
	
    simBlocks = simCtrl.getBlocks();
    blocks = repmat(struct(), size(simBlocks));
    nFigures = 0;
	nSteppingBlocks = 0;
    for iBlock = 1:length(blocks)
        blocks(iBlock).name = simBlocks(iBlock).name;
		if nSteppingBlocks == 0; stepMenuSeparator = 'on'; else stepMenuSeparator = 'off'; end
		if ~isinf(simBlocks(iBlock).spec.timing.deltaT)
			nSteppingBlocks = nSteppingBlocks + 1;
			blocks(iBlock).stepMenuHandle = uimenu(steppingSelectionMenu, 'Label', ['step from ' blocks(iBlock).name], 'Separator', stepMenuSeparator, 'Callback', @(varargin)selectStepping(iBlock));	
			if isempty(stepping.block) && ischar(settings.stepping.selected) && strcmp(settings.stepping.selected, blocks(iBlock).name)
				set(blocks(iBlock).stepMenuHandle, 'Checked', 'on'); 
				stepping.block = iBlock;
			end
		else blocks(iBlock).stepMenuHandle = [];
		end
		
        blocks(iBlock).graphicElements = repmat(struct(), numel(simBlocks(iBlock).spec.graphicElements), 1);
        for iElem = 1:length(blocks(iBlock).graphicElements)
            blocks(iBlock).graphicElements(iElem).name = simBlocks(iBlock).spec.graphicElements(iElem).name;                
            idx = find(ismember({settings.viewControl.settings.name}, [blocks(iBlock).name '.' blocks(iBlock).graphicElements(iElem).name]), 1);
            if ~isempty(idx); on = settings.viewControl.settings(idx).on;
            elseif ~isempty(simBlocks(iBlock).spec.graphicElements(iElem).hideByDefault)
                on = ~simBlocks(iBlock).spec.graphicElements(iElem).hideByDefault;
            else on = true;
            end

            blocks(iBlock).graphicElements(iElem).on = on;
            blocks(iBlock).graphicElements(iElem).draw = simBlocks(iBlock).spec.graphicElements(iElem).draw;
            if ~isempty(simBlocks(iBlock).spec.graphicElements(iElem).useLogs)
                blocks(iBlock).graphicElements(iElem).useLogs = simBlocks(iBlock).spec.graphicElements(iElem).useLogs;
            else blocks(iBlock).graphicElements(iElem).useLogs = false;
            end
            blocks(iBlock).graphicElements(iElem).handles = [];
            blocks(iBlock).graphicElements(iElem).needsUpdate = false;
        end
        blocks(iBlock).figures = repmat(struct(), numel(simBlocks(iBlock).spec.figures), 1);
        figMenu = [];
		for iFig = 1:length(blocks(iBlock).figures)
            if ~isa(simBlocks(iBlock).spec.figures(iFig).init, 'function_handle') || ...
               (isempty(simBlocks(iBlock).spec.figures(iFig).draw) && isempty(simBlocks(iBlock).spec.figures(iFig).drawLog)) || ...   
               (~isempty(simBlocks(iBlock).spec.figures(iFig).draw) && ~isa(simBlocks(iBlock).spec.figures(iFig).draw, 'function_handle')) || ...
               (~isempty(simBlocks(iBlock).spec.figures(iFig).drawLog) && ~isa(simBlocks(iBlock).spec.figures(iFig).drawLog, 'function_handle'))               
                warning('Sim:Figure:Invalid', 'figure specification %d of block ''%s'' invalid.', iFig, blocks(iBlock).name);
                continue;
            end
            blocks(iBlock).figures(iFig).name = simBlocks(iBlock).spec.figures(iFig).name;
            blocks(iBlock).figures(iFig).init = simBlocks(iBlock).spec.figures(iFig).init;
            blocks(iBlock).figures(iFig).draw = simBlocks(iBlock).spec.figures(iFig).draw;
            blocks(iBlock).figures(iFig).drawLog = simBlocks(iBlock).spec.figures(iFig).drawLog;
            blocks(iBlock).figures(iFig).handle = [];
            blocks(iBlock).figures(iFig).userData = [];
            blocks(iBlock).figures(iFig).visible = false;
            blocks(iBlock).figures(iFig).position = [];
            blocks(iBlock).figures(iFig).maximized = false;
            blocks(iBlock).figures(iFig).needsUpdate = false;
            blocks(iBlock).figures(iFig).alwaysOnTop = false;
            blocks(iBlock).figures(iFig).alwaysOnTopButton = [];
            
            idx = find(ismember({settings.figures.name}, [blocks(iBlock).name '.' blocks(iBlock).figures(iFig).name]), 1);
            if ~isempty(idx)
                blocks(iBlock).figures(iFig).visible = settings.figures(idx).visible;
                blocks(iBlock).figures(iFig).position = settings.figures(idx).position;
                blocks(iBlock).figures(iFig).maximized = settings.figures(idx).maximized;
                blocks(iBlock).figures(iFig).alwaysOnTop = settings.figures(idx).alwaysOnTop;
            end
            
            icon = simBlocks(iBlock).spec.figures(iFig).icon;
            if ischar(icon); icon = loadIcon(icon); end
            if nFigures == 0; sep = 'on'; else sep = 'off'; end
            if isempty(icon); icon = loadIcon(fullfile(mfilePath, 'res/figure_default.png')); end
            blocks(iBlock).figures(iFig).toggleAction.buttonHandle = uitoggletool(ht, 'CData', icon, 'separator', sep, ...
                                                                     'ToolTipString', blocks(iBlock).figures(iFig).name, ...
                                                                     'ClickedCallback', @(varargin)showHideFigure(iBlock, iFig), 'state', 'off');            
            if isempty(figMenu); figMenu = uimenu(simMenu, 'Label', blocks(iBlock).name); end
			blocks(iBlock).figures(iFig).toggleAction.menuHandle = uimenu(figMenu, 'Label', blocks(iBlock).figures(iFig).name, ...
																   'Callback', @(varargin)showHideFigure(iBlock, iFig));
			nFigures = nFigures + 1; 
        end
	end
	
	if isempty(stepping.block)
		if ~isempty(settings.stepping.selected) && isnumeric(settings.stepping.selected) && settings.stepping.selected > 0
			stepping.auto = false;
		end		
		if stepping.auto
			set(stepping.autoMenuHandle, 'Checked', 'on');
		else set(stepping.fixedMenuHandle, 'Checked', 'on');
		end
	end
	
    clear simBlocks;
    if settings.viewControl.visible; showHideViewControlWindow(); end
    for iBlock = 1:length(blocks)
        for iFig = 1:length(blocks(iBlock).figures)
            if blocks(iBlock).figures(iFig).visible; 
                blocks(iBlock).figures(iFig).visible = false;
                showHideFigure(iBlock, iFig); 
            end
        end
    end
    
    % some variables:
    % t     - point in time, the simulation has advanced to
    tLog = -1;  % selected point in time during replay (tLog <= t)	
    % experimentFinished - True when the engine reported completion of the experiment
    replay = false; % false when computing new data, true when using the replay functionality	
    abort = false;    
    [t, experimentFinished] = simCtrl.getExperimentState();
    
    if ischar(param)
        % experiment loaded from file
        if experimentFinished
            setLogPosition(0); % ready for replay
        else setLogPosition(t); % ready for continuing simulation
        end
    end
    
    recorder = []; % video recorder object
    recordingEnabled = false;
    
    % bring mainwindow to the foreground
    figure(mw.handle);

    
    
    % - End of initialization - 
    
    % From now, the simulator relies on events dispatched from Matlab's 
    % main loop.
    
    
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % "Member" functions
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    % Toggle run/pause by checking the current state and invoking either
    % doPause or doRun . This is the callback registered to both controls.
    function toggleRunPause(varargin)
		if strcmp(get(pauseAction.menuHandle, 'Checked'), 'off')
			doPause();
		else doRun();
		end
    end

    % interrupt simulation/replay, if running
	function doPause()
		setRunCheckState(false);
		if recordingEnabled; toggleVideo(); end
        abort = true;
    end
    
    % Run simlation or replay until someone sets abort = true (e.g. doPause)
 	function doRun()
		setRunCheckState(true);
		changed = [];
		tRealNextUpdate = 0;
		tSimNextUpdate = 0; % This causes an update after the first computation step (even if we do not start from the beginning)
		ticId = tic();		
		abort = false;
		if replay
			% The replay code is basically the same as the simulation code
			% below. See below for further explanations
			while ~abort
				doUpdate = false;
				atEnd = false;
				[tNew, changedInStep] = simCtrl.incLogPosition();
				if tNew == tLog && isempty(changedInStep)
					atEnd = true;
					doUpdate = true;
				else
					tLog = tNew;
					changed = union(changed, changedInStep);
				end
				tReal = toc(ticId);
				diffT = tRealNextUpdate - tReal;
				if diffT <= 0
					doUpdate = true;
					tRealNextUpdate = tReal + updateInterval;
				elseif t >= tSimNextUpdate
					diffT = diffT + tLog - tSimNextUpdate;
					doUpdate = true;
					if diffT > 0.05
						tRealNextUpdate = tReal + diffT + updateInterval;
						pause(diffT - 0.05);
						if abort; return; end
					end
				end
				if doUpdate
					if t > 0; setActionEnabled(stepBackAction, true); end
                    update(changed);
					if abort; return; end
                    
                    if recordingEnabled; recordFrame(tLog); end                                            
                    
					changed = [];
					tSimNextUpdate = tLog + updateInterval;
					if atEnd
						endOfLogReached();
						doPause();
					end
				end
			end
		else
			while ~abort			
				doUpdate = false;
				[tNew, changedInStep] = simCtrl.doStep();
				if tNew == t && isempty(changedInStep)
					experimentFinished = true;
					doUpdate = true;
                else
                    dirty = true;
                    t = tNew;
					changed = union(changed, changedInStep);
				end

				tReal = toc(ticId);
				diffT = tRealNextUpdate - tReal;
				if diffT <= 0
					% do an update because frame inverval elapsed in real-time
					% a.k.a. the simulation is too slow compared to real-time
					doUpdate = true;
					tRealNextUpdate = tReal + updateInterval;
				elseif t >= tSimNextUpdate
					diffT = diffT + t - tSimNextUpdate;
					% do an update because frame interval elapsed in simulation-time
					doUpdate = true;
					if diffT > 0.05
						% slow down to real-time, if necessary
						% a.k.a. simulation too fast compared to real-time. In
						% this case reduce timing jitter by scheduling the next
						% update relative to the previous one, not the current
						% time
						tRealNextUpdate = tReal + diffT + updateInterval;
						pause(diffT - 0.05);
						if abort; return; end
					else tRealNextUpdate = tReal + updateInterval;
					end
				end

				if doUpdate
					if t > 0; setActionEnabled(stepBackAction, true); end
					update(changed);
					if abort; return; end
					
                    if recordingEnabled; recordFrame(t); end                        
                    
                    changed = [];
					tSimNextUpdate = t + updateInterval;							

					if experimentFinished
						% switch to replay mode and disable run/step commands
						% because we cannot go further
						setReplay(true);
                        tLog = simCtrl.setLogPosition(t);						
                        setActionEnabled(pauseAction, false);
                        setActionEnabled(runAction, false);						
                        setActionEnabled(stepAction, false);                        
						% This will also set abort, which is required for the 
						% rare case when this function is invoked recursively 
						% due to multiple clicks to the appropriate controls. 
						% The outer call(s) will bail out immediately, when the
						% innermost call has finished the experiment.
                        
                        doPause();
					end
				end
			end
		end
    end
	
    % compute or replay a single step accoring to the selecting stepping
    % criterion.
    % Callback for stepAction's controls.
 	function doStep(varargin)
		doPause();
        changed = [];
		if replay
			tStart = tLog;
			while true
				[tNew, changedInStep] = simCtrl.incLogPosition();
				if tNew == tLog && isempty(changedInStep); break; end
				tLog = tNew;
				changed = union(changed, changedInStep);
				if ~isempty(stepping.block);
					if ismember(stepping.block, changed); break; end
				elseif stepping.auto || (tLog - tStart + 1e-6) >= stepping.interval; break;
				end
			end
			setActionEnabled(stepBackAction, tLog > 0);
			if tLog >= t; endOfLogReached(); end
			
		else
			if ~experimentFinished % should always hold
				tStart = t;
				while true
					[tNew, changedInStep] = simCtrl.doStep();
					if tNew == t && isempty(changedInStep)
						experimentFinished = true;
						break;
                    else dirty = true;
                    end
					t = tNew;
					changed = union(changed, changedInStep);
					if ~isempty(stepping.block)
						if ismember(stepping.block, changed); break; end
					elseif stepping.auto || (t - tStart + 1e-6) >= stepping.interval; break;
					end
				end	
				if t > 0; setActionEnabled(stepBackAction, true); end
			end
			if experimentFinished
				setReplay(true);
				cellfun(@(h)set(h, 'Enable', 'off'), {runAction.menuHandle, runAction.buttonHandle, stepAction.menuHandle, stepAction.buttonHandle});					
			end			
        end
		update(changed);		
    end

    % Go back a single step (according to the selected stepping criterion)
    % in the recorded log data.
    % Callback for stepBackAction's controls.
 	function doStepBack(varargin)		
		doPause();
        if ~replay
			setReplay(true);
			tLog = simCtrl.setLogPosition(t);
        end
		changed = [];
		atStart = false;
		tStart = tLog;
        while true
			[tNew, changedInStep] = simCtrl.decLogPosition();
			if tNew == tLog && isempty(changedInStep)
				atStart = true;
				break;
			end
			tLog = tNew;
			changed = union(changed, changedInStep);
			if ~isempty(stepping.block)
				if ismember(stepping.block, changed); break; end
			elseif stepping.auto || (tStart - tLog + 1e-6) >= stepping.interval; break;
			end
        end
        
        setActionEnabled(stepBackAction, ~atStart && tLog > 0);
		setActionEnabled(recomputeAction, tLog < t);
        setActionEnabled(pauseAction, tLog < t);
        setActionEnabled(runAction, tLog < t);
        setActionEnabled(stepAction, tLog < t);
        
		update(changed);
    end

    % Handle drag event of the Slider.
    % Callback for timelineSlider
 	function sliderMoved(varargin)
        % Note, that this routine sometimes does not work as expected, 
        % because matlab fires events only, when releasing the mouse button
        % and in the meantime, doRun might have already repositioned the 
        % slider, thus it apperears as if the slider jumps back to its 
        % original position. If you know a workaround, let me know.

        wasInRunMode = (replay && onOffToBool(get(runAction.menuHandle, 'Checked')));        
        doPause();        
        tSlider = get(timelineSlider, 'Value');
		if tSlider > 0; tSlider = tSlider + 1e-7; end
        setLogPosition(tSlider);
        
        if wasInRunMode
            %doRun(); 
        end
    end
    function setLogPosition(tDesired)
		[tLog, changed] = simCtrl.setLogPosition(tDesired);
		if ~replay
			changed = 1:length(blocks);
			setReplay(true);
		end		
		setActionEnabled(stepBackAction, tLog > 0);
		if tLog < t
			setActionEnabled(recomputeAction, true);		
			setActionEnabled(pauseAction, true);
            setActionEnabled(runAction, true);
			setActionEnabled(stepAction, true);
		else endOfLogReached();
        end
		update(changed);
    end
    
    % Callback for recomputeAction's controls
    function prepareRecompute(varargin)
        if strcmp(questdlg('This will delete all computed results from here?', 'Confirm Recomputation', 'Ok', 'Cancel', 'Cancel'), 'Ok')
            doPause();
            
            simCtrl.recomputeFromHere();
            
            t = tLog;
            experimentFinished = false;
            if t == 0; set(timelineSlider, 'Enable', 'off', 'Value', 0, 'Max', eps); end
            setTime(t);
            setReplay(false);
        end        
 	end

    % Some small helper functions for the above
	function setReplay(newReplay)
		if newReplay == replay; return; end
		replay = newReplay;
		if replay
			cellfun(@(a)a.jButton.setIcon(a.replayIcon), {pauseAction, runAction, stepAction});
		else
			setActionEnabled(recomputeAction, false);
			setTime(t);
			cellfun(@(a)a.jButton.setIcon(a.computeIcon), {pauseAction, runAction, stepAction});
		end
    end
	function setRunCheckState(run)	
		pauseOnOff = boolToOnOff(~run);
		set(pauseAction.menuHandle, 'Checked', pauseOnOff);
		set(pauseAction.buttonHandle, 'State', pauseOnOff);
		runOnOff = boolToOnOff(run);
		set(runAction.menuHandle, 'Checked', runOnOff);
		set(runAction.buttonHandle, 'State', runOnOff);
	end
    function endOfLogReached()
		setActionEnabled(recomputeAction, false);
		if experimentFinished
			setActionEnabled(pauseAction, false);
            setActionEnabled(runAction, false);
			setActionEnabled(stepAction, false);
		else setReplay(false);
		end	
    end
	function setTime(tShow)
		if tShow > t; tShow = t; end
		set(timeLabel, 'String', sprintf('%0.3f / %0.3f s', tShow, t));
		if t > 0; set(timelineSlider, 'Value', tShow, 'Max', t, 'Enable', 'on'); end
    end
    function setActionEnabled(action, enabled)
		onOff = boolToOnOff(enabled);
		if isfield(action, 'menuHandle'); set(action.menuHandle, 'Enable', onOff); end
		if isfield(action, 'buttonHandle'); set(action.buttonHandle, 'Enable', onOff); end		
    end

    function toggleVideo(varargin)
        isOn = onOffToBool(get(videoAction.menuHandle, 'Checked')); 
        
        if ~isOn
            if ~isempty(recorder)
                answers = {'Yes, append to file', 'No, create new file'};
                if strcmp(questdlg(sprintf('Would you like to continoue recording into %s?', recorder.getFileName()), ...
                                   'Video Recorder Configuration', answers{:}, answers{1}), answers{1})
                    % reuse the old recorder object
                    isOn = true;
                    recorder.startChapter();
                else
                    recorder.delete();
                    recorder = [];
                end
            end
            
            if ~isOn
                if isfield(settings, 'videoRecorder')
                  videoSettings = settings.videoRecorder;
                else videoSettings = struct();
                end
                % set video framerate to display update interval
                videoSettings.frameRate = 1 / updateInterval;
                [recorder, videoSettings] = videoRecorder(videoSettings, true);
                if ~isempty(recorder)
                    settings.videoRecorder = rmfield(videoSettings, 'frameRate');
                    isOn = true;
                % else cancel was pressed
                end
            end
            if isOn; recordingEnabled = true; end
        else
            isOn = false;
            recordingEnabled = false;
            % don't clear 'recorder', as we might continue operation later
        end
        newOnOff = boolToOnOff(isOn);
        set(videoAction.menuHandle, 'checked', newOnOff);
        set(videoAction.buttonHandle, 'state', newOnOff);
    end
    function recordFrame(t)
        errMsg = recorder.addFrame(getframe(mw.ax), t);
        if ~isempty(errMsg)
            uiwait(errordlg(errMsg, 'RecorderError'));
            if recordingEnabled; toggleVideo(); end
        end
    end


    % Update graphic Elements 'iElems' (or all, if not given) and figures
    % 'iFigs' (all if not given) for blocks 'changed'
    % The function checkes 'replay' and gathers information using the
    % appropriate method for each mode
    function update(changed, iElems, iFigs)
		simBlocks = simCtrl.getBlocks();
        [simLogs, logPositions] = simCtrl.getLogs();
		for iIdx = 1:length(changed)
			iBlock = changed(iIdx);
            loaded = false;
            if ~replay
                logPos = simBlocks(iBlock).iteration;
                [out, debugOut, state, inputs] = deal(simBlocks(iBlock).out, simBlocks(iBlock).debugOut, simBlocks(iBlock).state, simBlocks(iBlock).lastInputs);
            else logPos = logPositions(changed(iIdx));
            end

            % Note when out = []:
            % The engine considers empty outputs as failure, therefore the
            % only way for an empty 'out' to reach this code is when
            % either accessing a block that has nevern been computed or
            % accessing an invalid log entry (log index out of range, or
            % failure of load/unload routines)
            
			if nargin < 2; iElems = 1:length(blocks(iBlock).graphicElements); end                        
			for iElem = iElems
                if blocks(iBlock).graphicElements(iElem).on
                    blocks(iBlock).graphicElements(iElem).needsUpdate = false;

                    if blocks(iBlock).graphicElements(iElem).useLogs
                        blocks(iBlock).graphicElements(iElem).handles = ...
                            blocks(iBlock).graphicElements(iElem).draw(...
                                simBlocks(iBlock).spec, mw.ax, blocks(iBlock).graphicElements(iElem).handles, ...
                                logPos, simLogs(iBlock).times, simLogs(iBlock).out, simLogs(iBlock).debugOut, simLogs(iBlock).state);
                    else
                        if replay && ~loaded; loadLogRecord(changed(iIdx)); end
                        if isempty(out); continue; end % no break, since maybe we have some entries with useLogs left over
                        blocks(iBlock).graphicElements(iElem).handles = ...
                            blocks(iBlock).graphicElements(iElem).draw(...
                                simBlocks(iBlock).spec, mw.ax, blocks(iBlock).graphicElements(iElem).handles, ...
                                out, debugOut, state, inputs{:});
                    end

                else blocks(iBlock).graphicElements(iElem).needsUpdate = true;
                end
			end
            if nargin < 3; iFigs = 1:length(blocks(iBlock).figures); end
            for iFig = iFigs
                if blocks(iBlock).figures(iFig).visible
                    blocks(iBlock).figures(iFig).needsUpdate = false;
                                        
                    if ~isempty(blocks(iBlock).figures(iFig).drawLog)
                        blocks(iBlock).figures(iFig).userData = blocks(iBlock).figures(iFig).drawLog(...
                            simBlocks(iBlock).spec, blocks(iBlock).figures(iFig).handle, blocks(iBlock).figures(iFig).userData, ...
                            logPos, simLogs(iBlock).times, simLogs(iBlock).out, simLogs(iBlock).debugOut, simLogs(iBlock).state);
                    end
                    if ~isempty(blocks(iBlock).figures(iFig).draw)
                        if replay && ~loaded; loadLogRecord(changed(iIdx)); end
                        if isempty(out); continue; end

                        blocks(iBlock).figures(iFig).userData = blocks(iBlock).figures(iFig).draw(...
                            simBlocks(iBlock).spec, blocks(iBlock).figures(iFig).handle, blocks(iBlock).figures(iFig).userData, ...
                            out, debugOut, state, inputs{:});
                    end
                    
                else blocks(iBlock).figures(iFig).needsUpdate = true;
                end
            end            
		end
		
		if replay; setTime(tLog); else setTime(t); end
        drawnow; % cancellation point
        
        function loadLogRecord(iBlock)
            logRecord = simCtrl.getLogRecords(iBlock);
            [out, debugOut, state, inputs] = deal(logRecord.out, logRecord.debugOut, logRecord.state, logRecord.inputs);
            loaded = true;            
        end
    end    

    % Close event handler for mainwindow
    % Stop any running simulation/replay, save state and current window
    % settings for restoring them on the next run
    function cleanup(varargin)
        doPause();
        
        % stop video recording
        if ~isempty(recorder)
            recorder.delete();
            recorder = [];
        end
        
        if ~isempty(viewControl.windowHandle)
            settings.viewControl.settings(:) = [];
            for iBlock = 1:length(blocks);
                for iElem = 1:length(blocks(iBlock).graphicElements)
                    settings.viewControl.settings(end + 1) = ...
                        struct('name', [blocks(iBlock).name, '.', blocks(iBlock).graphicElements(iElem).name], ...
                               'on', blocks(iBlock).graphicElements(iElem).on);
                end
            end
            settings.viewControl.visible = onOffToBool(get(viewControl.toggleAction.menuHandle, 'checked'));
            settings.viewControl.position = get(viewControl.windowHandle, 'Position');
            
            delete(viewControl.windowHandle);
        end
        settings.figures(:) = [];
        for iBlock = 1:length(blocks)
            for iFig = 1:length(blocks(iBlock).figures)
                hFig = blocks(iBlock).figures(iFig).handle;
                if ~isempty(hFig)
                    if ~isempty(blocks(iBlock).figures(iFig).closeCallback)
                        blocks(iBlock).figures(iFig).closeCallback(hFig);
                    end
                    if ishghandle(hFig); delete(hFig); end                                
                end            
                settings.figures(end + 1).name = [blocks(iBlock).name '.' blocks(iBlock).figures(iFig).name];
                settings.figures(end).visible = blocks(iBlock).figures(iFig).visible;
                settings.figures(end).position = blocks(iBlock).figures(iFig).position;
                settings.figures(end).maximized = blocks(iBlock).figures(iFig).maximized;            
                settings.figures(end).alwaysOnTop = blocks(iBlock).figures(iFig).alwaysOnTop;            
            end
        end
        settings.stepping.interval = stepping.interval;
        if isempty(stepping.block)
            if ~stepping.auto; settings.stepping.selected = stepping.interval;
            else settings.stepping.selected = [];
            end
        else settings.stepping.selected = blocks(stepping.block).name;
        end
        
        if ~settings.mainWindow.isMaximized
            settings.mainWindow.position = get(mw.handle, 'Position');
        end
        
        % save whole experiment, if desired
        if dirty && isfield(experiment, 'path') && ~isempty(experiment.path) 
            if ischar(experiment.path)
                dialog = showProgressMessage(['Saving experiment to ''' experiment.path '''...']);                
                simCtrl.saveExperiment(experiment.path);            
                dialog.close();
            else
                warning('Sim:Save:InvalidPath', 'Could not save experiment. '',path'' has wrong type');
            end
        end
        save 'workspace.mat' settings;
        % finally delete the main window
        delete(mw.handle);
    end

    % Resize event handler for main window
	function resizeCallback(hObject, ~)
		settings.mainWindow.isMaximized = isMaximized(hObject);
        windowPos = get(hObject, 'Position');
        if ~settings.mainWindow.isMaximized; settings.mainWindow.position = windowPos; end        
        labelWidth = 150;
        width = max(labelWidth - 50, windowPos(3));
        set(timelineSlider, 'Position', [0, 0, width - labelWidth, 16]);
        set(timeLabel, 'Position', [width - labelWidth, 0, labelWidth, 16]);
        set(mw.ax, 'OuterPosition', [0, 16, width, max(windowPos(4) - 16, 1)]);
	end


    % Handle the menu items for selecting the stepping criterion
    % iBlock identifies, which entry was invoked by the user:
    % NaN:  fixed stepping interval (ask user to enter the new interval)
    % 0:    automatic stepping
    % >= 1: Block with index iBlock
	function selectStepping(iBlock)
		if isnan(iBlock)
			default = num2str(stepping.interval);
			while true
				res = inputdlg('Step interval', 'Simulation Environment', 1, {default});
				if isempty(res); return; end
				default = res{1};
				newInterval = str2double(res{1});
				if isnan(newInterval) || newInterval <= 0
					if strcmp(questdlg('Please enter a positive number', 'Invalid input', 'Cancel', 'Retry', 'Retry'), 'Cancel')
						return;
					end
				else break;
				end
			end			
		end
		
		if ~isempty(stepping.block); set(blocks(stepping.block).stepMenuHandle, 'Checked', 'off');
		elseif stepping.auto; set(stepping.autoMenuHandle, 'Checked', 'off');
		else set(stepping.fixedMenuHandle, 'Checked', 'off');
		end
		if iBlock >= 1
			stepping.block = iBlock;
			set(blocks(iBlock).stepMenuHandle, 'Checked', 'on');
		elseif iBlock == 0;
			stepping.block = [];			
			stepping.auto = true;
			set(stepping.autoMenuHandle, 'Checked', 'on');
		else			
			stepping.block = [];
			stepping.interval = newInterval;
			stepping.auto = false;
			set(stepping.fixedMenuHandle, 'Checked', 'on', 'Label', sprintf('fixed interval (%0.3f s)...', newInterval));
		end
    end

    % Implement the show/hide graphic elements dialog
	function showHideViewControlWindow(varargin)			
		show = ~onOffToBool(get(viewControl.toggleAction.menuHandle, 'checked'));
		set(viewControl.toggleAction.menuHandle, 'checked', boolToOnOff(show));
		set(viewControl.toggleAction.buttonHandle, 'state', boolToOnOff(show));		
        if show
			if isempty(viewControl.windowHandle)
				% create the view control window
                viewControl.windowHandle = figure('Name', 'Show/Hide', 'DockControls', 'off', ...
                                                  'MenuBar', 'None', 'NumberTitle', 'off', ...
                                                  'Color', get(0, 'defaultUicontrolBackgroundColor'), ...
                                                  'CloseRequestFcn', @viewControlCloseCallback, 'DeleteFcn', @cleanup);	

                if ~isempty(settings.viewControl.position)
                    set(viewControl.windowHandle, 'Position', settings.viewControl.position);
                end

                jframe = get(viewControl.windowHandle, 'javaframe');
                jframe.setFigureIcon(javax.swing.ImageIcon(fullfile(mfilePath, 'res/showhide_big.png')));	
                
                showIcon = imread(fullfile(mfilePath, 'res/show.png'));
                hideIcon = imread(fullfile(mfilePath, 'res/hide.png'));
                viewControl.showIcon = im2java(showIcon);
                viewControl.hideIcon = im2java(hideIcon);
                viewControl.iconSize = max(size(showIcon, 2), size(hideIcon, 2));

                rootNode = uitreenode('v0', [], ['Experiment: ' experiment.name], [], false);
                
                parents = struct('node', rootNode, 'name', []);
                for iBlock = 1:length(blocks)
                    if isempty(blocks(iBlock).graphicElements); continue; end
                    pathParts = regexp(blocks(iBlock).name, '/', 'split');
                    %fprintf('adding block %s\n', blocks(iBlock).name);
                    if length(parents) > length(pathParts)
                        parents((length(pathParts) + 1):end) = [];
                    end
                    for iPart = 1:length(pathParts) % note: last element is never processed by this loop!
                        if iPart < length(pathParts) && iPart < length(parents)
                            %fprintf('checking pathPart %s vs %s\n', pathParts{iPart}, parents(iPart + 1).name);
                            if ~strcmp(pathParts{iPart}, parents(iPart + 1).name)
                                parents((iPart + 1):end) = [];                                
                            else continue;
                            end
                        end
                        break;
                    end
                    for iRemPart = iPart:(length(pathParts) - 1)
                        %fprintf('adding new intermediate node %s\n', pathParts{iRemPart});
                        newNode = uitreenode('v0', [], pathParts{iRemPart}, [], false);
                        parents(end).node.add(newNode);
                        parents(end + 1) = struct('node', newNode, 'name', pathParts{iRemPart});
                    end
                    blockNode = uitreenode('v0', [], pathParts{end}, [], false);
                    
                    if length(blocks(iBlock).graphicElements) == 1 && isempty(blocks(iBlock).graphicElements(1).name)                        
                        if blocks(iBlock).graphicElements(1).on; blockNode.setIcon(viewControl.showIcon);
                        else blockNode.setIcon(viewControl.hideIcon);
                        end
                        blockNode.setValue([iBlock, 1]);
                    else                        
                        for iElem = 1:length(blocks(iBlock).graphicElements)
                            elemNode = uitreenode('v0', [iBlock, iElem], blocks(iBlock).graphicElements(iElem).name, [], true);                            
                            if blocks(iBlock).graphicElements(iElem).on;
                                elemNode.setIcon(viewControl.showIcon);
                            else elemNode.setIcon(viewControl.hideIcon);
                            end                            
                            blockNode.add(elemNode);
                        end
                    end
                    parents(end).node.add(blockNode);
                end
                [viewControl.tree.handle, container] = uitree('v0', viewControl.windowHandle, 'root', rootNode);                
                set(container, 'Units', 'normalized', 'Position', [0 0 1 1]);
                viewControl.tree.javaObj = handle(viewControl.tree.handle.getTree, 'CallbackProperties');

                % expand all nodes
                iRow = 0;
                while iRow < viewControl.tree.javaObj.getRowCount
                    viewControl.tree.javaObj.expandRow(iRow);
                    iRow = iRow + 1;
                end

                set(viewControl.tree.javaObj, 'MousePressedCallback', @mouseDown);
            else set(viewControl.windowHandle, 'visible', 'on');
			end

			setFigureAlwaysOnTop(viewControl.windowHandle);
			figure(mw.handle);
        else set(viewControl.windowHandle, 'visible', 'off');
        end

        function mouseDown(~, eventData)
            mousePos = [eventData.getX, eventData.getY];
            treePath = viewControl.tree.javaObj.getPathForLocation(mousePos(1), mousePos(2));            
            if isempty(treePath); return; end % not clicked on item
            
            % check if the checkbox was clicked
            if mousePos(1) <= (viewControl.tree.javaObj.getPathBounds(treePath).x + viewControl.iconSize);             
                node = treePath.getLastPathComponent();
                nodeValue = node.getValue();
                if isempty(nodeValue); return; end % not a checkable node

                on = blocks(nodeValue(1)).graphicElements(nodeValue(2)).on;
                blocks(nodeValue(1)).graphicElements(nodeValue(2)).on = ~on;
                if on
                    node.setIcon(viewControl.hideIcon);
                    forEachHgHandle(blocks(nodeValue(1)).graphicElements(nodeValue(2)).handles, @(h)set(h, 'Visible', 'off'));
                else
                    node.setIcon(viewControl.showIcon);
                    forEachHgHandle(blocks(nodeValue(1)).graphicElements(nodeValue(2)).handles, @(h)set(h, 'Visible', 'on'));
                    if blocks(nodeValue(1)).graphicElements(nodeValue(2)).needsUpdate
                        update(nodeValue(1), nodeValue(2), []);
                    end
                end
                viewControl.tree.javaObj.treeDidChange();
            end
        end
        function cleanup(varargin)
            % Matlab seems to not release workspace variables bound to java
            % objects if these are freed (maybe it does, but Java GC does
            % not clear the objects immediately or whatever...)
            % The prevents destructor calls to handle classes,
            % which is especially bad if these classes wrap mex files with
            % system ressources.
            % By removing all Matlab reference from the Java object before
            % we loose track of it, we can prevent this problem
            % (Maybe this is fixed in Matlab version later than 2012a, but 
            % the "workaround" will not harm anyway)
            set(viewControl.tree.javaObj, 'MousePressedCallback', []);
        end
        
    end    
	function viewControlCloseCallback(hObject, ~)		
        set(viewControl.toggleAction.menuHandle, 'checked', 'off');
		set(viewControl.toggleAction.buttonHandle, 'state', 'off');
		set(hObject, 'visible', 'off');
    end

    % show/hide an additional block figure. This function handles the
    % creation of figures on demand as well as saving their state on
    % closing
    function showHideFigure(iBlock, iFig)
        show = ~blocks(iBlock).figures(iFig).visible;
		set(blocks(iBlock).figures(iFig).toggleAction.buttonHandle, 'state', boolToOnOff(show));	
        set(blocks(iBlock).figures(iFig).toggleAction.menuHandle, 'checked', boolToOnOff(show));
		
        if isempty(blocks(iBlock).figures(iFig).handle)
            simBlocks = simCtrl.getBlocks();        
            % create figure by calling the block's init function
            
            [f, data] = blocks(iBlock).figures(iFig).init(simBlocks(iBlock).spec, blocks(iBlock).name);
            clear simBlocks;
            if isempty(f) || ~ishghandle(f)
                % callback decided to not create a figure
                warning('Sim:Gui:FigureInitFailure', 'init call for figure ''%s'' on block ''%s'' returned no figure handle', ...
                        blocks(iBlock).figures(iFig).name, blocks(iBlock).name);
                set(blocks(iBlock).figures(iFig).toolButton, 'state', 'off');
                return;
            end
            % If possible, add an always-on-top button to the figure
            figHt = findall(f, 'Tag', 'FigureToolBar');
            if ~isempty(figHt)
                blocks(iBlock).figures(iFig).alwaysOnTopButton = ...
                    uitoggletool(figHt, 'CData', loadIcon(fullfile(mfilePath, 'res/pin.png')), 'ClickedCallback', @toggleAlwaysOnTopCallback, 'ToolTipString', 'Toggle figure always-on-top');                
            end
            
            blocks(iBlock).figures(iFig).handle = f;
            blocks(iBlock).figures(iFig).userData = data;
            if ~isempty(blocks(iBlock).figures(iFig).position), set(f, 'Position', blocks(iBlock).figures(iFig).position); end
            if blocks(iBlock).figures(iFig).maximized, maximizeFigure(f); end
            
            blocks(iBlock).figures(iFig).resizeCallback = get(f, 'ResizeFcn');
            if ~isa(blocks(iBlock).figures(iFig).resizeCallback, 'function_handle'); blocks(iBlock).figures(iFig).resizeCallback = []; end
            blocks(iBlock).figures(iFig).closeCallback = get(f, 'CloseRequestFcn');            
            if ~isa(blocks(iBlock).figures(iFig).closeCallback, 'function_handle'); blocks(iBlock).figures(iFig).closeCallback = []; end            
            set(f, 'ResizeFcn', @resizeFigure, 'CloseRequestFcn', @closeFigure);
        end
        set(blocks(iBlock).figures(iFig).handle, 'visible', boolToOnOff(show));
        blocks(iBlock).figures(iFig).visible = show;
        if show 
            if blocks(iBlock).figures(iFig).alwaysOnTop && ~isempty(blocks(iBlock).figures(iFig).alwaysOnTopButton)
                set(blocks(iBlock).figures(iFig).alwaysOnTopButton, 'State', 'on');
                setFigureAlwaysOnTop(blocks(iBlock).figures(iFig).handle);
            end
            if blocks(iBlock).figures(iFig).needsUpdate; update(iBlock, [], iFig); end
        end
        
        function resizeFigure(hObject, varargin)            
            if ~isempty(blocks(iBlock).figures(iFig).resizeCallback)
                blocks(iBlock).figures(iFig).resizeCallback(hObject, varargin{:});
            end
            
            maximized = isMaximized(hObject);
            blocks(iBlock).figures(iFig).maximized = maximized;
            if ~maximized; blocks(iBlock).figures(iFig).position = get(hObject, 'Position'); end
        end
        function toggleAlwaysOnTopCallback(varargin)
            desired = onOffToBool(get(blocks(iBlock).figures(iFig).alwaysOnTopButton, 'State'));
            setFigureAlwaysOnTop(blocks(iBlock).figures(iFig).handle, desired);
            blocks(iBlock).figures(iFig).alwaysOnTop = desired;
        end        
        function closeFigure(hObject, varargin)
            blocks(iBlock).figures(iFig).visible = false;
            set(blocks(iBlock).figures(iFig).toggleAction.buttonHandle, 'state', 'off');
			set(blocks(iBlock).figures(iFig).toggleAction.menuHandle, 'checked', 'off');
            set(hObject, 'visible', 'off');            
        end
    end
end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% some common helper functions
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%	

function forEachHgHandle(s, func, varargin)
    if iscell(s)
        for i=1:numel(s)
            forEachHgHandle(s{i}, func, varargin{:});
        end
    elseif isstruct(s)
        nElems = numel(s);
        if nElems > 1
            for i = 1:nElems
                forEachHgHandle(s(i), func, varargin{:});
            end
        else
            fields = fieldnames(s);
            for i = 1:length(fields)
                forEachHgHandle(s.(fields{i}), func, varargin{:});
            end
        end
    else
        nElems = numel(s);
        if ~isnumeric(s) || nElems > 1000; return; end
        for i = 1:nElems
            if ~ishghandle(s(i)); break; end
            func(s(i), varargin{:});
        end
    end
end

% converts strings 'on'/'off' to boolean true/false and vice versa
function [b] = onOffToBool(o)
    if strcmp(o, 'on'); b = 1; else b = 0; end
end
function [o] = boolToOnOff(b)
	if b, o = 'on'; else o = 'off'; end
end

% Uses Java to force a figure always on top (useful for tool windows)
function setFigureAlwaysOnTop(h, enabled)
    if nargin < 2; enabled = true; end
    jh = get(h, 'JavaFrame');
    drawnow;    
    jh.fHG2Client.getWindow.setAlwaysOnTop(enabled);		
end

% maximizes a figure using Java properties
function maximizeFigure(h)
    %drawnow update;
    jh = get(h, 'JavaFrame');
    drawnow;
    set(jh, 'Maximized', 1);
end

% return the maximized state of a figure
function [b] = isMaximized(h)
    jh = get(h, 'JavaFrame');
    b = get(jh, 'Maximized');
end

function dialog = showProgressMessage(string, varargin)
    handle = msgbox(sprintf(string, varargin{:}), 'Operation in progress', 'Help');
    dialogChildren = get(handle, 'Children');
    delete(dialogChildren(end));
    set(handle, 'CloseRequestFcn', '');            
    dialog.close = @closeDialog;    
    function closeDialog()
        if ishghandle(handle); delete(handle); end
    end
end

% create an icon for a pushbutton or toolbar entry from a PNG file 
% If possible, transparency information is honored, i.e. only binary
% transparency is supported. For full alpha support, use the underlying 
% java objects.
function [icon] = loadIcon(fileName)
    [icon, ~, iconAlpha] = imread(fileName);
    icon = double(icon) / 255;
    icon(iconAlpha < 1) = NaN;
end
