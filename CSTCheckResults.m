function CSTCheckResults(videoIdxToLoad, wormIdxToLoad)
% Copyright (c) 2013 Rutgers
% Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
% The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
% THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.


global filenames fileDB colFtlWell mainPnlW mainPnlH filterSelection listOfWorms;

thresholdDistPixel = 4;
flagShowCurvaturePlots = false;
flagPlotCurvOnly = false;
totalWormsChecked = 0;
allMeasures = struct();
% ----------
% Variables storing the currently displayed video, frame, worm
% ----------
listOfWorms = cell(1,0);
nbOfWorms = 0;
nbOfFrames = 0;
imageFiles = [];
currentFrame = 1;
currentImage = [];
currentWorm = 0;
currentVideo = 0;
xImage = 0;
yImage = 0;
nbSamplesCBL = 24;
% ----------
% Measures to be computed
% ----------
measures.status = cell(1,0);
measures.highThr = [];
measures.lowThr = [];
measures.prevThr = [];
measures.highThrDef = [];
measures.lowThrDef = [];
measures.prevThrDef = [];
measures.usability = [];
centerMovedSignificantly = [];
% ----------
% Flag indicating that new glare zones have been defined
% ----------
flagNewZones = true;
% ----------
% Variables to switch worms
% ----------
valueStartFrame = 1;
valueEndFrame = 1;
idxOtherWorm = 1;
wormSwitchIdx =[];
% ----------
% Variables to define blocks and validity
% ----------
listOfWorms.manualInvalid = [];
listOfWorms.manualValid = [];
measures.manualSeparators = [];
measures.separators = [];
tmpAfterSelfOverlap = [];
% ============
% CREATE THE INTERFACE
% ============
% ----------
% Colors for display
% ----------
colorRejected = [0.8 0 0];
colorAccepted = [0.1 0.8 0.1];
colorTrajectory = [0.4 0.4 1];
colorThrash = [1 0.3 0.3];
% ----------
% Flag to display measures superimposed on the videos
% ----------
flagShowCBLSub = false;
flagShowTrajectory = false;
flagShowThrash = false;
% ----------
% Handles for the graphic objects to update for animation
% ----------
hLineHighThr = [];
hLineLowThr = [];
hLinePrevThr = [];
hRectCurrentFrame = [];
hSubImage = [];
hMainImage = [];
hMainAllWorms = [];
hMainTextWorms = [];
hMainBox = [];
hSubWorm = [];
displayAroundWorms = 10;
hTraj = [];
hGlareZones = cell(0);
hCBLSub = [];
hThrash = [];
% ----------
% Main figure and sliders
% ----------
scrsz = get(0,'ScreenSize');
mainW = min(mainPnlW, scrsz(3) - 10);
mainH = min(mainPnlH, scrsz(4) - 70);
mainPanelPosition = [2 , mainH-mainPnlH-2 , mainPnlW , mainPnlH];
mainFigure = figure('Visible','off','Position',[5,40,mainW,mainH],'Name','DURATION VALUES','numbertitle','off', 'menubar', 'none', 'resizefcn', @resizeMainFigure);
mainPanel = uipanel('parent', mainFigure,'BorderType', 'none','units','pixels', 'position', mainPanelPosition);
sliderHoriz = uicontrol('parent',mainFigure,'style','slider','position',[0 0 mainW-20 20],'max', 1,'min',0, 'value',0,'callback',@setMainPanelPositionBySliders);
sliderVert = uicontrol('parent',mainFigure,'style','slider','position',[mainW-20 20 20 mainH-20],'max', max(1,-mainPanelPosition(2)),'min',0, 'value',max(1,-mainPanelPosition(2)),'callback',@setMainPanelPositionBySliders);
set(mainFigure, 'color', get(mainPanel,'backgroundcolor'), 'keypressfcn', @keyboardShortcuts);
% ----------
% Filters
% ----------
filterH = 100;
filterW = 150;
hFilters = filterH + 20;
yFilters = mainPanelPosition(4) - hFilters - 5;
pnlFilters = uipanel('parent', mainPanel,'BorderType', 'none','units','pixels', 'position', [1 yFilters mainPnlW hFilters]);
listFilters = fieldnames(fileDB);
idxtmp = 1;
while idxtmp <= length(listFilters)
    if strcmp(listFilters{idxtmp},'name') || strcmp(listFilters{idxtmp},'directory') || strcmp(listFilters{idxtmp},'format')...
            || strcmp(listFilters{idxtmp},'frames_per_second') || strcmp(listFilters{idxtmp},'mm_per_pixel') || strcmp(listFilters{idxtmp},'set')...
            || strcmp(listFilters{idxtmp},'duration') || strcmp(listFilters{idxtmp},'images') || strcmp(listFilters{idxtmp},'glareZones')...
            || strcmp(listFilters{idxtmp},'note') || strcmp(listFilters{idxtmp},'worms') || strcmp(listFilters{idxtmp},'well')...
            || strcmp(listFilters{idxtmp},'month') || strcmp(listFilters{idxtmp},'day') || strcmp(listFilters{idxtmp},'year')
        listFilters(idxtmp) =[];
    else
        idxtmp = idxtmp + 1;
    end
end
for idxtmp = 0:length(listFilters)-1
    uicontrol('parent',pnlFilters,'style','text','string',listFilters{idxtmp+1},'position',[idxtmp*filterW filterH filterW 20])
    flt.(listFilters{idxtmp+1}) = uicontrol('parent',pnlFilters,'style','listbox','String',{''},'max',2,'min',0,'position',[idxtmp*filterW 0 filterW filterH],'callback',@setFilteredList);
end
% ----------
% List of videos
% ----------
txtListVideos = uicontrol('parent',mainPanel,'style','text','HorizontalAlignment', 'left','String','Select a video (0 filtered)','position',[0 yFilters-25 2*filterW 20]);
listVideos =  uicontrol('parent',mainPanel,'style','listbox','String',{''},'max',1,'min',0,'position',[0 yFilters-2*filterH-25 2*filterW 2*filterH],'callback', @checkSelectedVideo);
listVideosIdx = [];
uicontrol('parent', mainPanel, 'style', 'pushbutton', 'string', 'Close (not saving)','position', [0 yFilters-filterH-165 filterW 30],'callback', @closeWindow);

% ----------
% List of worms
% ----------
pnlLoad = uipanel('parent',mainPanel,'BorderType', 'none','units','pixels', 'position', [380-40 yFilters-filterH-185 2*filterW+120 270]);
btnLoad = uicontrol('parent',pnlLoad,'enable','off','style','pushbutton','string','Load the segmentation results', 'position', [0 240 2*filterW 30],'callback', @loadVideoContents);
txtVideoLoaded = uicontrol('parent',pnlLoad,'style','text','HorizontalAlignment', 'center','String','<no results loaded>','fontweight','bold','position',[0 210 2*filterW+100 20]);
listWorms =  uicontrol('parent',pnlLoad,'style','listbox','String',{''},'max',1,'min',0,'position',[0 70 filterW filterH],'callback', @selectWorm);
uicontrol('parent',pnlLoad,'style','pushbutton','string','Validate', 'position', [0 40 75 30],'callback', @validateWorm);
uicontrol('parent',pnlLoad,'style','pushbutton','string','Reject', 'position', [75 40 75 30],'callback', @rejectWorm);
uicontrol('parent', pnlLoad, 'style', 'pushbutton', 'string', 'Save and Compute measures','position', [0 0 2*filterW 30],'callback', @updateMeasureForCurrentVideo);


uicontrol('parent', pnlLoad, 'style', 'pushbutton', 'string', 'Glare zones','position', [180 180 120 20],'callback', @manageGlareZones);
% ----------
% Switch trajectories
% ----------
pnlSwitch = uipanel('parent',pnlLoad,'BorderType', 'none','units','pixels', 'position', [180 70 120 filterH]);
uicontrol('parent',pnlSwitch,'style','text','HorizontalAlignment', 'left','String','From frame','position',[0 80 80 20]);
editFrameCutStart = uicontrol('parent',pnlSwitch,'style','edit','string','1','position',[70 80 50 25]);
uicontrol('parent',pnlSwitch,'style','text','HorizontalAlignment', 'left','String','to frame','position',[0 60 80 20]);
editFrameCutEnd = uicontrol('parent',pnlSwitch,'style','edit','string','1','position',[70 60 50 25]);
uicontrol('parent',pnlSwitch,'style','text','HorizontalAlignment', 'left','String','switch ','position',[0 40 50 20]);
txtSelectedWorm = uicontrol('parent',pnlSwitch,'style','text','String','< n/a >','position',[45 40 60 20]);
uicontrol('parent',pnlSwitch,'style','text','HorizontalAlignment', 'left','String','and','position',[0 20 40 20]);
popWormSwitch = uicontrol('parent',pnlSwitch,'style','popupmenu','String',{'< n/a >'},'value',idxOtherWorm,'position',[25 20 100 20],'callback',@setWormSwitch);
uicontrol('parent',pnlSwitch,'style','pushbutton','String','Switch','position',[0 0 120 20],'callback', @switchWorms);
% ----------
% Switch head and tail
% ----------
pnlSwitchHeadTail = uipanel('parent',mainPanel,'BorderType', 'none','units','pixels', 'position', [380 yFilters-filterH-240 2*filterW 50]);
uicontrol('parent',pnlSwitchHeadTail,'style','text','HorizontalAlignment', 'left','String','From ','position',[0 0 40 20]);
editFrameSwitchHTStart = uicontrol('parent',pnlSwitchHeadTail,'style','edit','string','1','position',[40 0 50 25]);
uicontrol('parent',pnlSwitchHeadTail,'style','text','HorizontalAlignment', 'left','String','to ','position',[90 00 20 20]);
editFrameSwitchHTEnd = uicontrol('parent',pnlSwitchHeadTail,'style','edit','string','544','position',[110 0 50 25]);
uicontrol('parent',pnlSwitchHeadTail,'style','pushbutton','String','Switch H / T','position',[160 0 120 25],'callback', @switchHeadTail);
% ----------
% Video of all field
% ----------
hAxeAllVideo = axes('parent', mainPanel, 'units','pixels','position',[4*filterW+560 yFilters-filterH-235 500 320],'xtick',[],'ytick',[],'color',[.5 .5 .5]);
axis('image','ij')
% ----------
% Video of selected worm
% ----------
hAxeCurrentWorm = axes('parent', mainPanel, 'units','pixels','position',[4*filterW+120 yFilters-filterH-190 410 275],'xtick',[],'ytick',[],'color',[.5 .5 .5]);
axis('image','ij')
% ----------
% Navigation through the frames
% ----------
pnlNavigate = uipanel('parent',mainPanel,'BorderType', 'none','units','pixels', 'position', [4*filterW+100 yFilters-335 450 35]);
uicontrol('parent',pnlNavigate,'style','text','HorizontalAlignment', 'left','string','1','position',[5 6 10 20]);
btnFirstFrame = uicontrol('parent',pnlNavigate,'style','pushbutton','string','<<<','position',[15 0 40 35],'callback',@selectFrameByClick);
editStartFrame = uicontrol('parent',pnlNavigate,'style','edit','string','-','position',[55 0 40 35],'callback',@selectFrameByClick);
btnRewindFrame = uicontrol('parent',pnlNavigate,'style','pushbutton','string','<<','position',[95 0 40 35],'callback',@selectFrameByClick);
btnPrevFrame = uicontrol('parent',pnlNavigate,'style','pushbutton','string','<','position',[135 0 40 35],'callback',@selectFrameByClick);
editCurrentFrame = uicontrol('parent',pnlNavigate,'style','edit','string','-','position',[175 0 40 35],'callback',@selectFrameByClick);
btnNextFrame = uicontrol('parent',pnlNavigate,'style','pushbutton','string','>','position',[275 0 40 35],'callback',@selectFrameByClick);
btnForwardFrame = uicontrol('parent',pnlNavigate,'style','pushbutton','string','>>','position',[315 0 40 35],'callback',@selectFrameByClick);
editEndFrame = uicontrol('parent',pnlNavigate,'style','edit','string','-','position',[355 0 40 35],'callback',@selectFrameByClick);
btnLastFrame = uicontrol('parent',pnlNavigate,'style','pushbutton','string','>>>','position',[395 0 40 35],'callback',@selectFrameByClick);
txtMaxFrame = uicontrol('parent',pnlNavigate,'style','text','HorizontalAlignment', 'left','string','-','position',[435 6 40 20]);
btnPlayVideo = uicontrol('parent',pnlNavigate,'style','togglebutton','string','Play','position',[215 0 60 35],'callback',@playPauseVideo);
% ----------
% Panel for validity
% ----------
% Make the axes directly children of mainPanel, otherwise they are not properly placed when the window is scrolled or resized
% ----------
pnlValidity = uipanel('parent',mainPanel,'BorderType', 'none','units','pixels', 'position', [1 480 3*544+25 80]);
hAxeValid = axes('parent', mainPanel, 'units','pixels','position',[25+1 20+480 3*544 30],'xtick',[],'ytick',[],'color',[.5 .5 .5],'ButtonDownFcn', @selectFrameByClick);
uicontrol('parent',pnlValidity,'style','text','HorizontalAlignment', 'left','string','Validity of the segmented body: ','position',[25 55 200 20]);
txtValid = uicontrol('parent',pnlValidity,'style','text','HorizontalAlignment', 'left','string','Valid frames: - / - = - %','position',[225 55 220 20], 'foregroundcolor', [0.1 0.5 0.1]);
txtReject = uicontrol('parent',pnlValidity,'style','text','HorizontalAlignment', 'left','string','Rejected frames: - / - = - %','position',[445 55 230 20], 'foregroundcolor' , [0.7 0 0]);
uicontrol('parent',pnlValidity,'style','pushbutton','string','Next block','position',[875 52 100 35],'callback',@selectNextBlock);
uicontrol('parent',pnlValidity,'style','pushbutton','string','Switch validity (right click)','position',[1015 52 190 35],'callback',@switchValidity);
uicontrol('parent',pnlValidity,'style','pushbutton','string','Split block (double click)','position',[1215 52 190 35],'callback',@splitBlock);
uicontrol('parent',pnlValidity,'style','pushbutton','string','Isolate frame (triple click)','position',[1415 52 190 35],'callback',@isolateFrame);
% ----------
% Panel for glare zones
% ----------
pnlGlase = uipanel('parent',mainPanel,'BorderType', 'none','units','pixels', 'position', [1 430 3*544+25 50]);
hAxeGlare = axes('parent', mainPanel, 'units','pixels','position',[25+1 20+430 3*544 20],'xtick',[],'ytick',[],'color',[.5 .5 .5],'ButtonDownFcn', @selectFrameByClick);
uicontrol('parent',pnlGlase,'style','text','HorizontalAlignment', 'left','string','Within glare zones: ','position',[25 42 200 20]);
% ----------
% Panel for lost
% ----------
pnlLost = uipanel('parent',mainPanel,'BorderType', 'none','units','pixels', 'position', [1 380 3*544+25 50]);
hAxeLost = axes('parent', mainPanel, 'units','pixels','position',[25+1 20+380 3*544 20],'xtick',[],'ytick',[],'color',[.5 .5 .5],'ButtonDownFcn', @selectFrameByClick);
uicontrol('parent',pnlLost,'style','text','HorizontalAlignment', 'left','string','Lost during tracking: ','position',[25 42 200 20]);
% ----------
% Panel for overlap
% ----------
pnlOverlap = uipanel('parent',mainPanel,'BorderType', 'none','units','pixels', 'position', [1 330 3*544+25 50]);
hAxeOverlap = axes('parent', mainPanel, 'units','pixels','position',[25+1 20+330 3*544 20],'xtick',[],'ytick',[],'color',[.5 .5 .5],'ButtonDownFcn', @selectFrameByClick);
uicontrol('parent',pnlOverlap,'style','text','HorizontalAlignment', 'left','string','Overlap with other worm: ','position',[25 42 200 20]);
% ----------
% Panel for self-overlap
% ----------
pnlSelfOverlap = uipanel('parent',mainPanel,'BorderType', 'none','units','pixels', 'position', [1 280 3*544+25 50]);
hAxeSelfOverlap = axes('parent', mainPanel, 'units','pixels','position',[25+1 20+280 3*544 20],'xtick',[],'ytick',[],'color',[.5 .5 .5],'ButtonDownFcn', @selectFrameByClick);
uicontrol('parent',pnlSelfOverlap,'style','text','HorizontalAlignment', 'left','string','End of self-overlap: ','position',[25 42 200 20]);
% ----------
% Panel for prev overlap
% ----------
pnlPrevOverlap = uipanel('parent',mainPanel,'BorderType', 'none','units','pixels', 'position', [1 180 3*544+25 90]);
hAxePrevOverlap = axes('parent', mainPanel, 'units','pixels','position',[25+1 20+180 3*544 60],'xtick',[],'ytick',[],'color',[.5 .5 .5],'ButtonDownFcn', @selectFrameByClick);
uicontrol('parent',pnlPrevOverlap,'style','text','HorizontalAlignment', 'left','string','Self-overlap with previous frame (in %): ','position',[25 82 250 20]);
uicontrol('parent',pnlPrevOverlap,'style','text','HorizontalAlignment', 'right','string','Threshold: ','position',[275 82 90 20]);
btnPrevThrUp = uicontrol('parent',pnlPrevOverlap,'style','pushbutton','string','^','position',[365 82 40 25],'callback',@selectThreshold);
editPrevThr = uicontrol('parent',pnlPrevOverlap,'style','edit','string','25','position',[405 82 45 25],'callback',@selectThreshold);
btnPrevThrDown = uicontrol('parent',pnlPrevOverlap,'style','pushbutton','string','v','position',[450 82 40 25],'callback',@selectThreshold);
btnPrevThrDefault = uicontrol('parent',pnlPrevOverlap,'style','pushbutton','string','X','position',[490 82 40 25],'callback',@selectThreshold);
% ----------
% Panel for body length
% ----------
pnlBodyLength = uipanel('parent',mainPanel,'BorderType', 'none','units','pixels', 'position', [1 50 3*544+25 120]);
hAxeLength = axes('parent', mainPanel, 'units','pixels','position',[25+1 20+50 3*544 60],'xtick',[],'ytick',[],'color',[.5 .5 .5],'ButtonDownFcn', @selectFrameByClick);
uicontrol('parent',pnlBodyLength,'style','text','HorizontalAlignment', 'left','string','Length of the segmented body: ','position',[25 80 200 20]);
uicontrol('parent',pnlBodyLength,'style','text','HorizontalAlignment', 'right','string','High threshold: ','position',[225 106 140 20]);
btnHighThrUp = uicontrol('parent',pnlBodyLength,'style','pushbutton','string','^','position',[365 106 40 25],'callback',@selectThreshold);
editHighThr = uicontrol('parent',pnlBodyLength,'style','edit','string','0','position',[405 106 45 25],'callback',@selectThreshold);
btnHighThrDown = uicontrol('parent',pnlBodyLength,'style','pushbutton','string','v','position',[450 106 40 25],'callback',@selectThreshold);
btnHighThrDefault = uicontrol('parent',pnlBodyLength,'style','pushbutton','string','X','position',[490 106 40 25],'callback',@selectThreshold);
uicontrol('parent',pnlBodyLength,'style','text','HorizontalAlignment', 'right','string','Low threshold: ','position',[225 82 140 20]);
btnLowThrUp = uicontrol('parent',pnlBodyLength,'style','pushbutton','string','^','position',[365 82 40 25],'callback',@selectThreshold);
editLowThr = uicontrol('parent',pnlBodyLength,'style','edit','string','0','position',[405 82 45 25],'callback',@selectThreshold);
btnLowThrDown = uicontrol('parent',pnlBodyLength,'style','pushbutton','string','v','position',[450 82 40 25],'callback',@selectThreshold);
btnLowThrDefault = uicontrol('parent',pnlBodyLength,'style','pushbutton','string','X','position',[490 82 40 25],'callback',@selectThreshold);
% ============
% SHOW THE INTERFACE
% ============
populateFilters
set(mainFigure,'visible','on')
setMainPanelPositionBySliders
pause(0.1)



