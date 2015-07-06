function CSTProcessVideos
% Copyright (c) 2013 Rutgers
% Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
% The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
% THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

% This function creates a window displaying sequences (frame by frame), where the user can launch the processing per sequence, and manually draw and edit the segmented worms.

global fileDB filterSelection flagRobustness fileToLog currentImage timingOn timings timingsLabel timingsTime zoneOkForCompleteWorms zoneOkForStartingWorms listOfWorms traceOn colFtlWell mainPnlW mainPnlH;

% ============
% CREATE THE INTERFACE
% ============
% ----------
% Main figure and sliders
% ----------
defaultImSize = [640 480];
% -------------------
% Initialize variables
% -------------------
handlesPoints = [];
listOfPoints = [];
handleCircle = [];
idxVideo = [];
flagOkToDrawWell = false;
videoBeingProcessed = 0;
totalFrames = 0;
wellMarginSize = 6;
imageMarginSize = 6;
stepImagesAuto = 20;
scrsz = get(0,'ScreenSize');
mainW = min(mainPnlW, scrsz(3) - 10);
mainH = min(mainPnlH, scrsz(4) - 70);
mainPanelPosition = [2 , mainH-mainPnlH-2 , mainPnlW , mainPnlH];
mainFigure = figure('Visible','off','Position',[5,40,mainW,mainH],'Name','CeleST: Video Processing - Choose the videos to process, define the swimming zones, launch the processing','numbertitle','off', 'menubar', 'none', 'resizefcn', @resizeMainFigure);
mainPanel = uipanel('parent', mainFigure,'BorderType', 'none','units','pixels', 'position', mainPanelPosition);
sliderHoriz = uicontrol('parent',mainFigure,'style','slider','position',[0 0 mainW-20 20],'max', 1,'min',0, 'value',0,'callback',@setMainPanelPositionBySliders);
sliderVert = uicontrol('parent',mainFigure,'style','slider','position',[mainW-20 20 20 mainH-20],'max', max(1,-mainPanelPosition(2)),'min',0, 'value',max(1,-mainPanelPosition(2)),'callback',@setMainPanelPositionBySliders);
set(mainFigure, 'color', get(mainPanel,'backgroundcolor'));
set(mainFigure,'colormap',gray);

% ----------
% Filters
% ----------
filterH = 100;
filterW = 150;
hFilters = filterH + 20;
yFilters = mainPnlH - hFilters - 5;
pnlFilters = uipanel('parent', mainPanel,'BorderType', 'none','units','pixels', 'position', [1 yFilters mainPnlW hFilters]);
listFilters = fieldnames(fileDB);
idxtmp = 1;
while idxtmp <= length(listFilters)
    if strcmp(listFilters{idxtmp},'name') || strcmp(listFilters{idxtmp},'directory') || strcmp(listFilters{idxtmp},'format')...
            || strcmp(listFilters{idxtmp},'frames_per_second') || strcmp(listFilters{idxtmp},'mm_per_pixel') || strcmp(listFilters{idxtmp},'set')...
            || strcmp(listFilters{idxtmp},'duration') || strcmp(listFilters{idxtmp},'images') || strcmp(listFilters{idxtmp},'glareZones')...
            || strcmp(listFilters{idxtmp},'note') || strcmp(listFilters{idxtmp},'worms') || strcmp(listFilters{idxtmp},'well')...
            || strcmp(listFilters{idxtmp},'month') || strcmp(listFilters{idxtmp},'day') || strcmp(listFilters{idxtmp},'year')
        listFilters(idxtmp) = [];
    else
        idxtmp = idxtmp + 1;
    end
end
        
for idxtmp = 0:length(listFilters)-1
    uicontrol('parent',pnlFilters,'style','text','string',listFilters{idxtmp+1},'position',[idxtmp*filterW filterH filterW 20])
    flt.(listFilters{idxtmp+1}) = uicontrol('parent',pnlFilters,'style','listbox','String',{''},'max',2,'min',0,'position',[idxtmp*filterW 0 filterW filterH],'callback',@setFilteredList);
end




% ----------
% List of videos filtered
% ----------
yVideos = yFilters - 3*filterH - 65;
txtListVideosFiltered = uicontrol('parent',mainPanel,'style','text', 'FontWeight', 'bold','HorizontalAlignment', 'left','String','Videos to choose from: (0 filtered)','position',[0 yVideos+3*filterH+30 2*filterW 20]);
listVideosFiltered =  uicontrol('parent',mainPanel,'style','listbox','String',{''},'max',2,'min',0,'position',[0 yVideos 2*filterW 3*filterH]);
listVideosFilteredIdx = [];
uicontrol('parent',mainPanel,'style','pushbutton', 'string', 'Select all', 'position', [0 yVideos+3*filterH filterW-10 30], 'callback', @(a,b) set(listVideosFiltered, 'value', 1:length(get(listVideosFiltered,'string'))))
uicontrol('parent',mainPanel,'style','pushbutton', 'string', 'Deselect all', 'position', [filterW+10 yVideos+3*filterH filterW-10 30], 'callback', @(a,b) set(listVideosFiltered, 'value', []))

btnClose = uicontrol('parent',mainPanel,'style','pushbutton', 'string', 'Close', 'position', [20 yVideos-50 filterW 30], 'callback', @closeWindow);

btnAddVideos = uicontrol('parent',mainPanel,'style','pushbutton', 'string', '>> Add to the list >>', 'position', [2*filterW yVideos+3*filterH-40 filterW-20 50], 'callback', @addVideos);
btnRemoveVideos = uicontrol('parent',mainPanel,'style','pushbutton', 'string', '<< Remove  <<', 'position', [2*filterW yVideos+3*filterH-100 filterW-20 50], 'callback', @removeVideos);

% ----------
% List of videos to process
% ----------
txtListVideosToProc = uicontrol('parent',mainPanel,'style','text', 'FontWeight', 'bold','HorizontalAlignment', 'left','String','Videos to process: (0 listed)','position',[3*filterW-20 yVideos+3*filterH+30 2*filterW 20]);
listVideosToProc =  uicontrol('parent',mainPanel,'style','listbox','String',{},'max',2,'min',0,'position',[3*filterW-20 yVideos 2*filterW 3*filterH]);
listVideosToProcIdx = [];
uicontrol('parent',mainPanel,'style','pushbutton', 'string', 'Select all', 'position', [3*filterW-20 yVideos+3*filterH filterW-10 30], 'callback', @(a,b) set(listVideosToProc, 'value', 1:length(get(listVideosToProc,'string'))))
uicontrol('parent',mainPanel,'style','pushbutton', 'string', 'Deselect all', 'position', [3*filterW-20+filterW+10 yVideos+3*filterH filterW-10 30], 'callback', @(a,b) set(listVideosToProc, 'value', []))
btnProcess = uicontrol('parent',mainPanel,'style','pushbutton', 'string', 'Process all the videos listed above', 'position', [3*filterW-20 yVideos-50 2*filterW 30], 'callback', @launchProcessing);
txtProcStatus = uicontrol('parent', mainPanel, 'style' ,'text', 'FontWeight', 'bold','HorizontalAlignment', 'left','String','Processing: stopped','position',[3*filterW-20 yVideos-370+280 2*filterW 20]);
txtProcTotal = uicontrol('parent', mainPanel, 'style' ,'text', 'FontWeight', 'bold','HorizontalAlignment', 'left','String','Videos processed: 0 / 0','position',[3*filterW-20 yVideos-370+260 2*filterW 20]);
uicontrol('parent', mainPanel, 'style' ,'text', 'FontWeight', 'bold','HorizontalAlignment', 'left','String','Current video:','position',[3*filterW-20 yVideos-370+240 filterW 20]);
txtProcCurrent = uicontrol('parent', mainPanel, 'style' ,'text', 'FontWeight', 'bold','HorizontalAlignment', 'left','String','< no video >','position',[3*filterW-20 yVideos-370+220 2*filterW 20]);
txtProcFrame = uicontrol('parent', mainPanel, 'style' ,'text', 'FontWeight', 'bold','HorizontalAlignment', 'left','String','Frames processed: 0 / 0','position',[3*filterW-20 yVideos-370+200 2*filterW 20]);


% ----------
% List of videos with no well
% ----------
listVideosWell = [];
txtListVideosNoWell = uicontrol('parent',mainPanel,'style','text', 'FontWeight', 'bold','HorizontalAlignment', 'left','String','No swim well defined: (0 remaining)','position',[5*filterW yVideos+3*filterH 2*filterW 20]);
listVideosNoWell =  uicontrol('parent',mainPanel,'style','listbox','String',{},'max',2,'min',0,'position',[5*filterW yVideos+2*filterH 2*filterW filterH], 'callback', @selectNoWell);
listVideosNoWellIdx = [];
% ----------
% List of videos with well
% ----------
txtListVideosWell = uicontrol('parent',mainPanel,'style','text', 'FontWeight', 'bold','HorizontalAlignment', 'left','String','Swim well defined: (0 found)','position',[7*filterW yVideos+3*filterH 2*filterW 20]);
listVideosWell =  uicontrol('parent',mainPanel,'style','listbox','String',{},'max',2,'min',0,'position',[7*filterW yVideos+2*filterH 2*filterW filterH], 'callback', @selectWell);
listVideosWellIdx = [];

% ------------
% Image
% ------------
uicontrol('parent',mainPanel,'style','text','HorizontalAlignment', 'left','String','Left click = add a point on the border of the well  --- Right click = remove the latest point','position',[5*filterW yVideos-30+2*filterH defaultImSize(1) 20]);
axesImage = axes('parent',mainPanel,'drawmode','fast','units','pixels','Position',[5*filterW yVideos-30+2*filterH-defaultImSize(2) defaultImSize(1) defaultImSize(2)],'XTick',[],'YTick',[]);
blankImage = zeros(defaultImSize(2), defaultImSize(1));
set(axesImage,'children',imagesc(blankImage),'visible','off');


% ============
% SHOW THE INTERFACE
% ============
populateFilters
set(mainFigure,'visible','on', 'WindowButtonDownFcn', @downMouse)
setMainPanelPositionBySliders
pause(0.1)
% ------------
% Waiting for closure
% ------------
waitfor(mainFigure,'BeingDeleted','on');