if flagShowCurvaturePlots
    hPlots = figure('Position',[5,40,mainW,mainH]);
    if flagPlotCurvOnly
        hOnlyCurv = figure('Position',[5,600,mainW,250]);
    end
end
% ------------
% Case where this function was called from the visualization GUI, and needs to load a specific video and worm
% ------------
if nargin >= 2
    loadVideoContents
    set(listWorms, 'value', wormIdxToLoad);
    selectWorm
end

flagRemoveTempMeasures = true;
% ------------
% Waiting for closure
% ------------
waitfor(mainFigure,'BeingDeleted','on');

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%            SUBFUNCTIONS
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    function switchHeadTail(hObject, eventdata)
        for ff = max(1,min(nbOfFrames, floor(str2double(get(editFrameSwitchHTStart, 'string'))))):max(1,min(nbOfFrames, floor(str2double(get(editFrameSwitchHTEnd, 'string')))))
            listOfWorms.skel{currentWorm}{ff} = listOfWorms.skel{currentWorm}{ff}(:,end:-1:1);
            listOfWorms.width{currentWorm}{ff} = listOfWorms.width{currentWorm}{ff}(end:-1:1);
        end
        selectWorm;
        CSTwriteSegmentationToTXT(listOfWorms, fileDB(currentVideo).name);
    end

    function updateMeasureForCurrentVideo(hObject, eventdata)
        hTmp = waitbar(0,'Saving the results...');
        pause(0.001)
        finalNames = {'Wave_Initiation_Rate_Median', 'Wave_Initiation_Rate_Range', 'Body_Wave_Number_Median', 'Body_Wave_Number_Range', 'Asymmetry_Median', 'Asymmetry_Range', 'Reverse_Swimming', ...
            'Curling', 'Stretch_Median', 'Stretch_Range', 'Attenuation_Median', 'Attenuation_Range', 'Traveling_Speed_Mean', 'Brush_Stroke_Median', 'Brush_Stroke_Range', 'Activity_Index_Median', 'Activity_Index_Range'...
            , 'Wave_Initiation_Rate_10' 'Body_Wave_Number_10', 'Asymmetry_10', 'Stretch_10', 'Attenuation_10', 'Brush_Stroke_10', 'Activity_Index_10'...
            };
        for measureIdx = 1:length(finalNames)
            allMeasures.(finalNames{measureIdx}) = NaN(1,nbOfWorms);
        end
        finalNamesAllValues = {'Wave_Initiation_Rate_All', 'Body_Wave_Number_All', 'Asymmetry_All', 'Reverse_Swimming_All', ...
            'Curling_All', 'Stretch_All', 'Attenuation_All', 'Traveling_Speed_All', 'Brush_Stroke_All', 'Activity_Index_All'...
            };
        for measureIdx = 1:length(finalNamesAllValues)
            allMeasures.(finalNamesAllValues{measureIdx}) = zeros(nbOfWorms,2*nbOfFrames);
        end
        allMeasures.('Curling_All') = NaN(nbOfWorms, nbOfFrames);
        allMeasures.usability = NaN(1,nbOfWorms);
        negativeThreshold = -1;
        oldNames = {'status', 'highThr', 'lowThr', 'prevThr', 'highThrDef', 'lowThrDef', 'prevThrDef', 'usability', 'manualSeparators', 'separators'};
        for oldIdx = 1:length(oldNames)
            allMeasures.(oldNames{oldIdx}) = measures.(oldNames{oldIdx});
        end
        totWorms = 0;
        for wormToMeasure = 1:nbOfWorms
            waitbar(wormToMeasure/nbOfWorms,hTmp);
            if strcmp(measures.status{wormToMeasure}, 'rejected')
                continue
            end
            totWorms = totWorms + 1;
            %-----------------
            % Usability
            %-----------------
            allMeasures.usability(wormToMeasure) = mean(listOfWorms.valid(wormToMeasure, :));
            %-----------------
            % Curvature
            %-----------------
            flagSmoothCurvature = true;
            flagSuperSampleCurvature = true;
            [ temporalFreq , spatialFreq , dynamicAmplitude , attenuation , curvature ] = CSTComputeMeasuresFromBody(listOfWorms.skel{wormToMeasure}, flagSmoothCurvature, flagSuperSampleCurvature, listOfWorms.valid(wormToMeasure,:));
            rangeUsable = ~isnan(temporalFreq);
            if isempty(rangeUsable)
                return
            end
            %-----------------
            % Wave Initiation Rate
            %-----------------
            allMeasures.('Wave_Initiation_Rate_All')(wormToMeasure,rangeUsable)  = fileDB(currentVideo).frames_per_second * 60 * temporalFreq(rangeUsable);
            allMeasures.('Wave_Initiation_Rate_Median')(wormToMeasure)  = fileDB(currentVideo).frames_per_second * 60 * median(temporalFreq(rangeUsable));
            allMeasures.('Wave_Initiation_Rate_Range')(wormToMeasure)   = fileDB(currentVideo).frames_per_second * 60 * ( prctile(temporalFreq(rangeUsable),90) - prctile(temporalFreq(rangeUsable),10) );
            allMeasures.('Wave_Initiation_Rate_10')(wormToMeasure)   = fileDB(currentVideo).frames_per_second * 60 * prctile(temporalFreq(rangeUsable),10);
            %-----------------
            % Body Wave Number
            %-----------------
            allMeasures.('Body_Wave_Number_All')(wormToMeasure,rangeUsable)  = spatialFreq(rangeUsable);
            allMeasures.('Body_Wave_Number_Median')(wormToMeasure)  = median(abs(spatialFreq(rangeUsable)));
            allMeasures.('Body_Wave_Number_Range')(wormToMeasure)   = ( prctile(abs(spatialFreq(rangeUsable)),90) - prctile(abs(spatialFreq(rangeUsable)),10) );
            allMeasures.('Body_Wave_Number_10')(wormToMeasure)   = prctile(abs(spatialFreq(rangeUsable)),10);
            %-----------------
            % Symmetry / Lateral preference
            %-----------------
            totalCurvature = mean(curvature(:,3:end),2);
            averCurvature = zeros(1,length(totalCurvature));
            for ff = 1:length(totalCurvature)
                if temporalFreq(ff) > 0
                    period = max(3,min(50,fix(1/temporalFreq(ff))));
                else
                    period = 50;
                end
                timeRange = max(1, min(length(totalCurvature), ff-period)):max(1, min(length(totalCurvature), ff+period));
                averCurvature(ff) = mean(totalCurvature(timeRange));
            end
            rangeUsable2 = ~isnan(averCurvature(:) .* totalCurvature(:));
            tmpAverCurvature = averCurvature(rangeUsable2);
            allMeasures.('Asymmetry_All')(wormToMeasure,rangeUsable2)  = tmpAverCurvature;
            allMeasures.('Asymmetry_Median')(wormToMeasure)  = median(tmpAverCurvature);
            allMeasures.('Asymmetry_Range')(wormToMeasure)   = ( prctile(tmpAverCurvature,90) - prctile(tmpAverCurvature,10) );
            allMeasures.('Asymmetry_10')(wormToMeasure)   = prctile(tmpAverCurvature,10);
            %-----------------
            % Reverse Swimming
            %-----------------
            framesInReverse = sum(spatialFreq(rangeUsable) < negativeThreshold);
            allFrames = numel(spatialFreq(rangeUsable));
            allMeasures.('Reverse_Swimming')(wormToMeasure) = framesInReverse / allFrames;
            %-----------------
            % Curling
            %-----------------
            usableFrames = 0;
            for ff = 1:nbOfFrames
                if listOfWorms.valid(wormToMeasure, ff)
                    usableFrames = usableFrames + 1;
                    % distance head to lower-body
                    idxHd = 1;
                    idxTail = size(listOfWorms.skel{wormToMeasure}{ff}, 2);
                    idxMid = round(idxTail / 2);
                    xx = listOfWorms.skel{wormToMeasure}{ff}(1,:);
                    yy = listOfWorms.skel{wormToMeasure}{ff}(2,:);
                    minDistHead = min(hypot(xx(idxHd) - xx(idxMid:idxTail), yy(idxHd) - yy(idxMid:idxTail)));
                    minDistTail = min(hypot(xx(idxTail) - xx(idxHd:idxMid), yy(idxTail) - yy(idxHd:idxMid)));
                    allMeasures.('Curling_All')(wormToMeasure, ff) = min(minDistHead, minDistTail);
                end
            end
            allMeasures.('Curling')(wormToMeasure) = sum( allMeasures.('Curling_All')(wormToMeasure, :) <= thresholdDistPixel ) / usableFrames * 60; % in seconds(of curling) per minute(of swimming)
            %-----------------
            % Stretch
            %-----------------
            allMeasures.('Stretch_All')(wormToMeasure,rangeUsable)  = dynamicAmplitude(rangeUsable);
            allMeasures.('Stretch_Median')(wormToMeasure)  = median(dynamicAmplitude(rangeUsable));
            allMeasures.('Stretch_Range')(wormToMeasure)   = ( prctile(dynamicAmplitude(rangeUsable) ,90) - prctile(dynamicAmplitude(rangeUsable) ,10) );
            allMeasures.('Stretch_10')(wormToMeasure)   = prctile(dynamicAmplitude(rangeUsable) ,10);
            %-----------------
            % Attenuation
            %-----------------
            allMeasures.('Attenuation_All')(wormToMeasure,rangeUsable)  = 100 * attenuation(rangeUsable);
            allMeasures.('Attenuation_Median')(wormToMeasure)  = 100 * median(attenuation(rangeUsable));
            allMeasures.('Attenuation_Range')(wormToMeasure)   = 100 * ( prctile(attenuation(rangeUsable) ,90) - prctile(attenuation(rangeUsable) ,10) );
            allMeasures.('Attenuation_10')(wormToMeasure)   = 100 * prctile(attenuation(rangeUsable) ,10);
            %-----------------
            % Travel speed
            %-----------------
            deltas = zeros(1,nbOfFrames);
            positionCenterX = zeros(1,nbOfFrames);
            positionCenterY = zeros(1,nbOfFrames);
            ff0 = 1;
            if temporalFreq(ff0) > 0
                period = max(3,min(50,fix(1/temporalFreq(ff0))));
            else
                period = 50;
            end
            timeWindowForSweptAreas = period;
            while ff0 + timeWindowForSweptAreas < nbOfFrames
                % -----------
                % find the next frame with a complete usable range
                % -----------
                while (ff0 + timeWindowForSweptAreas <= nbOfFrames) && any( ~ listOfWorms.valid(wormToMeasure, ff0 + (0:timeWindowForSweptAreas)))
                    ff0 = ff0 + 1;
                end
                if temporalFreq(ff0) > 0
                    period = max(3,min(50,fix(1/temporalFreq(ff0))));
                else
                    period = 50;
                end
                timeWindowForSweptAreas = period;
                if ff0 + timeWindowForSweptAreas <= nbOfFrames
                    % -----------
                    % Initialize mask
                    % -----------
                    totalUsed = 0;
                    for ff = ff0 + (0:timeWindowForSweptAreas)
                        if listOfWorms.valid(wormToMeasure, ff)
                            totalUsed = totalUsed + 1;
                            totalWidth = sum(listOfWorms.width{wormToMeasure}{ff}(:));
                            positionCenterX(ff0) = positionCenterX(ff0) + sum(listOfWorms.width{wormToMeasure}{ff}(:)' .* listOfWorms.skel{wormToMeasure}{ff}(1,:)) / totalWidth;
                            positionCenterY(ff0) = positionCenterY(ff0) + sum(listOfWorms.width{wormToMeasure}{ff}(:)' .* listOfWorms.skel{wormToMeasure}{ff}(2,:)) / totalWidth;
                        end
                    end
                    positionCenterX(ff0) = positionCenterX(ff0) / totalUsed;
                    positionCenterY(ff0) = positionCenterY(ff0) / totalUsed;
                    if (ff0 > 1) && (positionCenterX(ff0-1) > 0) && (positionCenterY(ff0-1) > 0) && positionCenterX(ff0) >0 && positionCenterY(ff0) >0
                        deltas(ff0) = hypot(positionCenterX(ff0)-positionCenterX(ff0-1), positionCenterY(ff0)-positionCenterY(ff0-1));
                    end
                end
                ff0 = ff0 + 1;
                % -----------
                % finished
                % -----------
            end
            listOfWorms.positionCenterX(wormToMeasure,:) = positionCenterX;
            listOfWorms.positionCenterY(wormToMeasure,:) = positionCenterY;
            % mm / min
            tmpFramesUsed = length(deltas) - length(find(isnan(deltas)));
            rangeUsableDist = ~isnan(deltas);
            tmpDistanceTraveled = sum(deltas(rangeUsableDist));
            allMeasures.('Traveling_Speed_All')(wormToMeasure, rangeUsableDist) = cumsum(deltas(rangeUsableDist)) * fileDB(currentVideo). mm_per_pixel;
            allMeasures.('Traveling_Speed_Mean')(wormToMeasure) = tmpDistanceTraveled / tmpFramesUsed * fileDB(currentVideo). mm_per_pixel * fileDB(currentVideo).frames_per_second * 60;
            %-----------------
            % Sweeping speed
            %-----------------
            maskAreaCovered = zeros(yImage, xImage);
            averageWormBodyMask = zeros(yImage, xImage);
            areaCoveredNorm = zeros(1,nbOfFrames);
            sweeping_noTimeNorm = zeros(1, nbOfFrames);
            ff0 = 1;
            if temporalFreq(ff0) > 0
                period = max(3,min(50,fix(1/temporalFreq(ff0))));
            else
                period = 50;
            end
            timeWindowForSweptAreas = period;
            while ff0 + timeWindowForSweptAreas < nbOfFrames
                % -----------
                % find the next frame with a complete usable range
                % -----------
                while (ff0 + timeWindowForSweptAreas < nbOfFrames) && any( ~ listOfWorms.valid(wormToMeasure, ff0 + (0:timeWindowForSweptAreas)))
                    ff0 = ff0 + 1;
                end
                if temporalFreq(ff0) > 0
                    period = max(3,min(50,fix(1/temporalFreq(ff0))));
                else
                    period = 50;
                end
                timeWindowForSweptAreas = min(period, nbOfFrames - ff0);
                if ff0 + timeWindowForSweptAreas <= nbOfFrames
                    % -----------
                    % Initialize mask
                    % -----------
                    maskAreaCovered(:) = 0;
                    averageWormBodyArea = 0;
                    for ff = ff0 + (0:timeWindowForSweptAreas)
                        averageWormBodyMask(:) = 0;
                        for vv = 1:length(listOfWorms.width{wormToMeasure}{ff})
                            rr = max(1, min(yImage, round(listOfWorms.skel{wormToMeasure}{ff}(2,vv)-listOfWorms.width{wormToMeasure}{ff}(vv)):round(listOfWorms.skel{wormToMeasure}{ff}(2,vv)+listOfWorms.width{wormToMeasure}{ff}(vv))));
                            cc = max(1, min(xImage, round(listOfWorms.skel{wormToMeasure}{ff}(1,vv)-listOfWorms.width{wormToMeasure}{ff}(vv)):round(listOfWorms.skel{wormToMeasure}{ff}(1,vv)+listOfWorms.width{wormToMeasure}{ff}(vv))));
                            averageWormBodyMask(rr,cc) = 1 + averageWormBodyMask(rr,cc);
                            maskAreaCovered(rr,cc) = 1 + maskAreaCovered(rr,cc);
                        end
                        averageWormBodyArea = averageWormBodyArea + sum(averageWormBodyMask(:) > 0);
                    end
                    areaCoveredNorm(ff0) = sum(maskAreaCovered(:) > 0) / (averageWormBodyArea / (1+timeWindowForSweptAreas));
                    % -----------
                    % move to the next frame
                    % -----------
                    ff0 = ff0 + 1;
                    while (ff0 + timeWindowForSweptAreas < nbOfFrames) && listOfWorms.valid(wormToMeasure, ff0+timeWindowForSweptAreas)
                        % -----------
                        % remove previous frame
                        % -----------
                        ff = ff0 - 1;
                        averageWormBodyMask(:) = 0;
                        for vv = 1:length(listOfWorms.width{wormToMeasure}{ff})
                            rr = max(1, min(yImage, round(listOfWorms.skel{wormToMeasure}{ff}(2,vv)-listOfWorms.width{wormToMeasure}{ff}(vv)):round(listOfWorms.skel{wormToMeasure}{ff}(2,vv)+listOfWorms.width{wormToMeasure}{ff}(vv))));
                            cc = max(1, min(xImage, round(listOfWorms.skel{wormToMeasure}{ff}(1,vv)-listOfWorms.width{wormToMeasure}{ff}(vv)):round(listOfWorms.skel{wormToMeasure}{ff}(1,vv)+listOfWorms.width{wormToMeasure}{ff}(vv))));
                            averageWormBodyMask(rr,cc) = 1 + averageWormBodyMask(rr,cc);
                            maskAreaCovered(rr,cc) = -1 + maskAreaCovered(rr,cc);
                        end
                        averageWormBodyArea = averageWormBodyArea - sum(averageWormBodyMask(:) > 0);
                        % -----------
                        % add new frame
                        % -----------
                        ff = ff0 + timeWindowForSweptAreas;
                        averageWormBodyMask(:) = 0;
                        for vv = 1:length(listOfWorms.width{wormToMeasure}{ff})
                            rr = max(1, min(yImage, round(listOfWorms.skel{wormToMeasure}{ff}(2,vv)-listOfWorms.width{wormToMeasure}{ff}(vv)):round(listOfWorms.skel{wormToMeasure}{ff}(2,vv)+listOfWorms.width{wormToMeasure}{ff}(vv))));
                            cc = max(1, min(xImage, round(listOfWorms.skel{wormToMeasure}{ff}(1,vv)-listOfWorms.width{wormToMeasure}{ff}(vv)):round(listOfWorms.skel{wormToMeasure}{ff}(1,vv)+listOfWorms.width{wormToMeasure}{ff}(vv))));
                            averageWormBodyMask(rr,cc) = 1 + averageWormBodyMask(rr,cc);
                            maskAreaCovered(rr,cc) = 1 + maskAreaCovered(rr,cc);
                        end
                        averageWormBodyArea = averageWormBodyArea + sum(averageWormBodyMask(:) > 0);
                        areaCoveredNorm(ff0) = sum(maskAreaCovered(:) > 0) / (averageWormBodyArea / (1+timeWindowForSweptAreas));
                        sweeping_noTimeNorm(ff0) = areaCoveredNorm(ff0) * temporalFreq(ff0*2) * fileDB(currentVideo).frames_per_second * 60;
                        % -----------
                        % move to the next frame
                        % -----------
                        ff0 = ff0 + 1;
                    end
                end
                % -----------
                % finished
                % -----------
            end
            tmp = sweeping_noTimeNorm;
            allMeasures.('Activity_Index_All')(wormToMeasure,1:length(sweeping_noTimeNorm))  = sweeping_noTimeNorm;
            allMeasures.('Activity_Index_Median')(wormToMeasure)  = median(tmp(tmp > 0));
            allMeasures.('Activity_Index_Range')(wormToMeasure)   = ( prctile(tmp(tmp > 0), 90) - prctile(tmp(tmp > 0), 10) );
            allMeasures.('Activity_Index_10')(wormToMeasure)   = prctile(tmp(tmp > 0), 10);
            tmp = areaCoveredNorm(areaCoveredNorm > 0) ./ timeWindowForSweptAreas;
            allMeasures.('Brush_Stroke_All')(wormToMeasure, 1:length(tmp)) = tmp;
            allMeasures.('Brush_Stroke_Median')(wormToMeasure) = median(tmp);
            allMeasures.('Brush_Stroke_Range')(wormToMeasure) = ( prctile(tmp, 90) - prctile(tmp, 10) );
            allMeasures.('Brush_Stroke_10')(wormToMeasure) = prctile(tmp, 10);
            totalWormsChecked = totalWormsChecked + 1;
        end
        if flagRemoveTempMeasures
            finalNamesAllValues = {'Wave_Initiation_Rate_All', 'Body_Wave_Number_All', 'Asymmetry_All', 'Reverse_Swimming_All', ...
                'Curling_All', 'Stretch_All', 'Attenuation_All', 'Traveling_Speed_All', 'Brush_Stroke_All', 'Activity_Index_All'...
                };
            for measureIdx = 1:length(finalNamesAllValues)
                allMeasures = rmfield(allMeasures, finalNamesAllValues{measureIdx});
            end
        end
        close(hTmp);
        pause(0.001);
        CSTwriteMeasuresToTXT(allMeasures, fileDB(currentVideo).name);
        fileDB(currentVideo).measured = true;
        fileDB(currentVideo).worms = totWorms;
        populateFilters
    end

% *****************
%      MEASURES
% *****************

% ============
% SHORTCUTS FOR NAVIGATION AND VALIDATION
% ============
    function keyboardShortcuts(hObject, eventdata) %#ok<INUSL>
        if strcmp(eventdata.Key, 'space') && ~isempty(eventdata.Modifier) && strcmp(eventdata.Modifier{1}, 'shift')
            isolateFrame
            switchValidity
        elseif strcmp(eventdata.Key, 'space')
            switchValidity
        elseif strcmp(eventdata.Key, 'leftarrow')
            selectFrameByClick(btnPrevFrame)
        elseif strcmp(eventdata.Key, 'rightarrow')
            selectFrameByClick(btnNextFrame)
        elseif strcmp(eventdata.Key, 'uparrow')
            selectNextBlock
        elseif strcmp(eventdata.Key, 'pageup')
            tmpNewWorm = get(listWorms, 'value') - 1;
            if tmpNewWorm >= 1
                set(listWorms, 'value', tmpNewWorm);
                selectWorm
            end
        elseif strcmp(eventdata.Key, 'pagedown')
            tmpNewWorm = get(listWorms, 'value') + 1;
            if tmpNewWorm <= nbOfWorms
                set(listWorms, 'value', tmpNewWorm)
                selectWorm
            end
        elseif strcmp(eventdata.Key, 'return')
            validateWorm
        elseif strcmp(eventdata.Key, 'backspace')
            rejectWorm
        elseif strcmp(eventdata.Key, 'home')
            selectFrameByClick(btnFirstFrame)
        end
    end


% ************************
%      GLARE ZONES MANAGEMENT
% ************************

% ============
% MANAGE GLARE ZONES FROM A POP-UP WINDOW: DISPLAY, DEFINE, MODIFY, ERASE, SAVE
% ============
    function manageGlareZones(hObject,eventdata) %#ok<*INUSD>
        if currentVideo == 0
            return
        end
        dimImage = 1.5*size(currentImage);
        popupPosition = [5,40,dimImage(2)+10,dimImage(1)+50];
        hPolygons = cell(1,length(fileDB(currentVideo).glareZones));
        hEllipses = cell(1,0);
        hPopup = figure('Visible','off','Position',popupPosition,'Name','CeleST: Define glare zone','numbertitle','off', 'menubar', 'none', 'windowstyle', 'modal');
        pnlPopup = uipanel('parent', hPopup,'BorderType', 'none','units','pixels', 'position', [0 0 popupPosition(3) popupPosition(4)]);
        hAxePopup = axes('parent', pnlPopup, 'units','pixels','position',[5 5 dimImage(2) dimImage(1)],'xtick',[],'ytick',[],'color',[.5 .5 .5]);
        uicontrol('parent',pnlPopup,'style','pushbutton','string','New Ellipse','position',[105 dimImage(1)+10 100 35],'callback',@(a,b) newEllipse);
        uicontrol('parent',pnlPopup,'style','pushbutton','string','New Polygon','position',[205 dimImage(1)+10 100 35],'callback',@(a,b) newPolygon);
        uicontrol('parent',pnlPopup,'style','pushbutton','string','Save and Close','position',[405 dimImage(1)+10 150 35],'callback',@(a,b) saveAll);
        uicontrol('parent',pnlPopup,'style','pushbutton','string','Erase zones','position',[655 dimImage(1)+10 100 35],'callback',@(a,b) eraseAll);
        image('parent', hAxePopup, 'cdata', currentImage);
        axis(hAxePopup, 'equal', 'off', 'image', 'tight','ij');
        colormap(gray(255));
        for zz = 1:length(fileDB(currentVideo).glareZones)
            hPolygons{zz} = impoly(hAxePopup, fileDB(currentVideo).glareZones{zz});
        end
        set(hPopup,'visible','on');
        waitfor(hPopup,'BeingDeleted','on');
        checkWormsAgainstGlare
        computeBlockSeparatorsAndValidity;
        selectWorm
        
        function newEllipse
            hEllipses{end+1} = imellipse(hAxePopup);
        end
        function newPolygon
            hPolygons{end+1} = impoly(hAxePopup);
        end
        function eraseAll
            choice = questdlg('Are you sure you want to erase all the zones?','Erase zones','Erase','Cancel','Cancel');
            if strcmp(choice,'Erase')
                for it = 1:length(hPolygons)
                    delete(hPolygons{it});
                end
                for it = 1:length(hEllipses)
                    delete(hEllipses{it});
                end
                hPolygons = cell(1,0);
                hEllipses = cell(1,0);
            end
        end
        function saveAll
            fileDB(currentVideo).glareZones = cell(1,0);
            for it = 1:length(hPolygons)
                tmpVertices = round(getPosition(hPolygons{it}));
                fileDB(currentVideo).glareZones{end+1} = tmpVertices([1:end,1],:);
            end
            for it = 1:length(hEllipses)
                tmpVertices = round(getVertices(hEllipses{it}));
                fileDB(currentVideo).glareZones{end+1} = tmpVertices(1:2:end,:);
            end
            flagNewZones = true;
            set(hPopup,'visible','off');
            delete(hPopup);
        end
    end

% ============
% CHECK WHETHER WORMS ARE WITHIN THE GLARE ZONES THROUGHOUT THE VIDEO
% ============
    function checkWormsAgainstGlare
        if isfield(fileDB, 'glareZones')
            % Build a mask of glare regions
            hWaitBar = waitbar(0,'Detecting the overlap of worms with glare zones...');
            pause(0.001)
            mask = false(yImage, xImage);
            for zz = 1:length(fileDB(currentVideo).glareZones)
                if ~isempty(fileDB(currentVideo).glareZones{zz})
                    mask = mask | poly2mask(fileDB(currentVideo).glareZones{zz}(:,1), fileDB(currentVideo).glareZones{zz}(:,2), yImage, xImage);
                end
            end
            for ww = 1:nbOfWorms
                waitbar(ww/nbOfWorms, hWaitBar);
                for ff = 1:nbOfFrames
                    skel = round(listOfWorms.skel{ww}{ff});
                    flagIn = false;
                    for vv = 1:size(skel,2)
                        if mask(max(1,min(yImage,skel(2,vv))), max(1,min(xImage,skel(1,vv))))
                            flagIn = true;
                            break
                        end
                    end
                    listOfWorms.inGlareZone(ww,ff) = flagIn;
                end
            end
            close(hWaitBar)
            pause(0.001)
        end
    end

% ************************
%      WORM SWITCHING
% ************************

% ============
% SELECT THE WORM TO BE SWITCHED FROM THE DROP-DOWN LIST IN THE GUI
% ============
    function setWormSwitch(hObject,eventdata) %#ok<*INUSD>
        valueSelected = get(popWormSwitch, 'value');
        if valueSelected <= 0
            set(popWormSwitch, 'value', idxOtherWorm);
        else
            idxOtherWorm = valueSelected;
        end
    end

% ============
% SWITCH THE TWO SELECTED WORMS
% ============
    function switchWorms(hObject,eventdata) %#ok<INUSD>
        frameCutStart = floor(str2double(get(editFrameCutStart, 'string')));
        if isnan(frameCutStart) || frameCutStart < 1 || frameCutStart > nbOfFrames
            return
        end
        frameCutEnd = floor(str2double(get(editFrameCutEnd, 'string')));
        if isnan(frameCutEnd) || frameCutEnd < 1 || frameCutEnd > nbOfFrames
            return
        end
        if (frameCutEnd < frameCutStart)
            helpdlg('The frames defining the switch are not consistent. The initial frame index should be smaller than the final one.','CeleST');
            return
        end
        choice = questdlg('Are you sure you want to switch the worms?','Switch worms','Switch','Cancel','Cancel');
        
        if strcmp(choice,'Switch')
            worm1 = currentWorm;
            worm2 = wormSwitchIdx(get(popWormSwitch,'value'));
            listBoolean = {'missed', 'lost', 'overlapped', 'valid', 'outOfLengths', 'outOfPrevious', 'inGlareZone', 'selfOverlap', 'manualInvalid', 'manualValid'};
            listCell = {'skel', 'width', 'cblSubSampled'};
            listCellSingle = {'localthreshold'};
            listDouble = {'lengthWorms', 'positionCenterX', 'positionCenterY', 'widthCenter', 'angleHead', 'angleTail', 'I', 'J', 'C', 'S', 'O', 'overlapPrev', 'headThrashCount'};
            if worm2 < 0
                disp('create new worm ')
                % ---------
                % Create a new worm
                % ---------
                nbOfWorms = 1 + nbOfWorms;
                worm2 = nbOfWorms;
                for idx = 1:length(listBoolean)
                    listOfWorms.(listBoolean{idx})(worm2,1:nbOfFrames) = false;
                end
                listOfWorms.lost(worm2,:) = true;
                for idx = 1:length(listCell)
                    for ff = 1:nbOfFrames
                        listOfWorms.(listCell{idx}){worm2}{ff} = listOfWorms.(listCell{idx}){worm1}{frameCutStart};
                    end
                end
                for idx = 1:length(listCellSingle)
                    listOfWorms.(listCellSingle{idx}){worm2} = listOfWorms.(listCellSingle{idx}){worm1};
                end
                for idx = 1:length(listDouble)
                    listOfWorms.(listDouble{idx})(worm2,1:nbOfFrames) = listOfWorms.(listDouble{idx})(worm1,frameCutStart);
                end
                longMean = mean(listOfWorms.lengthWorms(worm2,~listOfWorms.lost(worm2,:) & ~listOfWorms.overlapped(worm2,:)));
                longStd = std(listOfWorms.lengthWorms(worm2,~listOfWorms.lost(worm2,:) & ~listOfWorms.overlapped(worm2,:)));
                measures.highThrDef(worm2) = ceil(longMean + 3*longStd);
                measures.highThr(worm2) = measures.highThrDef(worm2);
                measures.lowThrDef(worm2) = max(0,floor(longMean - 3*longStd));
                measures.lowThr(worm2) = measures.lowThrDef(worm2);
                listOfWorms.outOfLengths(worm2,:) = (listOfWorms.lengthWorms(worm2,:) > measures.highThr(worm2)) | (listOfWorms.lengthWorms(worm2,:) < measures.lowThr(worm2));
                measures.prevThrDef(worm2) = 25;
                measures.prevThr(worm2) = measures.prevThrDef(worm2);
                listOfWorms.outOfPrevious(worm2,:) = (listOfWorms.overlapPrev(worm2,:)*100 < measures.prevThr(worm2));
                measures.status{worm2} = '';
                measures.manualSeparators{worm2} = [];
                measures.separators{worm2} = [];
                tmpAfterSelfOverlap(worm2,:) = false;
            end
            % ---------
            % Switch the two worms
            % ---------
            for idx = 1:length(listCell)
                buffer = listOfWorms.(listCell{idx}){worm1}(frameCutStart:frameCutEnd);
                listOfWorms.(listCell{idx}){worm1}(frameCutStart:frameCutEnd) = listOfWorms.(listCell{idx}){worm2}(frameCutStart:frameCutEnd);
                listOfWorms.(listCell{idx}){worm2}(frameCutStart:frameCutEnd) = buffer;
            end
            for idx = 1:length(listBoolean)
                buffer = listOfWorms.(listBoolean{idx})(worm1,frameCutStart:frameCutEnd);
                listOfWorms.(listBoolean{idx})(worm1,frameCutStart:frameCutEnd) = listOfWorms.(listBoolean{idx})(worm2,frameCutStart:frameCutEnd);
                listOfWorms.(listBoolean{idx})(worm2,frameCutStart:frameCutEnd) = buffer;
            end
            for idx = 1:length(listDouble)
                buffer = listOfWorms.(listDouble{idx})(worm1,frameCutStart:frameCutEnd);
                listOfWorms.(listDouble{idx})(worm1,frameCutStart:frameCutEnd) = listOfWorms.(listDouble{idx})(worm2,frameCutStart:frameCutEnd);
                listOfWorms.(listDouble{idx})(worm2,frameCutStart:frameCutEnd) = buffer;
            end
            % ---------
            % Check if the extremities of each worm should be switched in the frames that were swapped
            % ---------
            for ww = [worm1, worm2]
                if frameCutStart >= 2
                    if sum(hypot(listOfWorms.skel{ww}{frameCutStart-1}(1,:)-listOfWorms.skel{ww}{frameCutStart}(1,:),        listOfWorms.skel{ww}{frameCutStart-1}(2,:)-listOfWorms.skel{ww}{frameCutStart}(2,:)))...
                            > sum(hypot(listOfWorms.skel{ww}{frameCutStart-1}(1,:)-listOfWorms.skel{ww}{frameCutStart}(1,end:-1:1), listOfWorms.skel{ww}{frameCutStart-1}(2,:)-listOfWorms.skel{ww}{frameCutStart}(2,end:-1:1)))
                        % Swap
                        for ff = frameCutStart:frameCutEnd
                            listOfWorms.skel{ww}{ff} = listOfWorms.skel{ww}{ff}(:, end:-1:1);
                            listOfWorms.width{ww}{ff} = listOfWorms.width{ww}{ff}(end:-1:1);
                        end
                    end
                elseif frameCutEnd <= nbOfFrames-1
                    if sum(hypot(listOfWorms.skel{ww}{frameCutEnd}(1,:)-listOfWorms.skel{ww}{frameCutEnd+1}(1,:),        listOfWorms.skel{ww}{frameCutEnd}(2,:)-listOfWorms.skel{ww}{frameCutEnd+1}(2,:)))...
                            > sum(hypot(listOfWorms.skel{ww}{frameCutEnd}(1,:)-listOfWorms.skel{ww}{frameCutEnd+1}(1,end:-1:1), listOfWorms.skel{ww}{frameCutEnd}(2,:)-listOfWorms.skel{ww}{frameCutEnd+1}(2,end:-1:1)))
                        % Swap
                        for ff = frameCutStart:frameCutEnd
                            listOfWorms.skel{ww}{ff} = listOfWorms.skel{ww}{ff}(:, end:-1:1);
                            listOfWorms.width{ww}{ff} = listOfWorms.width{ww}{ff}(end:-1:1);
                        end
                    end
                end
            end
            measures.status{worm1} = 'unchecked';
            measures.status{worm2} = 'unchecked';
            computeBlockSeparatorsAndValidity
            % ---------
            % Update the interface
            % ---------
            nbOfWorms = length(listOfWorms.skel);
            newListTmp = cell(1,nbOfWorms);
            for tmp = 1:nbOfWorms
                newListTmp{tmp} = ['Worm ', num2str(tmp), ' : ', measures.status{tmp}];
            end
            set(listWorms, 'string', newListTmp);
            selectWorm;
        end
    end





% ************************
%      BLOCK MANAGEMENT
% ************************

% ============
% COMPUTE THE BLOCK SEPARATORS USING THE MANUALLY DEFINED ONES AND THE AUTOMATICALLY DEFINES ONES
% ============
    function computeBlockSeparatorsAndValidity
        % ------------
        % Find the frames at the end of a self-overlap zone
        % ------------
        tmpAfterSelfOverlap = [false(nbOfWorms,1) , listOfWorms.selfOverlap(:,1:end-1) & ~listOfWorms.selfOverlap(:,2:end) ];
        % ------------
        % Compute the validity of the frames
        % ------------
        listOfWorms.valid = listOfWorms.manualValid | (~ (listOfWorms.manualInvalid...
            | listOfWorms.outOfLengths | listOfWorms.outOfPrevious | listOfWorms.lost | listOfWorms.overlapped | listOfWorms.inGlareZone ...
            | tmpAfterSelfOverlap));
        % ------------
        % Define the block separators
        % ------------
        for ww = 1:nbOfWorms
            if ~strcmp(measures.status{ww}, 'rejected')
                measures.separators{ww} = unique(sort([...
                    1, 1+nbOfFrames, ...
                    measures.manualSeparators{ww}(:)',...
                    1 + find(listOfWorms.manualValid(ww,1:end-1)   ~= listOfWorms.manualValid(ww,2:end)),...
                    1 + find(listOfWorms.manualInvalid(ww,1:end-1) ~= listOfWorms.manualInvalid(ww,2:end)),...
                    1 + find(listOfWorms.outOfLengths(ww,1:end-1)  ~= listOfWorms.outOfLengths(ww,2:end)),...
                    1 + find(listOfWorms.outOfPrevious(ww,1:end-1) ~= listOfWorms.outOfPrevious(ww,2:end)),...
                    1 + find(listOfWorms.lost(ww,1:end-1)          ~= listOfWorms.lost(ww,2:end)),...
                    1 + find(listOfWorms.overlapped(ww,1:end-1)    ~= listOfWorms.overlapped(ww,2:end)),...
                    1 + find(listOfWorms.inGlareZone(ww,1:end-1)   ~= listOfWorms.inGlareZone(ww,2:end)),...
                    find(tmpAfterSelfOverlap(ww,:)), 1+find(tmpAfterSelfOverlap(ww,:)) ]));
            end
        end
    end

% ============
% SELECT THE NEXT BLOCK
% ============
    function selectNextBlock(hObject,eventdata) %#ok<*INUSD>
        if currentVideo == 0
            return
        end
        tmpRange = find(measures.separators{currentWorm} > currentFrame);
        % Select current block
        idxBlock = 1;
        prevSeparator = measures.separators{currentWorm}(tmpRange(idxBlock) - 1);
        nextSeparator = measures.separators{currentWorm}(tmpRange(idxBlock)) - 1;
        if (prevSeparator == valueStartFrame) && (nextSeparator == valueEndFrame) && (length(tmpRange) >= 2)
            % Select next block
            idxBlock = 2;
            prevSeparator = measures.separators{currentWorm}(tmpRange(idxBlock) - 1);
            nextSeparator = measures.separators{currentWorm}(tmpRange(idxBlock)) - 1;
        end
        valueStartFrame = prevSeparator;
        set(editStartFrame, 'string', num2str(valueStartFrame));
        valueEndFrame = nextSeparator;
        set(editEndFrame, 'string', num2str(valueEndFrame));
        currentFrame = valueStartFrame;
        set(editCurrentFrame, 'string', num2str(currentFrame));
        selectFrameByClick(editCurrentFrame,[]);
    end

% ============
% DEFINE A NEW BLOCK STARTING FROM THE CURRENT FRAME
% ============
    function splitBlock(hObject,eventdata) %#ok<INUSD>
        if currentVideo == 0
            return
        end
        if ~any(measures.manualSeparators{currentWorm} == currentFrame)
            measures.manualSeparators{currentWorm}(end+1) = currentFrame;
        end
        computeBlockSeparatorsAndValidity
        selectWorm
    end

% ============
% DEFINE A NEW BLOCK AS THE SINGLE CURRENT FRAME
% ============
    function isolateFrame(hObject,eventdata) %#ok<INUSD>
        if currentVideo == 0
            return
        end
        if ~any(measures.manualSeparators{currentWorm} == currentFrame)
            measures.manualSeparators{currentWorm}(end+1) = currentFrame;
        end
        if ~any(measures.manualSeparators{currentWorm} == currentFrame + 1)
            measures.manualSeparators{currentWorm}(end+1) = currentFrame + 1;
        end
        computeBlockSeparatorsAndValidity
        selectWorm
    end

% ============
% SWITCH THE VALIDITY FLAG OF ALL THE FRAMES IN THE CURRENT BLOCK
% ============
    function switchValidity(hObject,eventdata) %#ok<*INUSD>
        if currentVideo == 0
            return
        end
        tmpRange = find(measures.separators{currentWorm} > currentFrame);
        % Select current block
        idxBlock = 1;
        prevSeparator = measures.separators{currentWorm}(tmpRange(idxBlock) - 1);
        nextSeparator = measures.separators{currentWorm}(tmpRange(idxBlock)) - 1;
        newValue = ~ listOfWorms.valid(currentWorm, prevSeparator);
        % store it as manual
        if newValue
            listOfWorms.manualValid(currentWorm, prevSeparator:nextSeparator) = true;
            listOfWorms.manualInvalid(currentWorm, prevSeparator:nextSeparator) = false;
        else
            listOfWorms.manualValid(currentWorm, prevSeparator:nextSeparator) = false;
            listOfWorms.manualInvalid(currentWorm, prevSeparator:nextSeparator) = true;
        end
        computeBlockSeparatorsAndValidity
        selectWorm
        CSTwriteSegmentationToTXT(listOfWorms, fileDB(currentVideo).name);
    end


% ************************
%      FRAME SELECTION
% ************************

% ============
% SWITCH PLAY AND PAUSE VIDEO PLAYING
% ============
    function playPauseVideo(hObject,eventdata) %#ok<INUSD>
        if strcmp('Play',get(btnPlayVideo, 'string'))
            message = 'Pause';
        else
            message = 'Play';
        end
        set(btnPlayVideo, 'string', message, 'value', 0);
        while currentFrame < valueEndFrame && strcmp('Pause',get(btnPlayVideo, 'string')) && (get(btnPlayVideo,'Value') <= 0)
            pause(0.05);
            if (strcmp('Pause',get(btnPlayVideo, 'string')))
                % Play the video frame by frame
                selectFrameByClick(btnNextFrame, []);
            else
                break;
            end
        end
        set(btnPlayVideo, 'string', 'Play', 'value', 0);
    end

% ============
% SELECT A FRAME FROM ANY OF THE CONTROL OPTIONS IN THE GUI
% ============
    function selectFrameByClick(hObject,eventdata) %#ok<INUSD>
        if currentVideo == 0
            return
        end
        if hObject == btnPrevFrame
            currentFrame = max(1, currentFrame-1);
        elseif hObject == btnFirstFrame
            currentFrame = 1;
        elseif hObject == editStartFrame
            newValue = round(str2double(get(hObject, 'string')));
            if ~isnan(newValue) && newValue >= 1 && newValue <= nbOfFrames
                valueStartFrame = newValue;
            end
            set(hObject, 'string', num2str(valueStartFrame));
            return
        elseif hObject == editCurrentFrame
            newValue = floor(str2double(get(hObject, 'string')));
            if ~isnan(newValue) && newValue >= 1 && newValue <= nbOfFrames
                currentFrame = newValue;
            end
        elseif hObject == btnNextFrame
            currentFrame = min(nbOfFrames, currentFrame+1);
        elseif hObject == editEndFrame
            newValue = round(str2double(get(hObject, 'string')));
            if ~isnan(newValue) && newValue >= 1 && newValue <= nbOfFrames
                valueEndFrame = newValue;
            end
            set(hObject, 'string', num2str(valueEndFrame));
            return
        elseif hObject == btnForwardFrame
            currentFrame = valueEndFrame;
        elseif hObject == btnRewindFrame
            currentFrame = valueStartFrame;
        elseif hObject == btnLastFrame
            currentFrame = nbOfFrames;
        elseif hObject == hAxeLength || hObject == hAxeLost || hObject == hAxePrevOverlap || hObject == hAxeOverlap || hObject == hAxeSelfOverlap || hObject == hAxeGlare
            click = get(hObject, 'CurrentPoint');
            currentFrame = max(1, min(nbOfFrames, floor(click(1))));
        elseif hObject == hAxeValid
            click = get(hObject, 'CurrentPoint');
            if strcmp(get(mainFigure,'SelectionType'),'normal')
                % ------------
                % left click: select a single frame
                % ------------
                currentFrame = max(1, min(nbOfFrames, floor(click(1))));
            elseif strcmp(get(mainFigure,'SelectionType'),'alt')
                % ------------
                % right click: change the validity of the block
                % ------------
                tmpRange = find(measures.separators{currentWorm} > click(1));
                prevSeparator = measures.separators{currentWorm}(tmpRange(1) - 1);
                nextSeparator = measures.separators{currentWorm}(tmpRange(1)) - 1;
                newValue = ~ listOfWorms.valid(currentWorm, prevSeparator);
                % store it as manual
                if newValue
                    listOfWorms.manualValid(currentWorm, prevSeparator:nextSeparator) = true;
                    listOfWorms.manualInvalid(currentWorm, prevSeparator:nextSeparator) = false;
                else
                    listOfWorms.manualValid(currentWorm, prevSeparator:nextSeparator) = false;
                    listOfWorms.manualInvalid(currentWorm, prevSeparator:nextSeparator) = true;
                end
                computeBlockSeparatorsAndValidity
                selectWorm
            elseif strcmp(get(mainFigure,'SelectionType'),'open')
                click = get(hObject, 'CurrentPoint');
                % ------------
                % double click: add a separator
                % ------------
                newSeparator = floor(click(1));
                if any(measures.separators{currentWorm} == newSeparator)
                    newSeparator = 1 + newSeparator;
                    % if existing separator, add one at the next frame
                    if any(measures.separators{currentWorm} == newSeparator)
                        newSeparator = [];
                    end
                end
                if ~isempty(newSeparator)
                    % store it as a manual separator
                    measures.manualSeparators{currentWorm}(end+1) = newSeparator;
                    computeBlockSeparatorsAndValidity
                    selectWorm
                end
            end
        end
        set(editCurrentFrame, 'string', int2str(currentFrame));
        currentImage = imread( fullfile( fileDB(currentVideo).directory, imageFiles(currentFrame).name) );
        displayCurrentFrame
    end

% ============
% DISPLAY THE CURRENT FRAME WITH ALL RELEVANT UPDATES IN THE GUI
% ============
    function displayCurrentFrame(hObject,eventdata) %#ok<INUSD>
        % -------------------
        % Display the current frame location on all graphs
        % -------------------
        tmp = axis(hAxeLength);
        set(hRectCurrentFrame(1), 'position', [currentFrame, tmp(3), 1, tmp(4)-tmp(3)]);
        set(hRectCurrentFrame(2), 'position', [currentFrame, 0, 1, 1]);
        set(hRectCurrentFrame(3), 'position', [currentFrame, 0, 1, 1]);
        set(hRectCurrentFrame(4), 'position', [currentFrame, 0, 1, 1]);
        set(hRectCurrentFrame(5), 'position', [currentFrame, 0, 1, 1]);
        set(hRectCurrentFrame(6), 'position', [currentFrame, 0, 1, 1]);
        set(hRectCurrentFrame(7), 'position', [currentFrame, 0, 1, 1]);
        % -------------------
        % Display the image and the worms
        % -------------------
        if listOfWorms.valid(currentWorm,currentFrame)
            colour = colorAccepted;
        else
            colour = colorRejected;
        end
        if (isempty(hMainImage) || ~ishandle(hMainImage))
            hMainImage = image('parent', hAxeAllVideo, 'cdata', currentImage);
            axis(hAxeAllVideo, 'equal', 'off', 'image')
        else
            set(hMainImage, 'cdata', currentImage);
        end
        
        cbl = listOfWorms.skel{currentWorm}{currentFrame};
        width = listOfWorms.width{currentWorm}{currentFrame};
        bbox = [ max(1,min(xImage, min(floor(cbl(1,:)-width)-displayAroundWorms))), ... % xMin
            max(1,min(xImage, max(ceil(cbl(1,:)+width)+displayAroundWorms))), ... % xMax
            max(1,min(yImage, min(floor(cbl(2,:)-width)-displayAroundWorms))), ... % yMin
            max(1,min(yImage, max(ceil(cbl(2,:)+width)+displayAroundWorms))) ];   % yMax
        tmp = mean(cbl,2);
        hold(hAxeAllVideo, 'on');
        if flagNewZones && isfield(fileDB, 'glareZones')
            for zz = 1:length(hGlareZones)
                if ishandle(hGlareZones{zz})
                    delete(hGlareZones{zz});
                end
            end
            hGlareZones = cell(1,length(fileDB(currentVideo).glareZones));
            for zz = 1:length(fileDB(currentVideo).glareZones)
                if ~isempty(fileDB(currentVideo).glareZones{zz})
                    hGlareZones{zz} = plot(hAxeAllVideo, fileDB(currentVideo).glareZones{zz}(:,1), fileDB(currentVideo).glareZones{zz}(:,2), 'color', colorRejected);
                end
            end
            flagNewZones = false;
        end
        if (length(hMainAllWorms) < currentWorm || isempty(hMainAllWorms(currentWorm)) || ~ishandle(hMainAllWorms(currentWorm)))
            hMainAllWorms(currentWorm) = plot(hAxeAllVideo,cbl(1,:), cbl(2,:), 'color', colour,'linewidth',2);
            hMainTextWorms(currentWorm) = text(tmp(1), tmp(2), num2str(currentWorm),'parent',hAxeAllVideo,'color', 'r','FontSize',12, 'fontweight' ,' bold');
            hMainBox = plot(hAxeAllVideo,bbox([1 1 2 2 1]), bbox([3 4 4 3 3]),'-r');
        else
            set(hMainAllWorms(currentWorm), 'xdata', cbl(1,:), 'ydata', cbl(2,:), 'color', colour,'linewidth',2);
            set(hMainTextWorms(currentWorm), 'position', tmp,'color', 'r','FontSize',12);
            set(hMainBox, 'xdata', bbox([1 1 2 2 1]), 'ydata', bbox([3 4 4 3 3]));
        end
        for otherWorm = [1:currentWorm-1 , currentWorm+1:nbOfWorms]
            if ~strcmp('rejected', measures.status{otherWorm})
                tmp = mean(listOfWorms.skel{otherWorm}{currentFrame},2);
                if listOfWorms.valid(otherWorm,currentFrame)
                    colourOther = colorAccepted;
                else
                    colourOther = colorRejected;
                end
                if (length(hMainAllWorms) < otherWorm || isempty(hMainAllWorms(otherWorm)) || ~ishandle(hMainAllWorms(otherWorm)))
                    hMainAllWorms(otherWorm) = plot(hAxeAllVideo, listOfWorms.skel{otherWorm}{currentFrame}(1,:), listOfWorms.skel{otherWorm}{currentFrame}(2,:), 'color', colourOther,'linewidth',2);
                    hMainTextWorms(otherWorm) = text(tmp(1), tmp(2), num2str(otherWorm),'parent',hAxeAllVideo,'color', 'r','FontSize',12, 'fontweight' ,'bold');
                else
                    set(hMainAllWorms(otherWorm), 'xdata', listOfWorms.skel{otherWorm}{currentFrame}(1,:), 'ydata', listOfWorms.skel{otherWorm}{currentFrame}(2,:), 'color', colourOther,'linewidth',2);
                    set(hMainTextWorms(otherWorm), 'position', tmp,'color', 'r','FontSize',12, 'fontweight' ,' bold');
                end
            else
                tmp = mean(listOfWorms.skel{otherWorm}{currentFrame},2);
                if (length(hMainAllWorms) < otherWorm || isempty(hMainAllWorms(otherWorm)) || ~ishandle(hMainAllWorms(otherWorm)))
                    hMainAllWorms(otherWorm) = plot(hAxeAllVideo, listOfWorms.skel{otherWorm}{currentFrame}(1,:), listOfWorms.skel{otherWorm}{currentFrame}(2,:), 'color', [0.5 0.5 0.5],'linewidth',1);
                    hMainTextWorms(otherWorm) = text(tmp(1), tmp(2), num2str(otherWorm),'parent',hAxeAllVideo,'color', 'r','FontSize',12, 'fontweight' ,'bold');
                else
                    set(hMainAllWorms(otherWorm), 'xdata', listOfWorms.skel{otherWorm}{currentFrame}(1,:), 'ydata', listOfWorms.skel{otherWorm}{currentFrame}(2,:), 'color', [0.5 0.5 0.5],'linewidth',1);
                    set(hMainTextWorms(otherWorm), 'position', tmp,'color', 'r','FontSize',12, 'fontweight' ,' bold');
                end
            end
        end
        hold(hAxeAllVideo,'off')
        
        edges = cbl(:,[2:end,end]) - cbl(:,[1:end-1,end-1]);
        edges = [width; width] .* edges ./ ([1;1]*hypot(edges(1,:), edges(2,:)));
        normals = [-edges(2,:) ; edges(1,:)];
        tmpDraw = [ cbl(:,1) - edges(:,1) , cbl + normals , cbl(:,end) + edges(:,end) , cbl(:,end:-1:1) - normals(:,end:-1:1) , cbl(:,1) - edges(:,1)];
        tmpDraw(1,:) = tmpDraw(1,:) - bbox(1)+1;
        tmpDraw(2,:) = tmpDraw(2,:) - bbox(3)+1;
        
        if (isempty(hSubImage) || ~ishandle(hSubImage))
            hSubImage = image('parent', hAxeCurrentWorm, 'cdata', currentImage(bbox(3):bbox(4), bbox(1):bbox(2)));
            hold(hAxeCurrentWorm, 'on')
            hSubWorm = plot(hAxeCurrentWorm, tmpDraw(1,:), tmpDraw(2,:), 'color', colour, 'linewidth', 2);
        else
            set(hSubImage,  'cdata', currentImage(bbox(3):bbox(4), bbox(1):bbox(2)));
            set(hSubWorm, 'xdata', tmpDraw(1,:), 'ydata', tmpDraw(2,:), 'color', colour);
        end
        axis(hAxeCurrentWorm, 'equal', 'off', 'image', 'tight')
        hold(hAxeCurrentWorm, 'on')
        if isempty(hCBLSub) || ~ishandle(hCBLSub)
            if flagShowCBLSub && ~isempty(listOfWorms.cblSubSampled{currentWorm}{currentFrame})
                hCBLSub = plot(hAxeCurrentWorm, listOfWorms.cblSubSampled{currentWorm}{currentFrame}(1,:) - bbox(1)+1, listOfWorms.cblSubSampled{currentWorm}{currentFrame}(2,:) - bbox(3)+1, '-b*', 'linewidth', 2);
            end
            if flagShowThrash && isfield(listOfWorms, 'headThrashCount') && ~isempty(listOfWorms.headThrashCount)
                hThrash = text( listOfWorms.cblSubSampled{currentWorm}{currentFrame}(1,1) - bbox(1)+1, listOfWorms.cblSubSampled{currentWorm}{currentFrame}(2,1) - bbox(3)+1,...
                    num2str(listOfWorms.headThrashCount(currentWorm,currentFrame)), 'parent', hAxeCurrentWorm, 'fontsize', 15, 'color', colorThrash);
            end
        else
            set(hSubImage,  'cdata', currentImage(bbox(3):bbox(4), bbox(1):bbox(2)));
            axis(hAxeCurrentWorm, 'equal', 'off', 'image', 'tight')
            if flagShowCBLSub && ~isempty(listOfWorms.cblSubSampled{currentWorm}{currentFrame})
                set(hCBLSub, 'xdata', listOfWorms.cblSubSampled{currentWorm}{currentFrame}(1,:) - bbox(1)+1, 'ydata', listOfWorms.cblSubSampled{currentWorm}{currentFrame}(2,:) - bbox(3)+1);
            end
            if flagShowThrash && isfield(listOfWorms, 'headThrashCount') && ~isempty(listOfWorms.headThrashCount)
                set(hThrash, 'position', listOfWorms.cblSubSampled{currentWorm}{currentFrame}(:,1) - [bbox(1); bbox(3)]+1, 'string',  num2str(listOfWorms.headThrashCount(currentWorm,currentFrame)));
            end
        end
        axis(hAxeCurrentWorm, 'equal', 'off', 'image', 'tight')
        hold(hAxeCurrentWorm,'off')
    end

% ************************
%      VIDEO SELECTION
% ************************

% ============
% LOAD THE DATA FOR THE SELECTED VIDEO, THEN UPDATE THE WORM DISPLAY
% ============
    function loadVideoContents(hObject,eventdata) %#ok<INUSD>
        if (nargin <= 0) ||  (~isempty(listVideosIdx))
            % ------------
            % Check if the video should be loaded from user selection in GUI, or from arguments passed through API
            % ------------
            if nargin <= 0
                currentVideo = videoIdxToLoad;
            else
                currentVideo = listVideosIdx(get(listVideos,'value'));
            end
            % ------------
            % Check the presence of image files
            % ------------
            imageFiles = dir(fullfile(fileDB(currentVideo).directory,['*.',fileDB(currentVideo).format]));
            if ~isempty(imageFiles)
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
            end
            
            currentFrame = 1;
            set(editCurrentFrame, 'string', int2str(currentFrame));
            try
                currentImage = imread( fullfile( fileDB(currentVideo).directory, imageFiles(currentFrame).name) );
            catch %#ok<CTCH>
                currentImage = zeros(500);
            end
            xImage = size(currentImage,2);
            yImage = size(currentImage,1);
            % ------------
            % Update the display with the total number of images
            % ------------
            nbOfFrames = length(imageFiles);
            set(txtMaxFrame,'string', num2str(nbOfFrames));
            valueStartFrame = 1;
            valueEndFrame = nbOfFrames;
            set(editStartFrame, 'string', num2str(valueStartFrame));
            set(editEndFrame, 'string', num2str(valueEndFrame));
            % ------------
            % Check the presence of segmentation results
            % ------------
            ftmp = fopen(fullfile(filenames.segmentation, ['wormSegm_',fileDB(currentVideo).name,'.txt']));
            if ftmp >= 3
                fclose(ftmp);
                % ------------
                % Load the segmentation results
                % ------------
                listOfWorms = CSTreadSegmentationFromTXT(fileDB(currentVideo).name);
                nbOfWorms = length(listOfWorms.skel);
                % ------------
                % Check the presence of measures
                % ------------
                if ( fileDB(currentVideo).measured && isfield(listOfWorms,'outOfLengths'))
                    measures = CSTreadMeasuresFromTXT(fileDB(currentVideo).name, true);
                    
                    if isfield(measures, 'ratioThrashMedian')
                        measures = rmfield(measures, 'ratioThrashMedian');
                    end
                    if isfield(measures, 'ratioThrashStd')
                        measures = rmfield(measures, 'ratioThrashStd');
                    end
                    if isfield(measures, 'ratioAngleThrashMedian')
                        measures = rmfield(measures, 'ratioAngleThrashMedian');
                    end
                    
                    tmpAfterSelfOverlap = [false(nbOfWorms,1) , listOfWorms.selfOverlap(:,1:end-1) & ~listOfWorms.selfOverlap(:,2:end) ];
                else
                    % ------------
                    % No previous existing measures
                    % ------------
                    hTmp = waitbar(0,'Analyzing the results...');
                    pause(0.001)
                    % ------------
                    % Add extra fields if they are not defined already
                    % ------------
                    if ~isfield(listOfWorms, 'outOfLengths')
                        listOfWorms.outOfLengths = false(nbOfWorms,nbOfFrames);
                        listOfWorms.outOfPrevious = false(nbOfWorms,nbOfFrames);
                        listOfWorms.inGlareZone = false(nbOfWorms,nbOfFrames);
                        listOfWorms.valid = false(nbOfWorms,nbOfFrames);
                        listOfWorms.selfOverlap = false(nbOfWorms,nbOfFrames);
                        listOfWorms.positionCenterX = zeros(nbOfWorms,nbOfFrames);
                        listOfWorms.positionCenterY = zeros(nbOfWorms,nbOfFrames);
                        listOfWorms.widthCenter = zeros(nbOfWorms,nbOfFrames);
                        listOfWorms.cblSubSampled = cell(1,nbOfWorms);
                        for ww = 1:nbOfWorms
                            listOfWorms.cblSubSampled{ww} = cell(1,nbOfFrames);
                        end
                        listOfWorms.overlapPrev = zeros(nbOfWorms, nbOfFrames);
                        listOfWorms.manualInvalid = false(nbOfWorms, nbOfFrames);
                        listOfWorms.manualValid = false(nbOfWorms, nbOfFrames);
                        listOfWorms.headThrashCount = zeros(nbOfWorms, nbOfFrames);
                    end
                    % ------------
                    % Scan the results
                    % ------------
                    subSamp = (0:(1/nbSamplesCBL):1)';
                    for ff = 1:nbOfFrames
                        waitbar(ff/nbOfFrames,hTmp);
                        bbox = zeros(nbOfWorms,4);
                        for ww = 1:nbOfWorms
                            % =========
                            % Remove extremities of width 0
                            % =========
                            if ~isempty(listOfWorms.width{ww}{ff}) && (listOfWorms.width{ww}{ff}(1) <= 0 || norm(listOfWorms.skel{ww}{ff}(:,1) - listOfWorms.skel{ww}{ff}(:,2)) < 0.05)
                                % Remove the head
                                listOfWorms.width{ww}{ff}(1) = [];
                                listOfWorms.skel{ww}{ff}(:,1) = [];
                            end
                            if ~isempty(listOfWorms.width{ww}{ff}) && (listOfWorms.width{ww}{ff}(end) <= 0 || norm(listOfWorms.skel{ww}{ff}(:,end) - listOfWorms.skel{ww}{ff}(:,end-1)) < 0.05)
                                % Remove the tail
                                listOfWorms.width{ww}{ff}(end) = [];
                                listOfWorms.skel{ww}{ff}(:,end) = [];
                            end
                            % =========
                            % Re-sample the CBL
                            % =========
                            currentCBL = listOfWorms.skel{ww}{ff};
                            long = cumsum([0,hypot(currentCBL(1,2:end)-currentCBL(1,1:end-1), currentCBL(2,2:end)-currentCBL(2,1:end-1))]);
                            listOfWorms.lengthWorms(ww,ff) = long(end);
                            long = long / long(end);
                            currentCBL = interp1q(long', currentCBL', subSamp)';
                            currentWidth = interp1q(long', listOfWorms.width{ww}{ff}', subSamp)';
                            listOfWorms.skel{ww}{ff} = currentCBL;
                            listOfWorms.width{ww}{ff} = currentWidth;
                            listOfWorms.positionCenterX(ww,ff) = currentCBL(1, 1+nbSamplesCBL/2);
                            listOfWorms.positionCenterY(ww,ff) = currentCBL(2, 1+nbSamplesCBL/2);
                            listOfWorms.widthCenter(ww,ff) = mean(listOfWorms.width{ww}{ff});
                            % =========
                            % Detect overlap of extremities
                            % =========
                            flagLoopyWorm = false;
                            totSub = length(subSamp);
                            headThird = round(totSub/3);
                            tailThird = round(2*totSub/3);
                            % --------
                            % Check if head is overlapping with tail
                            % --------
                            for idx = 1:headThird
                                within = (hypot(currentCBL(1,idx+3:end) - currentCBL(1,idx), currentCBL(2,idx+3:end) - currentCBL(2,idx)) - currentWidth(idx+3:end) < 0 );
                                if any(within)
                                    flagLoopyWorm = true;
                                    break
                                end
                            end
                            % --------
                            % Check if tail is overlapping with head
                            % --------
                            if ~flagLoopyWorm
                                for idx = tailThird:totSub
                                    within = (hypot(currentCBL(1,1:idx-3) - currentCBL(1,idx), currentCBL(2,1:idx-3) - currentCBL(2,idx)) - currentWidth(1:idx-3) < 0 );
                                    if any(within)
                                        flagLoopyWorm = true;
                                        break
                                    end
                                end
                            end
                            listOfWorms.selfOverlap(ww,ff) = flagLoopyWorm;
                            % =========
                            % Detect whether head and tail were swapped
                            % =========
                            if ff >= 2 && ...
                                    sum(hypot(listOfWorms.skel{ww}{ff-1}(1,:)-listOfWorms.skel{ww}{ff}(1,:),listOfWorms.skel{ww}{ff-1}(2,:)-listOfWorms.skel{ww}{ff}(2,:)))...
                                    > sum(hypot(listOfWorms.skel{ww}{ff-1}(1,:)-listOfWorms.skel{ww}{ff}(1,end:-1:1),listOfWorms.skel{ww}{ff-1}(2,:)-listOfWorms.skel{ww}{ff}(2,end:-1:1)))
                                % Swap
                                listOfWorms.skel{ww}{ff} = listOfWorms.skel{ww}{ff}(:, end:-1:1);
                                listOfWorms.width{ww}{ff} = listOfWorms.width{ww}{ff}(end:-1:1);
                            end
                            % =========
                            % Compute bounding box
                            % =========
                            bbox(ww,:) = [ min(listOfWorms.skel{ww}{ff}(1,:) - listOfWorms.width{ww}{ff}) , ...
                                max(listOfWorms.skel{ww}{ff}(1,:) + listOfWorms.width{ww}{ff}) , ...
                                min(listOfWorms.skel{ww}{ff}(2,:) - listOfWorms.width{ww}{ff}) , ...
                                max(listOfWorms.skel{ww}{ff}(2,:) + listOfWorms.width{ww}{ff}) ];
                            % =========
                            % Compute overlap with previous location
                            % =========
                            if ff >= 2
                                distTmp = zeros(1,length(listOfWorms.skel{ww}{ff}));
                                for vv = 1:length(listOfWorms.skel{ww}{ff})
                                    distTmp(vv) = min(hypot(listOfWorms.skel{ww}{ff}(1,vv)-listOfWorms.skel{ww}{ff-1}(1,:), listOfWorms.skel{ww}{ff}(2,vv)-listOfWorms.skel{ww}{ff-1}(2,:))...
                                        - listOfWorms.width{ww}{ff-1}) < 0;
                                end
                                listOfWorms.overlapPrev(ww, ff) = mean(distTmp);
                            else
                                listOfWorms.overlapPrev(ww, ff) = 1;
                            end
                            
                            % =========
                            % Detect overlap with other worms
                            % =========
                            if ~(listOfWorms.lost(ww,ff) || listOfWorms.missed(ww,ff))
                                % --------
                                % Compute the bounding boxes
                                % --------
                                for otherWorm = 1:(ww-1)
                                    if ~(listOfWorms.lost(otherWorm,ff) || listOfWorms.missed(otherWorm,ff))
                                        overlapX = (bbox(ww,1) <= bbox(otherWorm,1) && bbox(ww,2) >= bbox(otherWorm,1)) || (bbox(ww,1) >= bbox(otherWorm,1) && bbox(otherWorm,2) >= bbox(ww,1));
                                        overlap = overlapX && ((bbox(ww,3) <= bbox(otherWorm,3) && bbox(ww,4) >= bbox(otherWorm,3)) || (bbox(ww,3) >= bbox(otherWorm,3) && bbox(otherWorm,4) >= bbox(ww,3)));
                                        if overlap
                                            for vv = 1:length(listOfWorms.skel{ww}{ff})
                                                distTmp = hypot(listOfWorms.skel{ww}{ff}(1,vv)-listOfWorms.skel{otherWorm}{ff}(1,:),...
                                                    listOfWorms.skel{ww}{ff}(2,vv)-listOfWorms.skel{otherWorm}{ff}(2,:));
                                                distTmp = distTmp(:) - listOfWorms.width{ww}{ff}(vv) - listOfWorms.width{otherWorm}{ff}(:);
                                                if any(distTmp <= 0)
                                                    listOfWorms.overlapped(ww, ff) = true;
                                                    listOfWorms.overlapped(otherWorm, ff) = true;
                                                    break
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                    % --------
                    % Compute the outOfLengths thresholds
                    % --------
                    measures.highThr = zeros(1,nbOfWorms);
                    measures.lowThr = zeros(1,nbOfWorms);
                    measures.prevThr = zeros(1,nbOfWorms);
                    measures.highThrDef = zeros(1,nbOfWorms);
                    measures.lowThrDef = zeros(1,nbOfWorms);
                    measures.prevThrDef = zeros(1,nbOfWorms);
                    for ww = 1:nbOfWorms
                        longMean = mean(listOfWorms.lengthWorms(ww,~listOfWorms.lost(ww,:) & ~listOfWorms.overlapped(ww,:)));
                        longStd = std(listOfWorms.lengthWorms(ww,~listOfWorms.lost(ww,:) & ~listOfWorms.overlapped(ww,:)));
                        measures.highThrDef(ww) = ceil(longMean + 3*longStd);
                        if length(measures.highThr) < ww || measures.highThr(ww) == 0;
                            measures.highThr(ww) = measures.highThrDef(ww);
                        end
                        measures.lowThrDef(ww) = max(0,floor(longMean - 3*longStd));
                        if length(measures.lowThr) < ww || measures.lowThr(ww) == 0;
                            measures.lowThr(ww) = measures.lowThrDef(ww);
                        end
                        listOfWorms.outOfLengths(ww,:) = (listOfWorms.lengthWorms(ww,:) > measures.highThr(ww)) | (listOfWorms.lengthWorms(ww,:) < measures.lowThr(ww));
                        % --------
                        % Define the default previous overlap threshold
                        % --------
                        measures.prevThrDef(ww) = 25;
                        measures.prevThr(ww) = measures.prevThrDef(ww);
                        listOfWorms.outOfPrevious(ww,:) = (listOfWorms.overlapPrev(ww,:)*100 < measures.prevThr(ww));
                    end
                    % --------
                    % Compute the blocks and separators
                    % --------
                    measures.status = cell(1,nbOfWorms);
                    measures.manualSeparators = cell(nbOfWorms,1);
                    measures.separators = cell(nbOfWorms,1);
                    tmpAfterSelfOverlap = false(nbOfWorms, nbOfFrames);
                    checkWormsAgainstGlare
                    computeBlockSeparatorsAndValidity;
                    close(hTmp);
                end
                newListTmp = cell(1,nbOfWorms);
                %-------------------
                % Use existing measures files in older format to extract the validity of the worms
                %-------------------
                fidTmp = fopen(fullfile([filenames.measures, ' copy'], ['wormMeas_',fileDB(currentVideo).name,'.txt']),'r');
                if fidTmp >= 3
                    sscanf(fgetl(fidTmp), 'fields %d');
                    nbOfWormsTmp = sscanf(fgetl(fidTmp), 'worms %d');
                    fieldTmp = fgetl(fidTmp);
                    if strcmp(fieldTmp, 'status')
                        % always store status anyway
                        existingStatus = cell(1,nbOfWormsTmp);
                        for ww = 1:nbOfWormsTmp
                            existingStatus{ww} = fgetl(fidTmp);
                            measures.status{ww} = existingStatus{ww};
                        end
                    end
                end
                for tmp = 1:nbOfWorms
                    if isempty(measures.status{tmp})
                        measures.status{tmp} = 'unchecked';
                    end
                    if sum(listOfWorms.valid(tmp,:)) < 50
                        measures.status{tmp} = 'rejected';
                    end
                    newListTmp{tmp} = ['Worm ', num2str(tmp), ' : ', measures.status{tmp}];
                end
                set(listWorms, 'string', newListTmp, 'value',1);
                set(txtVideoLoaded,'string',fileDB(currentVideo).name);
            else
                listOfWorms = cell(1,0);
                set(listWorms, 'string', [], 'value',1);
            end
            hMainAllWorms = [];
            hMainTextWorms = [];
            hMainBox = [];
            cla(hAxeAllVideo);
            cla(hAxeCurrentWorm);
            colormap(gray(255))
            selectWorm
        else
            % ------------
            % No existing segmentation results
            % ------------
            listOfWorms = cell(1,0);
            set(listWorms, 'string', [], 'value',1);
        end
    end

% ============
% CHECK IF THE NEW VIDEO HAS DATA TO LOAD
% ============
    function checkSelectedVideo(hObject,eventdata) %#ok<INUSD>
        if ~isempty(listVideosIdx)
            tmp = listVideosIdx(get(listVideos,'value'));
            if fileDB(tmp).segmented
                set(btnLoad,'enable','on');
            else
                set(btnLoad,'enable','off');
            end
        else
            set(btnLoad,'enable','off');
        end
    end

% ************************
%      WORM SELECTION
% ************************

% ============
% SELECT A WORM IN THE LIST, UPDATE ALL THE RELEVANT DISPLAYS IN THE GUI ACCORDINGLY
% ============
    function selectWorm(hObject,eventdata) %#ok<INUSD>
        currentWorm = get(listWorms, 'value');
        if isempty(currentWorm)
            cla(hAxeLength)
        else
            % -------------------
            % Find listOfWorms.outOfLengths zones
            % -------------------
            set(txtSelectedWorm, 'String', ['Worm ', num2str(currentWorm)]);
            set(editHighThr, 'string', int2str(measures.highThr(currentWorm)));
            set(editLowThr, 'string', int2str(measures.lowThr(currentWorm)));
            set(editPrevThr, 'string', int2str(measures.prevThr(currentWorm)));
            newListTmp = {};
            wormSwitchIdx = [];
            for otherWorm = [1:currentWorm-1 , currentWorm+1:nbOfWorms]
                if ~strcmp('rejected', measures.status{otherWorm})
                    newListTmp{end+1} = ['Worm ', num2str(otherWorm)]; %#ok<AGROW>
                    wormSwitchIdx(end+1) = otherWorm; %#ok<AGROW>
                end
            end
            newListTmp{end+1} = 'new worm';
            wormSwitchIdx(end+1) = -1;
            set(popWormSwitch, 'string', newListTmp,'value', 1);
            % -------------------
            % Display the valid frames
            % -------------------
            cla(hAxeValid)
            hold(hAxeValid, 'on');
            for ff = 1:nbOfFrames
                if listOfWorms.valid(currentWorm,ff)
                    rectangle('parent',hAxeValid, 'position', [ff, 0, 1, 1], 'FaceColor', colorAccepted, 'edgecolor', colorAccepted, 'hittest', 'off');
                else
                    rectangle('parent',hAxeValid, 'position', [ff, 0, 1, 1], 'FaceColor', colorRejected, 'edgecolor', colorRejected, 'hittest', 'off');
                end
            end
            for sep = 1:length(measures.separators{currentWorm})
                line('parent',hAxeValid, 'xdata', measures.separators{currentWorm}(sep)*[1,1], 'ydata', [0, 1], 'color', 'k', 'hittest', 'off');
            end
            axis(hAxeValid,[1 nbOfFrames+1 0 1]);
            grid(hAxeValid,'on')
            set(hAxeValid, 'XTickLabel', [], 'TickLength', [0 0],'YTick',[0 1], 'YTickLabel', [], 'color', 'w', 'ButtonDownFcn', @selectFrameByClick);
            % -------------------
            % Display the overlap with glare zones
            % -------------------
            cla(hAxeGlare)
            hold(hAxeGlare, 'on');
            for ff = find(listOfWorms.inGlareZone(currentWorm,:))
                rectangle('parent',hAxeGlare, 'position', [ff, 0, 1, 1], 'FaceColor', colorRejected, 'edgecolor', colorRejected, 'hittest', 'off');
            end
            axis(hAxeGlare,[1 nbOfFrames+1 0 1]);
            grid(hAxeGlare,'on')
            set(hAxeGlare, 'XTickLabel', [], 'TickLength', [0 0],'YTick',[0 1], 'YTickLabel', [], 'color', 'w', 'ButtonDownFcn', @selectFrameByClick);
            % -------------------
            % Display the previous overlap
            % -------------------
            cla(hAxePrevOverlap)
            hold(hAxePrevOverlap, 'on');
            for ff = find(listOfWorms.outOfPrevious(currentWorm,:))
                rectangle('parent',hAxePrevOverlap, 'position', [ff, 0, 1, 1], 'FaceColor', colorRejected, 'edgecolor', colorRejected, 'hittest', 'off');
            end
            if (isempty(hLinePrevThr) || ~ishandle(hLinePrevThr))
                hLinePrevThr = line('parent',hAxePrevOverlap,'xdata', [1 nbOfFrames+1], 'ydata', 0.01*[measures.prevThr(currentWorm) measures.prevThr(currentWorm)], 'color', 'r', 'hittest', 'off');
            else
                set(hLinePrevThr, 'ydata', 0.01*[measures.prevThr(currentWorm) measures.prevThr(currentWorm)]);
            end
            stairs(hAxePrevOverlap, listOfWorms.overlapPrev(currentWorm,:), 'hittest', 'off');
            axis(hAxePrevOverlap,[1 nbOfFrames+1 0 1]);
            grid(hAxePrevOverlap,'on')
            set(hAxePrevOverlap, 'XTickLabel', [], 'TickLength', [0 0], 'YTick',[0 0.5 1],'YTickLabel', ['  0'; ' 50'; '100'], 'color', 'w', 'ButtonDownFcn', @selectFrameByClick);
            % -------------------
            % Display the lost frames
            % -------------------
            cla(hAxeLost)
            hold(hAxeLost, 'on');
            for ff = find(listOfWorms.lost(currentWorm,:))
                rectangle('parent',hAxeLost, 'position', [ff, 0, 1, 1], 'FaceColor', colorRejected, 'edgecolor', colorRejected, 'hittest', 'off');
            end
            axis(hAxeLost,[1 nbOfFrames+1 0 1]);
            grid(hAxeLost,'on')
            set(hAxeLost, 'XTickLabel', [], 'TickLength', [0 0],'YTick',[0 1], 'YTickLabel', [], 'color', 'w', 'ButtonDownFcn', @selectFrameByClick);
            % -------------------
            % Display the overlap with other worms
            % -------------------
            cla(hAxeOverlap)
            hold(hAxeOverlap, 'on');
            for ff = find(listOfWorms.overlapped(currentWorm,:))
                rectangle('parent',hAxeOverlap, 'position', [ff, 0, 1, 1], 'FaceColor', colorRejected, 'edgecolor', colorRejected, 'hittest', 'off');
            end
            axis(hAxeOverlap,[1 nbOfFrames+1 0 1]);
            grid(hAxeOverlap,'on')
            set(hAxeOverlap, 'XTickLabel', [], 'TickLength', [0 0],'YTick',[0 1], 'YTickLabel', [], 'color', 'w', 'ButtonDownFcn', @selectFrameByClick);
            % -------------------
            % Display the end of self-overlap
            % -------------------
            cla(hAxeSelfOverlap)
            hold(hAxeSelfOverlap, 'on');
            for ff = find(tmpAfterSelfOverlap(currentWorm,:))
                rectangle('parent',hAxeSelfOverlap, 'position', [ff, 0, 1, 1], 'FaceColor', colorRejected, 'edgecolor', colorRejected, 'hittest', 'off');
            end
            axis(hAxeSelfOverlap,[1 nbOfFrames+1 0 1]);
            grid(hAxeSelfOverlap,'on')
            set(hAxeSelfOverlap, 'XTickLabel', [], 'TickLength', [0 0],'YTick',[0 1], 'YTickLabel', [], 'color', 'w', 'ButtonDownFcn', @selectFrameByClick);
            % -------------------
            % Display the length
            % -------------------
            cla(hAxeLength)
            stairs(hAxeLength, listOfWorms.lengthWorms(currentWorm,:), 'hittest', 'off');
            tmp = axis(hAxeLength) + [0 0 0 1];
            axis(hAxeLength,[1 nbOfFrames+1 0 tmp(4)]);
            hold(hAxeLength,'on')
            for ff = find(listOfWorms.outOfLengths(currentWorm,:))
                rectangle('parent',hAxeLength, 'position', [ff, 0, 1, tmp(4)], 'FaceColor', colorRejected, 'edgecolor', colorRejected, 'hittest', 'off');
            end
            if (isempty(hLineHighThr) || ~ishandle(hLineHighThr))
                hLineHighThr = line('parent',hAxeLength,'xdata', [tmp(1) tmp(2)], 'ydata', [measures.highThr(currentWorm) measures.highThr(currentWorm)], 'color', 'r', 'hittest', 'off');
            else
                set(hLineHighThr, 'xdata', [tmp(1) tmp(2)], 'ydata', [measures.highThr(currentWorm) measures.highThr(currentWorm)]);
            end
            if (isempty(hLineLowThr) || ~ishandle(hLineLowThr))
                hLineLowThr = line('parent',hAxeLength,'xdata', [tmp(1) tmp(2)], 'ydata', [measures.lowThr(currentWorm) measures.lowThr(currentWorm)], 'color', 'r', 'hittest', 'off');
            else
                set(hLineLowThr, 'xdata', [tmp(1) tmp(2)], 'ydata', [measures.lowThr(currentWorm) measures.lowThr(currentWorm)]);
            end
            stairs(hAxeLength, listOfWorms.lengthWorms(currentWorm,:),'-k', 'hittest', 'off');
            hold(hAxeLength,'off')
            grid(hAxeLength,'on')
            set(hAxeLength, 'TickLength', [0 0], 'ButtonDownFcn', @selectFrameByClick)
            % -------------------
            % Display the current frame location on all graphs
            % -------------------
            tmp = axis(hAxeLength);
            hRectCurrentFrame(1) = rectangle('parent',hAxeLength,      'position', [currentFrame, tmp(3), 1, tmp(4)-tmp(3)], 'FaceColor', 'none', 'edgecolor', 'k', 'LineStyle', '--', 'hittest', 'off');
            hRectCurrentFrame(2) = rectangle('parent',hAxeOverlap,     'position', [currentFrame, 0, 1, 1], 'FaceColor', 'none', 'edgecolor', 'k', 'LineStyle', '--', 'hittest', 'off');
            hRectCurrentFrame(3) = rectangle('parent',hAxeLost,        'position', [currentFrame, 0, 1, 1], 'FaceColor', 'none', 'edgecolor', 'k', 'LineStyle', '--', 'hittest', 'off');
            hRectCurrentFrame(4) = rectangle('parent',hAxePrevOverlap, 'position', [currentFrame, 0, 1, 1], 'FaceColor', 'none', 'edgecolor', 'k', 'LineStyle', '--', 'hittest', 'off');
            hRectCurrentFrame(5) = rectangle('parent',hAxeValid,       'position', [currentFrame, 0, 1, 1], 'FaceColor', 'none', 'edgecolor', 'k', 'LineStyle', '--', 'hittest', 'off');
            hRectCurrentFrame(6) = rectangle('parent',hAxeSelfOverlap, 'position', [currentFrame, 0, 1, 1], 'FaceColor', 'none', 'edgecolor', 'k', 'LineStyle', '--', 'hittest', 'off');
            hRectCurrentFrame(7) = rectangle('parent',hAxeGlare,       'position', [currentFrame, 0, 1, 1], 'FaceColor', 'none', 'edgecolor', 'k', 'LineStyle', '--', 'hittest', 'off');
            % -------------------
            % Update the display
            % -------------------
            displayCurrentFrame
            % -------------------
            % Update the number of valid frames
            % -------------------
            totalValid = sum(listOfWorms.valid(currentWorm,:));
            fracValid = 100*totalValid/nbOfFrames;
            set(txtValid, 'string', ['Valid frames: ', num2str(totalValid), ' / ', num2str(nbOfFrames), ' = ', sprintf('%.1f', fracValid), ' %']);
            set(txtReject, 'string', ['Rejected frames: ', num2str(nbOfFrames-totalValid), ' / ', num2str(nbOfFrames), ' = ', sprintf('%.1f', 100-fracValid), ' %']);
            % -------------------
            % Display the trajectory of the current worm
            % -------------------
            if flagShowTrajectory && ~isempty(centerMovedSignificantly) && ~isempty(listOfWorms.positionCenterX)
                hold(hAxeAllVideo,'on')
                if isempty(hTraj) || ~ishandle(hTraj)
                    hTraj = plot(hAxeAllVideo, listOfWorms.positionCenterX(currentWorm,centerMovedSignificantly(currentWorm,:) & listOfWorms.valid(currentWorm,:)),...
                        listOfWorms.positionCenterY(currentWorm,centerMovedSignificantly(currentWorm,:)& listOfWorms.valid(currentWorm,:)),'-','color',colorTrajectory);
                else
                    set(hTraj,'xdata', listOfWorms.positionCenterX(currentWorm,centerMovedSignificantly(currentWorm,:)& listOfWorms.valid(currentWorm,:)),...
                        'ydata', listOfWorms.positionCenterY(currentWorm,centerMovedSignificantly(currentWorm,:)& listOfWorms.valid(currentWorm,:)));
                end
                hold(hAxeAllVideo,'off')
            end
        end
    end

% ************************
%      THRESHOLD SELECTION
% ************************

% ============
% SELECT A THRESHOLD
% ============
    function selectThreshold(hObject,eventdata) %#ok<INUSD>
        if currentVideo == 0
            return
        end
        % ------------
        % Length: high threshold
        % ------------
        if hObject == btnHighThrUp
            measures.highThr(currentWorm) = measures.highThr(currentWorm) + 1;
        elseif hObject == btnHighThrDown
            measures.highThr(currentWorm) = max(0, measures.highThr(currentWorm)-1);
        elseif hObject == btnHighThrDefault
            measures.highThr(currentWorm) = measures.highThrDef(currentWorm);
        elseif hObject == editHighThr
            newCurrent = round(str2double(get(editHighThr, 'string')));
            if ~isnan(newCurrent) && newCurrent >= 0
                measures.highThr(currentWorm) = newCurrent;
            end
        end
        set(editHighThr, 'string', int2str(measures.highThr(currentWorm)));
        % ------------
        % Length: low threshold
        % ------------
        if hObject == btnLowThrUp
            measures.lowThr(currentWorm) = measures.lowThr(currentWorm) + 1;
        elseif hObject == btnLowThrDown
            measures.lowThr(currentWorm) = max(0, measures.lowThr(currentWorm)-1);
        elseif hObject == btnLowThrDefault
            measures.lowThr(currentWorm) = measures.lowThrDef(currentWorm);
        elseif hObject == editLowThr
            newCurrent = round(str2double(get(editLowThr, 'string')));
            if ~isnan(newCurrent) && newCurrent >= 0
                measures.lowThr(currentWorm) = newCurrent;
            end
        end
        set(editLowThr, 'string', int2str(measures.lowThr(currentWorm)));
        listOfWorms.outOfLengths(currentWorm,:) =...
            (listOfWorms.lengthWorms(currentWorm,:) > measures.highThr(currentWorm))...
            | (listOfWorms.lengthWorms(currentWorm,:) < measures.lowThr(currentWorm));
        % ------------
        % Previous overlap threshold
        % ------------
        if hObject == btnPrevThrUp
            measures.prevThr(currentWorm) = min(100,measures.prevThr(currentWorm) + 1);
        elseif hObject == btnPrevThrDown
            measures.prevThr(currentWorm) = max(0, measures.prevThr(currentWorm)-1);
        elseif hObject == btnPrevThrDefault
            measures.prevThr(currentWorm) = measures.prevThrDef(currentWorm);
        elseif hObject == editPrevThr
            newCurrent = round(str2double(get(editPrevThr, 'string')));
            if ~isnan(newCurrent) && newCurrent >= 0 && newCurrent <= 100
                measures.prevThr(currentWorm) = newCurrent;
            end
        end
        listOfWorms.outOfPrevious(currentWorm,:) = (listOfWorms.overlapPrev(currentWorm,:)*100 < measures.prevThr(currentWorm));
        set(editPrevThr, 'string', int2str(measures.prevThr(currentWorm)));
        % ------------
        % Update the display
        % ------------
        computeBlockSeparatorsAndValidity
        selectWorm
    end


% ************************
%      WORM VALIDATION
% ************************

% ============
% VALIDATE A WORM
% ============
    function validateWorm(hObject,eventdata) %#ok<INUSD>
        if currentVideo == 0
            return
        end
        measures.status{currentWorm} = 'valid';
        tmp = get(listWorms,'string');
        tmp{currentWorm} = ['Worm ', num2str(currentWorm), ' : ', measures.status{currentWorm}];
        set(listWorms,'string', tmp);
    end

% ============
% REJECT A WORM
% ============
    function rejectWorm(hObject,eventdata) %#ok<INUSD>
        if currentVideo == 0
            return
        end
        measures.status{currentWorm} = 'rejected';
        tmp = get(listWorms,'string');
        tmp{currentWorm} = ['Worm ', num2str(currentWorm), ' : ', measures.status{currentWorm}];
        set(listWorms,'string', tmp);
    end




% ************************
%      GUI BUILDING AND FILLING
% ************************

% ============
% GET ALL THE DISTINCT VALUES TO DISPLAY IN EVERY FILTER LIST
% ============
    function populateFilters
        listToShow = 1:length(fileDB);
        fields = fieldnames(flt);
        for field = 1:length(fields)
            setappdata(flt.(fields{field}),'field',fields{field});
            newListTmp = {};
            flagWell = strcmp('well',fields{field});
            for vid = listToShow
                if flagWell
                    value = num2str(~isempty(fileDB(vid).(fields{field})));
                elseif ~ischar(fileDB(vid).(fields{field}))
                    value = num2str(fileDB(vid).(fields{field}));
                else
                    value = fileDB(vid).(fields{field});
                end
                cand = length(newListTmp);
                while (cand >= 1) && ~strcmpi(value,newListTmp{cand})
                    cand = cand - 1;
                end
                if cand < 1
                    newListTmp{end+1} = value; %#ok<AGROW>
                end
            end
            newListTmp = [['All (',num2str(length(newListTmp)) ,' values)'], sort(newListTmp)];
            set(flt.(fields{field}),'string',newListTmp);
        end
        for field = 1:length(fields)
            set(flt.(fields{field}),'value', filterSelection.(fields{field}));
        end
        setFilteredList
    end

% ============
% BUILD THE LIST OF VIDEOS TO SHOW, BASED ON THE SELECTED FILTERS
% ============
    function setFilteredList(hObject,eventdata) %#ok<INUSD>
        newListTmp = cell(length(fileDB),1);
        currentVal = 0;
        listVideosIdx = zeros(1,length(fileDB));
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
                newListTmp{currentVal} = fileDB(vv).name;
                listVideosIdx(currentVal) = vv;
            end
        end
        listVideosIdx = listVideosIdx(1:currentVal);
        set(listVideos, 'string', newListTmp(1:currentVal,:), 'value',1);
        set(txtListVideos,'string', ['Select a video (',num2str(length(listVideosIdx)),' filtered)']);
        checkSelectedVideo
    end

% ============
% DISPLAY THE AXIS AND THE SLIDER
% ============
% ------------
% Set the position of the main panel based on the sliders values
% ------------
    function setMainPanelPositionBySliders(hObject,eventdata) %#ok<INUSD>
        newPos = get(mainPanel,'position');
        newPos(1) = 5 - get(sliderHoriz,'value');
        newPos(2) = -5 - get(sliderVert,'value');
        set(mainPanel,'position',newPos);
    end

% ------------
% Update the sliders positions when the main figure is resized
% ------------
    function resizeMainFigure(hObject,eventdata) %#ok<INUSD>
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

% ============
% CLOSE THE MAIN GUI
% ============
    function closeWindow(hObject,eventdata)
        set(mainFigure,'visible','off');
        if flagShowCurvaturePlots
            delete(hPlots);
            if flagPlotCurvOnly
                delete(hOnlyCurv);
            end
        end
        delete(mainFigure);
    end

    function [ temporalFreq , spatialFreq , dynamicAmplitude , attenuation , curvature ] = CSTComputeMeasuresFromBody(skel, flagSmoothCurvature, flagSuperSampleCurvature, validity, returnOnlyCurvature)
        if nargin < 2
            flagSmoothCurvature = false;
        end
        if nargin < 3
            flagSuperSampleCurvature = false;
        end
        if nargin < 4
            validity = true(length(skel),1);
        end
        if nargin < 5
            returnOnlyCurvature = false;
        end
        % Parameters for the measure of timePeriod and phaseFactor
        nbOfTimeIntervals = length(skel);
        listOfFourTransformDurations = [32,64,128];
        minFreq = 0;
        flagInterpolateSpace = true;
        % Input data
        nbOfFrames = length(skel);
        nbOfPoints = length(skel{1})-1;
        % Compute the curvature
        curvature = zeros(nbOfFrames, nbOfPoints);
        for ff = 1:nbOfFrames
            curvature(ff,:) = CSTcomputeCurvatureFromBody(skel{ff}(:,1:end-1));
        end
        nbOfMissingFramesMaxToRecover = 10;
        if ~isempty(find(~validity(2:end-1) & validity(1:end-2),1))
            for fff = (1+find(~validity(2:end-1) & validity(1:end-2)))
                % fff is an invalid frame and fff-1 is a valid frame
                nbOfInvalidFrames = 1;
                while ( fff + nbOfInvalidFrames <= nbOfFrames) && ( ~validity(fff+nbOfInvalidFrames))
                    nbOfInvalidFrames = nbOfInvalidFrames + 1;
                end
                if fff + nbOfInvalidFrames <= nbOfFrames && nbOfInvalidFrames < nbOfMissingFramesMaxToRecover
                    % Interpolate the missing values
                    nextValidFrame = fff + nbOfInvalidFrames;
                    newValues = interp2([1:nbOfPoints; 1:nbOfPoints], repmat([fff-1; nextValidFrame],1,nbOfPoints), ...
                        curvature([fff-1, nextValidFrame],:)...
                        , repmat((1:nbOfPoints),nextValidFrame-fff+2,1), repmat((fff-1:nextValidFrame)',1,nbOfPoints));
                    validity(fff:nextValidFrame) = true;
                    curvature(fff-1:nextValidFrame, :) = newValues;
                end
            end
        end
        % Smooth the curvature values in space and time
        if flagSmoothCurvature
            curvature(1,2:end-1) = 1/6 *...
                (curvature(1 ,1:end-2) + curvature(1 ,2:end-1) + curvature(1 ,3:end) + ...
                curvature(2 ,1:end-2) + curvature(2 ,2:end-1) + curvature(2 ,3:end) );
            curvature(end,2:end-1) = 1/6 *...
                (curvature(end-1 ,1:end-2) + curvature(end-1,2:end-1) + curvature(end-1,3:end) + ...
                curvature(end   ,1:end-2) + curvature(end  ,2:end-1) + curvature(end  ,3:end) );
            curvature(2:end-1,end ) = 1/6 * ...
                (curvature(1:end-2,end-1) + curvature(1:end-2,end) + ...
                curvature(2:end-1,end-1) + curvature(2:end-1,end) + ...
                curvature(3:end  ,end-1) + curvature(3:end  ,end) );
            curvature(2:end-1, 1 ) = 1/6 * ...
                (curvature(1:end-2,1) + curvature(1:end-2,2) + ...
                curvature(2:end-1,1) + curvature(2:end-1,2) + ...
                curvature(3:end  ,1) + curvature(3:end  ,2) );
            curvature(2:end-1,2:end-1) = 1/9 *...
                (curvature(1:end-2,1:end-2) + curvature(1:end-2,2:end-1) + curvature(1:end-2,3:end) + ...
                curvature(2:end-1,1:end-2) + curvature(2:end-1,2:end-1) + curvature(2:end-1,3:end) + ...
                curvature(3:end  ,1:end-2) + curvature(3:end  ,2:end-1) + curvature(3:end,  3:end) );
        end
        curvature(~validity,:) = NaN;
        % Supersample the values
        if flagSuperSampleCurvature
            curvature = interp2(curvature,'linear');
            validityTmp = (interp2([validity;validity]+0.0,'linear') >= 1);
            validity = validityTmp(1,:);
            nbOfFramesSup = size(curvature,1);
            nbOfPoints = size(curvature,2);
        end
        if returnOnlyCurvature
            temporalFreq =[];
            spatialFreq =[];
            dynamicAmplitude =[];
            attenuation =[];
            return;
        end
        fftw('planner', 'exhaustive');
        nbOfFourTransformDurations = length(listOfFourTransformDurations);
        temporalFreq = zeros(1, nbOfFramesSup);
        spatialFreq = zeros(1, nbOfFramesSup);
        nbOfMeasuresPerFrame = zeros(1, nbOfFramesSup);
        framesMeasured = fix(linspace(1, nbOfFramesSup, nbOfTimeIntervals));
        startingPoints = zeros(nbOfTimeIntervals,nbOfFourTransformDurations);
        endingPoints = zeros(nbOfTimeIntervals,nbOfFourTransformDurations);
        for idxTimeInter = 1:nbOfTimeIntervals
            for idxDuration = 1:nbOfFourTransformDurations
                startingPoints(idxTimeInter, idxDuration) = max(1, min(nbOfFramesSup, framesMeasured(idxTimeInter) - listOfFourTransformDurations(idxDuration)/2));
                endingPoints(idxTimeInter, idxDuration) = max(1, min(nbOfFramesSup, framesMeasured(idxTimeInter) + listOfFourTransformDurations(idxDuration)/2));
            end
        end
        nbOfPoints = nbOfPoints-2;
        for idxTimeInter = 1:nbOfTimeIntervals
            flagAtLeastOneMeasure = false;
            finalFourierTransform = zeros(max(listOfFourTransformDurations)/2, nbOfPoints );
            freqMaxFinal = size(finalFourierTransform,1)-1;
            for idxDuration = 1:nbOfFourTransformDurations
                rangeDuration = startingPoints(idxTimeInter, idxDuration):endingPoints(idxTimeInter, idxDuration);
                if all(validity(rangeDuration))
                    flagAtLeastOneMeasure = true;
                    % substract the average value first
                    fourierTmp = abs(fft2(curvature(rangeDuration,3:end) - mean(mean(curvature(rangeDuration,3:end))))) * 4 / (nbOfPoints * length(rangeDuration));
                    [tt,ss] = meshgrid(1:size(fourierTmp,1),1:size(fourierTmp,2));
                    fourierTmp = fftshift(fourierTmp);
                    ttshifted = fftshift(tt);
                    newCenterTime = find(ttshifted(1,:)==1);
                    ssshifted = fftshift(ss);
                    newCenterSpace = find(ssshifted(:,1)==1);
                    % Remove negative time frequencies
                    fourierTransform = fourierTmp(newCenterTime:end,:);
                    freqMaxCurrent = size(fourierTransform,1)-1;
                    fourierTransformRescaled = interp2((1:nbOfPoints), (0:freqMaxCurrent)/freqMaxCurrent , fourierTransform, (1:nbOfPoints)' , (0:freqMaxFinal)/freqMaxFinal);
                    finalFourierTransform = finalFourierTransform + fourierTransformRescaled / nbOfFourTransformDurations ;
                end
            end
            if flagAtLeastOneMeasure
                [spaceFreqMaximaValues, timeFreqMaximaIndices] = max(finalFourierTransform((minFreq+1):end,:));
                [~ , spaceFreqMaximumIndex] = max(spaceFreqMaximaValues);
                timeFreqMaximumIndex = minFreq + timeFreqMaximaIndices(spaceFreqMaximumIndex);
                rangeTime = timeFreqMaximumIndex + (-1:1);
                rangeTime(rangeTime <= 0) = [];
                rangeTime(rangeTime > size(finalFourierTransform,1)) = [];
                if flagInterpolateSpace
                    rangeSpace = spaceFreqMaximumIndex + (-1:2:1);
                else
                    rangeSpace = spaceFreqMaximumIndex; %#ok<UNRCH>
                end
                rangeSpace(rangeSpace <= 0) = [];
                rangeSpace(rangeSpace > size(finalFourierTransform,2)) = [];
                sample = finalFourierTransform(rangeTime , rangeSpace);
                sample = sample / sum(sample(:));
                timeFreqMeasured = sum(rangeTime .* sum(sample,2)');
                spaceFreqMeasured = sum(rangeSpace .* sum(sample,1));
                rangeMeasured = startingPoints(idxTimeInter, 1):endingPoints(idxTimeInter, 1);
                temporalFreq(rangeMeasured)  = temporalFreq(rangeMeasured) + (timeFreqMeasured - 1) / max(listOfFourTransformDurations);
                spatialFreq(rangeMeasured)  = spatialFreq(rangeMeasured) + (spaceFreqMeasured - newCenterSpace);
                nbOfMeasuresPerFrame(rangeMeasured) = nbOfMeasuresPerFrame(rangeMeasured) + 1;
            end
        end
        temporalFreq = temporalFreq ./ nbOfMeasuresPerFrame;
        spatialFreq = - spatialFreq ./ nbOfMeasuresPerFrame;
        if flagSuperSampleCurvature
            temporalFreq = temporalFreq * 2;
        end
        % -------
        % Ranges
        % -------
        headIndices = 3:fix(0.25 * nbOfPoints); %first 2 values are 0
        tailIndices = fix(0.75 * nbOfPoints):nbOfPoints;
        dynamicAmplitude = zeros(1, nbOfFramesSup);
        attenuation = zeros(1, nbOfFramesSup);
        atteSmooth = zeros(1, nbOfFramesSup);
        dynaSmooth = zeros(1, nbOfFramesSup);
        for ff = 1:nbOfFramesSup
            if temporalFreq(ff) > 0
                period = max(3,min(50,fix(1/temporalFreq(ff))));
            else
                period = 50;
            end
            timeRange = max(1, min(nbOfFramesSup, ff-period)):max(1, min(nbOfFramesSup, ff+period));
            if any(validity(timeRange))
                dynamicAmplitude(ff) = max( max(curvature(timeRange,3:nbOfPoints)) - min(curvature(timeRange,3:nbOfPoints)));
                rangeHeadTmp = max( max(curvature(timeRange,headIndices)) - min(curvature(timeRange,headIndices)) , [] ,2);
                rangeMidTail = min( max(curvature(timeRange,tailIndices)) - min(curvature(timeRange,tailIndices)) , [] ,2);
                if rangeHeadTmp > 0
                    attenuation(ff) = (1 - rangeMidTail / rangeHeadTmp);
                else
                    attenuation(ff) = 0;
                end
            end
        end
        for ff = 1:nbOfFramesSup
            if temporalFreq(ff) > 0
                period = max(3,min(50,fix(1/temporalFreq(ff))));
            else
                period = 50;
            end
            timeRange = max(1, min(nbOfFramesSup, ff-period)):max(1, min(nbOfFramesSup, ff+period));
            atteSmooth(ff) = mean(attenuation(timeRange));
            dynaSmooth(ff) = mean(dynamicAmplitude(timeRange));
        end
        attenuation = atteSmooth;
        dynamicAmplitude = dynaSmooth;
        function kappa = CSTcomputeCurvatureFromBody(body)
            norms = hypot(body(1,2:end)-body(1,1:end-1), body(2,2:end)-body(2,1:end-1));
            norms(end+1) = norms(end);
            dx = (body(1,[2,2:end]) - body(1,[1,1:(end-1)])) ./ norms([1,1:end-1]);
            dy = (body(2,[2,2:end]) - body(2,[1,1:(end-1)])) ./ norms([1,1:end-1]);
            d2x = dx([2,2:end])-dx([1,1:(end-1)]);
            d2y = dy([2,2:end])-dy([1,1:(end-1)]);
            kappa = ( dx .* d2y - dy .* d2x ) ./ sqrt( ( dx .^2 + dy .^2 ) .^3 );
        end
    end

end