%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%            SUBFUNCTIONS
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    function closeWindow(hObject,eventdata)
        set(mainFigure,'Visible','off');
        delete(mainFigure);
    end



    function processSequence
        timings = zeros(1,length(timingsLabel));
        timingsTime = zeros(1,length(timingsLabel));
        currentFrameForProcessing = 1;
        set(txtProcFrame, 'string', ['Frames processed: ', num2str(currentFrameForProcessing), ' / ', num2str(totalFrames)]);
        %-----------------------
        % PROCESSING OF A SEQUENCE OF IMAGES
        %-----------------------
        % call for processing current image here
        if timingOn; tic; end
        
        imageFiles = dir(fullfile(fileDB(videoBeingProcessed).directory,['*.',fileDB(videoBeingProcessed).format]));
        % ----------------
        % Special case: when images have filenames with different lengths
        % (capture1 -> capture500), extract the number from the file name, use it to
        % sort the list of files, and re-order the files
        % ...............
        longueurs = arrayfun(@(c) length(c.name),imageFiles);
        if min(longueurs) < max(longueurs)
            nbOfElementsTmp = length(imageFiles);
            listOfNamesTmp = cell(1,nbOfElementsTmp);
            for n = 1:nbOfElementsTmp
                listOfNamesTmp{n} = imageFiles(n).name;
            end
            fctTmp = @(cellule) str2double(strrep(regexpi(cellule,'[0-9]*\.','match'),'.',''));
            results = cellfun(fctTmp,listOfNamesTmp);
            [valTmp, idxTmp] = sort(results); %#ok<ASGLU>
            for n=1:nbOfElementsTmp
                imageFiles(n).name = listOfNamesTmp{idxTmp(n)};
            end
        end
        % ...............
        currentImage = double(imread( fullfile( fileDB(videoBeingProcessed).directory, imageFiles(currentFrameForProcessing).name) ));
        if timingOn; timings(1) = timings(1) + toc ; timingsTime(1) = timingsTime(1) + 1 ; tic; end
        [imHeight, imWidth] = size(currentImage);
        if timingOn; tic; end
        % ===========
        % GET THE INSIDE BORDER OF THE CICRLE WHERE WORMS ARE SWIMMING
        % ===========
        if isempty(fileDB(videoBeingProcessed).well)
            % -----------
            % If not pre-defined, use the whole image as masks
            % -----------
            zoneOkForCompleteWorms = true(size(currentImage));
            zoneOkForStartingWorms = true(size(currentImage));
        else
            % -----------
            % If pre-defined, read it from the file entry
            % -----------
            if ischar(fileDB(videoBeingProcessed).well)
                fileDB(videoBeingProcessed).well = str2num(fileDB(videoBeingProcessed).well); %#ok<*ST2NM>
            end
            maxX = fileDB(videoBeingProcessed).well(1);
            maxY = fileDB(videoBeingProcessed).well(2);
            newRayon = fileDB(videoBeingProcessed).well(3);

            disp(['Process sequence: ', num2str(maxX), ' - ' , num2str(maxY), ' - ' , num2str(newRayon) ]);

            zoneOkForCompleteWorms = (  repmat((1-maxX:imWidth-maxX).^2,imHeight,1) + repmat((1-maxY:imHeight-maxY)'.^2, 1, imWidth) <= (newRayon - wellMarginSize).^2 );
            zoneOkForStartingWorms = (  repmat((1-maxX:imWidth-maxX).^2,imHeight,1) + repmat((1-maxY:imHeight-maxY)'.^2, 1, imWidth) <= (newRayon - wellMarginSize).^2 );
        end
        % -----------
        % Define the vertices at the edges of the well and the image
        % -----------
        zoneOkForCompleteWorms(1:imageMarginSize,:) = false;
        zoneOkForCompleteWorms(end-imageMarginSize+1:end,:) = false;
        zoneOkForCompleteWorms(:,1:imageMarginSize) = false;
        zoneOkForCompleteWorms(:,end-imageMarginSize+1:end) = false;
        % -----------
        % Define the vertices in the inner part of the well, where the gradient values will be reliable, and not affected by the values outside the ring
        % -----------
        zoneOkForStartingWorms(1:imageMarginSize,:) = false;
        zoneOkForStartingWorms(end-imageMarginSize+1:end,:) = false;
        zoneOkForStartingWorms(:,1:imageMarginSize) = false;
        zoneOkForStartingWorms(:,end-imageMarginSize+1:end) = false;
        if timingOn; timings(2) = timings(2) + toc ; timingsTime(2) = timingsTime(2) + 1 ; tic; end
        [fileDBEntry,listOfWormsEntry] = CSTSegmentImage(fileDB(videoBeingProcessed), imageFiles(currentFrameForProcessing).name, currentFrameForProcessing, axesImage);
        fileDB(videoBeingProcessed) = fileDBEntry;
        nbOfWormsFound = length(listOfWormsEntry.skel);
        nbOfFrames = length(imageFiles);
        listOfWorms.missed = false(nbOfWormsFound, nbOfFrames);
        listOfWorms.overlapped = false(nbOfWormsFound, nbOfFrames);
        listOfWorms.lost = false(nbOfWormsFound, nbOfFrames);
        listOfWorms.skel = cell(nbOfWormsFound,1);
        listOfWorms.width = cell(nbOfWormsFound,1);
        listOfWorms.localthreshold = cell(nbOfWormsFound, 1);
        listOfWorms.lengthWorms = zeros(nbOfWormsFound, nbOfFrames);
        for worm = 1:nbOfWormsFound
            listOfWorms.skel{worm} = cell(nbOfFrames,1);
            listOfWorms.width{worm} = cell(nbOfFrames,1);
            listOfWorms.skel{worm}{currentFrameForProcessing} = listOfWormsEntry.skel{worm};
            listOfWorms.width{worm}{currentFrameForProcessing} = listOfWormsEntry.width{worm};
            listOfWorms.localthreshold{worm} = listOfWormsEntry.localthreshold{worm};
            listOfWorms.lengthWorms(worm, currentFrameForProcessing) = listOfWormsEntry.lengthWorms(worm);
        end
        if timingOn; timings(6) = timings(6) + toc ; timingsTime(6) = timingsTime(6) + 1 ; tic; end
        for iter = 1:nbOfFrames-1
            pause(0.001)
            currentFrameForProcessing = currentFrameForProcessing + 1;
            set(txtProcFrame, 'string', ['Frames processed: ', num2str(currentFrameForProcessing), ' / ', num2str(totalFrames)]);
            if timingOn; tic; end
            currentImage = double(imread( fullfile( fileDB(videoBeingProcessed).directory, imageFiles(currentFrameForProcessing).name) ));
            if timingOn; timings(1) = timings(1) + toc ; timingsTime(1) = timingsTime(1) + 1 ; tic; end
            try
                if floor(iter/stepImagesAuto) == iter/stepImagesAuto
                    [fileDBEntry,listOfWormsEntry] = CSTSegmentImage(fileDB(videoBeingProcessed), imageFiles(currentFrameForProcessing).name, currentFrameForProcessing, axesImage);
                    CSTTrackWorms(fileDB(videoBeingProcessed), imageFiles(currentFrameForProcessing).name, currentFrameForProcessing, axesImage);
                    CSTMergeSegmAndTrack(fileDBEntry, listOfWormsEntry, imageFiles(currentFrameForProcessing).name, currentFrameForProcessing, axesImage, nbOfFrames);
                else
                    CSTTrackWorms(fileDB(videoBeingProcessed), imageFiles(currentFrameForProcessing).name, currentFrameForProcessing, axesImage);
                end
            catch em
                if flagRobustness
                    fprintf(fileToLog, ['***   There was an error tracking file number: ',num2str(currentFrameForProcessing),' , skipping this file. ***','\n']);
                    fprintf(fileToLog, [getReport(em, 'basic'),'\n']);
                else
                    rethrow(em)
                end
            end
        end
        fileDB(videoBeingProcessed).worms = length(listOfWorms.skel);
        fileDB(videoBeingProcessed).segmented = true;
        try
            CSTwriteSegmentationToTXT(listOfWorms, fileDB(videoBeingProcessed).name);
        catch em
            if flagRobustness
                try
                    fprintf(fileToLog, ['***   There was an error saving the xml results of sequence: ',fileDB(videoBeingProcessed).name,' ***','\n']);
                catch %#ok<CTCH>
                    fprintf(fileToLog, ['***   There was an error saving the xml results of sequence index: ',num2str(videoBeingProcessed),' ***','\n']);
                end
                fprintf(fileToLog, [getReport(em, 'basic'),'\n']);
            else
                rethrow(em)
            end
        end
        if traceOn; fprintf(fileToLog, ['end of processing sequence ', num2str(videoBeingProcessed),'\n']); end
        for tt = 1:length(timingsLabel)
            disp([timingsLabel{tt}, ' : ' , num2str(timings(tt)) , ' / ' , num2str( timingsTime(tt))]);
        end
    end


    function launchProcessing(hObject,eventdata)
        if ~isempty(listVideosToProcIdx)
            % if some videos have no well, ask for confirmation
            if ~isempty(get(listVideosNoWell, 'string'))
                button = questdlg('Some videos have no defined swim well. Processing them might take longer and be less reliable. Process all videos anyway?','CeleST','Process','Cancel','Cancel');
                if strcmp(button, 'Cancel')
                    return
                end
            end
            listToDisable = {btnAddVideos, btnRemoveVideos, btnClose, listVideosNoWell, listVideosWell, btnProcess};
            set(txtProcStatus, 'string', 'Processing: on-going');
            flagOkToDrawWell = false;
            for item = 1:length(listToDisable)
                set(listToDisable{item}, 'enable', 'off');
            end
            try
                for currentVideoIdx = 1:length(listVideosToProcIdx)
                    videoBeingProcessed = listVideosToProcIdx(currentVideoIdx);
                    set(txtProcTotal, 'string' , ['Videos processed: ',num2str(currentVideoIdx),' / ', num2str(length(listVideosToProcIdx))]);
                    % if already processed, move on
                    if ~fileDB(videoBeingProcessed).segmented
                        imageFiles = dir(fullfile(fileDB(videoBeingProcessed).directory,['*.',fileDB(videoBeingProcessed).format]));
                        totalFrames = length(imageFiles);
                        if ~isempty(totalFrames)
                            cla(axesImage);
                            currentImageForDisplay = imread( fullfile( fileDB(videoBeingProcessed).directory, imageFiles(1).name) );
                            imagesc(currentImageForDisplay,'parent', axesImage);
                            hold(axesImage, 'on');
                            if ~isempty(fileDB(videoBeingProcessed).well)
                                if ischar(fileDB(videoBeingProcessed).well)
                                    fileDB(videoBeingProcessed).well = str2num(fileDB(videoBeingProcessed).well); %#ok<*ST2NM>
                                end
                                omega(1) = fileDB(videoBeingProcessed).well(1);
                                omega(2) = fileDB(videoBeingProcessed).well(2);
                                radius = fileDB(videoBeingProcessed).well(3);
                                handleCircle = plot(axesImage, omega(1) + radius*cos(2*pi*(0:200)/200), omega(2) + radius*sin(2*pi*(0:200)/200), '-r', 'linewidth', 2);
                                pause(0.01)
                            end
                            set(axesImage,'XTick',[],'YTick',[]);
                            axis(axesImage, 'equal');
                            [yImage, xImage] = size(currentImageForDisplay);
                            axis(axesImage, [1,xImage, 1,yImage]);
                            set(txtProcCurrent, 'string', fileDB(videoBeingProcessed).name);
                            set(txtProcFrame, 'string', ['Frames processed: 0 / ', num2str(totalFrames)]);
                            pause(0.001)
                            disp(['Launch processing: ', num2str(omega(1)), ' - ' , num2str(omega(2)), ' - ' , num2str(radius) ]);
                            processSequence
                        end
                    end
                end
            catch em
                if flagRobustness
                    fprintf(fileToLog, ['***   There was an error during processing, stopping all processing. ***','\n']);
                    fprintf(fileToLog, [getReport(em, 'basic'),'\n']);
                else
                    rethrow(em)
                end
            end
            set(txtProcStatus, 'string', 'Processing: finished');
            for item = 1:length(listToDisable)
                set(listToDisable{item}, 'enable', 'on');
            end
        end
    end


    function selectNoWell(hObject, eventdata)
        tmp = get(listVideosNoWell, 'value');
        if isempty(get(listVideosNoWell,'string'))
            set(listVideosNoWell, 'value',[]);
        else
            set(listVideosNoWell, 'value', min(tmp(1),length(get(listVideosNoWell,'string'))));
        end
        set(listVideosWell,'value',[]);
        showVideo
    end

    function selectWell(hObject, eventdata)
        tmp = get(listVideosWell, 'value');
        if isempty(get(listVideosWell,'string'))
            set(listVideosWell, 'value',[]);
        else
            set(listVideosWell, 'value', min(tmp(1),length(get(listVideosWell,'string'))));
        end
        set(listVideosNoWell,'value',[]);
        showVideo
    end


    function showVideo(hObject, eventdata)
        cla(axesImage);
        if ~isempty(get(listVideosWell, 'value')) && ~isempty(get(listVideosWell,'string'))
            get(listVideosWell, 'value');
            idxVideo = listVideosWellIdx(get(listVideosWell, 'value'));
        elseif ~isempty(get(listVideosNoWell, 'value')) && ~isempty(get(listVideosNoWell,'string'))
            get(listVideosNoWell, 'value');
            idxVideo = listVideosNoWellIdx(get(listVideosNoWell, 'value'));
        else
            idxVideo = [];
        end
        flagOkToDrawWell = false;
        if ~isempty(idxVideo)
            imageFiles = dir(fullfile(fileDB(idxVideo).directory,['*.',fileDB(idxVideo).format]));
            if ~isempty(imageFiles)
                currentImageForDisplay = imread( fullfile( fileDB(idxVideo).directory, imageFiles(1).name) );
                imagesc(currentImageForDisplay,'parent', axesImage);
                flagOkToDrawWell = true;
                set(axesImage,'XTick',[],'YTick',[]);
                axis(axesImage, 'equal');
                [yImage, xImage] = size(currentImageForDisplay);
                axis(axesImage, [1,xImage, 1,yImage]);        
            else
                imagesc(blankImage,'parent', axesImage);            
            end
        else
            imagesc(blankImage,'parent', axesImage);
        end
        listOfPoints = [];
        hold(axesImage, 'on');
        if ~isempty(idxVideo) && ~isempty(fileDB(idxVideo).well)
            if ischar(fileDB(idxVideo).well)
                fileDB(idxVideo).well = str2num(fileDB(idxVideo).well); %#ok<*ST2NM>
            end
            omega(1) = fileDB(idxVideo).well(1);
            omega(2) = fileDB(idxVideo).well(2);
            radius = fileDB(idxVideo).well(3);
            handleCircle = plot(axesImage, omega(1) + radius*cos(2*pi*(0:200)/200), omega(2) + radius*sin(2*pi*(0:200)/200), '-r', 'linewidth', 2);
        end
    end


    % ------------
    % Mouse button down
    % ------------
    function downMouse(hObject,eventdata)
        if (get(get(mainFigure,'CurrentObject'), 'parent') == axesImage) && (~isempty(idxVideo)) && flagOkToDrawWell
            if strcmp(get(hObject,'SelectionType'),'normal')
                % ------------
                % left click: add a point
                % ------------
                newPoint = get(axesImage, 'CurrentPoint');
                listOfPoints(:,end+1) = [newPoint(1,1) ; newPoint(1,2)];
                handlesPoints(end+1) = plot(listOfPoints(1,:), listOfPoints(2,:), '*r');
                if size(listOfPoints,2) >= 3
                    [omega,radius] = getCenterFromManyPoints(listOfPoints);
                    omega = fix(omega);
                    radius = fix(radius);
                    if ~isempty(handleCircle) && ishandle(handleCircle)
                        delete(handleCircle);
                        handleCircle = [];
                    end
                    handleCircle = plot(omega(1) + radius*cos(2*pi*(0:200)/200), omega(2) + radius*sin(2*pi*(0:200)/200), '-r', 'linewidth', 2);
                    fileDB(idxVideo).well = [omega(1), omega(2), radius];
                    fileDB(idxVideo).mm_per_pixel = 5/fileDB(idxVideo).well(3);
                end
            else
                % ------------
                % right click: remove a point
                % ------------
                if ~isempty(listOfPoints)
                    listOfPoints(:,end) = [];
                    delete(handlesPoints(end));
                    handlesPoints(end) = [];
                    fileDB(idxVideo).well = [];
                    fileDB(idxVideo).mm_per_pixel = 1;
                    if ~isempty(handleCircle) && ishandle(handleCircle)
                        delete(handleCircle);
                        handleCircle = [];
                    end
                    if size(listOfPoints,2) >= 3
                        [omega,radius] = getCenterFromManyPoints(listOfPoints);
                        omega = fix(omega);
                        radius = fix(radius);
                        handleCircle = plot(omega(1) + radius*cos(2*pi*(0:200)/200), omega(2) + radius*sin(2*pi*(0:200)/200), '-r', 'linewidth', 2);
                        fileDB(idxVideo).well = [omega(1), omega(2), radius];
                        fileDB(idxVideo).mm_per_pixel = 5/fileDB(idxVideo).well(3);
                    else
                        
                    end
                end
            end
            if ~isempty(get(listVideosNoWell, 'value')) && ~isempty(fileDB(idxVideo).well)
                % now it has a well defined, swap it in the lists, keep it listed
                idxOldList = find(listVideosNoWellIdx == idxVideo);
                listVideosNoWellIdx(idxOldList) = [];
                namesNoWell = get(listVideosNoWell, 'string');
                namesNoWell(idxOldList) = [];
                set(listVideosNoWell, 'string', namesNoWell);
                set(listVideosNoWell, 'value',[]);
                set(listVideosWell, 'string', [get(listVideosWell, 'string') ; fileDB(idxVideo).name ]);
                set(listVideosWell, 'value',length(get(listVideosWell, 'string')));
                listVideosWellIdx = [listVideosWellIdx ; idxVideo];
            elseif ~isempty(get(listVideosWell, 'value')) && isempty(fileDB(idxVideo).well)
                % now it has a no well defined, swap it in the lists, keep it listed
                idxOldList = find(listVideosWellIdx == idxVideo);
                listVideosWellIdx(idxOldList) = [];
                namesWell = get(listVideosWell, 'string');
                namesWell(idxOldList) = [];
                set(listVideosWell, 'string', namesWell);
                set(listVideosWell, 'value',[]);
                set(listVideosNoWell, 'string', [get(listVideosNoWell, 'string') ; fileDB(idxVideo).name ]);
                set(listVideosNoWell, 'value',length(get(listVideosNoWell, 'string')));
                listVideosNoWellIdx = [listVideosNoWellIdx ; idxVideo];
            end
            set(txtListVideosToProc, 'string', ['Videos to process: (', num2str(length(get(listVideosToProc,'string'))),' listed)']);
            set(txtListVideosWell, 'string', ['Swim well defined: (', num2str(length(get(listVideosWell,'string'))),' found)']);
            set(txtListVideosNoWell, 'string', ['No swim well defined: (', num2str(length(get(listVideosNoWell,'string'))),' remaining)']);
        end
    end

    % -------------------
    % Compute the center of the circumscribed circle from three points
    % -------------------
    function omega = getCenterFrom3Points(p1, p2, p3)
        delta = ( p2(1)-p3(1) ) * ( p2(2)-p1(2) ) - ( p2(2)-p3(2) ) * ( p2(1)-p1(1) );
        len = ( p2(1)^2 + p2(2)^2 ) - ( p3(1)^2 + p3(2)^2 ) - ( p1(1)+p2(1) )*( p2(1)-p3(1) ) - ( p1(2)+p2(2) )*( p2(2)-p3(2) );
        lambda = len / delta;
        omega(1) = p1(1) + p2(1) +  lambda * ( p2(2) - p1(2) );
        omega(2) = p1(2) + p2(2) -  lambda * ( p2(1) - p1(1) );
        omega = omega / 2;
    end

    % -------------------
    % Compute the center and radius of the averaged circumscribed circle from more than three points
    % -------------------
    function [omega,radius] = getCenterFromManyPoints(p)
        nbPoints = size(p,2);
        omegaAll = zeros(2,nchoosek(nbPoints,3));
        radiiAll = zeros(1,nchoosek(nbPoints,3));
        it = 0;
        for firstPoint = 1:nbPoints-2
            p1 = p(:, firstPoint);
            for secondPoint = firstPoint+1:nbPoints-1
                p2 = p(:, secondPoint);
                for thirdPoint = secondPoint+1:nbPoints
                    p3 = p(:, thirdPoint);
                    it = it+1;
                    omegaAll(:,it) = getCenterFrom3Points(p1, p2, p3);
                    radiiAll(it) = realsqrt((omegaAll(1,it)-p1(1))^2 + (omegaAll(2,it)-p1(2))^2);
                end
            end
        end
        omega = mean(omegaAll,2);
        radius = mean(radiiAll);
    end

    function addVideos(hObject, eventdata)
        listOfFiltered = get(listVideosFiltered,'string');
        listOfSelection = get(listVideosFiltered,'value');
        previousSel = get(listVideosToProc,'string');
        for video = 1:length(listOfSelection)
            % check if it was selected before
            flagOkToAdd = true;
            for idxPrev = 1:length(previousSel)
                if strcmp(listOfFiltered{listOfSelection(video)}, previousSel{idxPrev})
                    flagOkToAdd = false;
                    break;
                end
            end
            if flagOkToAdd
                % Add to the list of videos to process
                tmp = get(listVideosToProc, 'string');
                if isempty(tmp) || isempty(tmp{1})
                    set(listVideosToProc, 'string',listOfFiltered(listOfSelection(video)));
                    listVideosToProcIdx = listVideosFilteredIdx(listOfSelection(video));
                else
                    set(listVideosToProc, 'string',[get(listVideosToProc, 'string'); listOfFiltered{listOfSelection(video)}]);
                    listVideosToProcIdx = [listVideosToProcIdx; listVideosFilteredIdx(listOfSelection(video))]; %#ok<AGROW>
                end
                % Check the definition of well, add to corresponding list
                if length(fileDB(listVideosFilteredIdx(listOfSelection(video))).well) >= 3 && fileDB(listVideosFilteredIdx(listOfSelection(video))).well(3) > 0
                    % add to the list with well
                    tmp = get(listVideosWell, 'string');
                    if isempty(tmp) || isempty(tmp{1})
                        set(listVideosWell, 'string',listOfFiltered(listOfSelection(video)));
                        listVideosWellIdx = listVideosFilteredIdx(listOfSelection(video));
                    else
                        set(listVideosWell, 'string',[get(listVideosWell, 'string'); listOfFiltered{listOfSelection(video)}]);
                        listVideosWellIdx = [listVideosWellIdx; listVideosFilteredIdx(listOfSelection(video))]; %#ok<AGROW>
                    end
                else
                    % add to the list with no well
                    tmp = get(listVideosNoWell, 'string');
                    if isempty(tmp) || isempty(tmp{1})
                        set(listVideosNoWell, 'string',listOfFiltered(listOfSelection(video)));
                        listVideosNoWellIdx = listVideosFilteredIdx(listOfSelection(video));
                    else
                        set(listVideosNoWell, 'string',[get(listVideosNoWell, 'string'); listOfFiltered{listOfSelection(video)}]);
                        listVideosNoWellIdx = [listVideosNoWellIdx; listVideosFilteredIdx(listOfSelection(video))]; %#ok<AGROW>
                    end
                end
            end
        end
        if ~isempty(get(listVideosWell, 'value'))
            selectWell
        elseif ~isempty(get(listVideosNoWell, 'value'))
            selectNoWell
        end
        set(txtListVideosToProc, 'string', ['Videos to process: (', num2str(length(get(listVideosToProc,'string'))),' listed)']);
        set(txtListVideosWell, 'string', ['Swim well defined: (', num2str(length(get(listVideosWell,'string'))),' found)']);
        set(txtListVideosNoWell, 'string', ['No swim well defined: (', num2str(length(get(listVideosNoWell,'string'))),' remaining)']);
    end

    function removeVideos(hObject, eventdata)
        listOfSelection = get(listVideosToProc,'value');
        listStrings = get(listVideosToProc, 'string');
        namesNoWell = get(listVideosNoWell, 'string');
        namesWell = get(listVideosWell, 'string');
        if ~isempty(listStrings) && ~isempty(listStrings{1}) && ~isempty(listOfSelection) && listOfSelection(1) ~= 0
            tmp = get(listVideosToProc, 'string');
            for video = length(listOfSelection):-1:1
                % Check the definition of well, remove from corresponding list
                if fileDB(listVideosToProcIdx(listOfSelection(video))).well
                    idx = find(listVideosWellIdx == listVideosToProcIdx(listOfSelection(video)));
                    namesWell(idx) = [];
                    listVideosWellIdx(idx) = [];
                else
                    idx = find(listVideosNoWellIdx == listVideosToProcIdx(listOfSelection(video)));
                    namesNoWell(idx) = [];
                    listVideosNoWellIdx(idx) = [];
                end
                tmp(listOfSelection(video)) = [];
                listVideosToProcIdx(listOfSelection(video)) = [];
            end
            set(listVideosNoWell, 'string',namesNoWell)
            set(listVideosWell, 'string',namesWell);
            set(listVideosToProc, 'string', tmp);
            set(listVideosToProc, 'value', 1);
        end
        if ~isempty(get(listVideosWell, 'value'))
            selectWell;
        elseif ~isempty(get(listVideosNoWell, 'value'))
            selectNoWell;
        end
        set(txtListVideosToProc, 'string', ['Videos to process: (', num2str(length(get(listVideosToProc,'string'))),' listed)']);
        set(txtListVideosWell, 'string', ['Swim well defined: (', num2str(length(get(listVideosWell,'string'))),' found)']);
        set(txtListVideosNoWell, 'string', ['No swim well defined: (', num2str(length(get(listVideosNoWell,'string'))),' remaining)']);
    end

    % ============
    % GET ALL THE DISTINCT VALUES TO DISPLAY IN EVERY FILTER LIST
    % ============
    function populateFilters
        listToShow = 1:length(fileDB);
        fields = fieldnames(flt);
        for field = 1:length(fields)
            setappdata(flt.(fields{field}),'field',fields{field});
            result = {};
            flagWell = strcmp('well',fields{field});
            for vid = listToShow
                if flagWell
                    value = num2str(~isempty(fileDB(vid).(fields{field})));
                elseif ~ischar(fileDB(vid).(fields{field}))
                    value = num2str(fileDB(vid).(fields{field}));
                else
                    value = fileDB(vid).(fields{field});
                end
                cand = length(result);
                while (cand >= 1) && ~strcmpi(value,result{cand})
                    cand = cand - 1;
                end
                if cand < 1
                    result{end+1} = value; %#ok<AGROW>
                end
            end
            result = [['All (',num2str(length(result)) ,' values)'], sort(result)];
            set(flt.(fields{field}),'string',result);
        end
        for field = 1:length(fields)
            if ~isfield(filterSelection, fields{field})
                filterSelection.(fields{field}) = 1;
            end
            set(flt.(fields{field}),'value', filterSelection.(fields{field}));
        end
        setFilteredList
    end

    % ============
    % BUILD THE LIST OF VIDEOS TO SHOW, BASED ON THE SELECTED FILTERS
    % ============
    function setFilteredList(hObject,eventdata) %#ok<*INUSD>
        result = cell(length(fileDB),1);
        currentVal = 0;
        listVideosFilteredIdx = zeros(1,length(fileDB));
        fields = fieldnames(flt);
        for field = 1:length(fields)
            filterSelection.(fields{field}) = get(flt.(fields{field}),'value');
        end
        for vv = 1:length(fileDB)
            flagKeep = true;
            for field = 1:length(fields)
                if (field == colFtlWell)
                    value = num2str(~isempty(fileDB(vv).(fields{field})));
                elseif ~ischar(fileDB(vv).(fields{field}))
                    value = num2str(fileDB(vv).(fields{field}));
                else
                    value = fileDB(vv).(fields{field});
                end
                options = get(flt.(fields{field}),'string');
                selIdx = get(flt.(fields{field}),'value');
                if length(selIdx) >= 1 && selIdx(1) == 1
                    continue;
                end
                
                selection = options(selIdx);
                cand = 1;
                while (cand <= length(selection)) && ~strcmpi(value, selection{cand})
                    cand = cand + 1;
                end
                if cand > length(selection)
                    flagKeep = false;
                    break
                end
            end
            if flagKeep
                currentVal = currentVal + 1;
                result{currentVal} = fileDB(vv).name;
                listVideosFilteredIdx(currentVal) = vv;
            end
        end
        listVideosFilteredIdx = listVideosFilteredIdx(1:currentVal);
        set(listVideosFiltered, 'string', result(1:currentVal,:), 'value',1);
        set(txtListVideosFiltered,'string', ['Videos to choose from: (',num2str(length(listVideosFilteredIdx)),' filtered)']);
    end

    % ============
    % DISPLAY THE AXIS AND THE SLIDER
    % ============

    % ------------
    % Set the position of the main panel based on the sliders values
    % ------------
    function setMainPanelPositionBySliders(hObject,eventdata) 
        newPos = get(mainPanel,'position');
        newPos(1) = 5 - get(sliderHoriz,'value');
        newPos(2) = -5 - get(sliderVert,'value');
        set(mainPanel,'position',newPos);
    end

    % ------------
    % Update the sliders positions when the main figure is resized
    % ------------
    function resizeMainFigure(hObject,eventdata) 
        % -------
        % Update the size and position of the sliders
        % -------
        newPosition = get(mainFigure,'position');
        set(sliderHoriz, 'position',[0 0 newPosition(3)-20 20]);
        set(sliderVert, 'position',[newPosition(3)-20 20 20 newPosition(4)-20]);
        % -------
        % Check the horizontal slider
        % -------
        if newPosition(3) < mainPanelPosition(3)
            deltaH = round(mainPanelPosition(3) - newPosition(3));
            newValue = min(deltaH,get(sliderHoriz,'value'));
            set(sliderHoriz, 'enable', 'on', 'min',0,'max',deltaH,'value',newValue);
        else
            set(sliderHoriz, 'enable', 'off','min',0,'max',1,'value',0);
        end
        % -------
        % Check the horizontal slider
        % -------
        if newPosition(4) < mainPanelPosition(4)
            deltaV = round(mainPanelPosition(4) - newPosition(4));
            newValue = min(deltaV,get(sliderVert,'value'));
            set(sliderVert, 'enable', 'on', 'min',0,'max',deltaV,'value',newValue);
        else
            set(sliderVert, 'enable', 'off','min',0,'max',1,'value',0);
        end
        setMainPanelPositionBySliders
    end


end
