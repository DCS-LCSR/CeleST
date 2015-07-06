function CSTShowGraphs
% Copyright (c) 2013 Rutgers
% Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
% The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
% THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.


global fileDB samplesIdx mainPnlW samplesDef measures listOfMeasures listOfButtons wormIndices flagRobustness fileToLog filenames;

listColormaps = {'hot', 'jet', 'cool', 'pink', 'copper', 'bone', 'gray', 'spring', 'summer', 'autumn','winter'};
        
listOfButtons = {'Wave Init Rate', 'Body Wave Number', 'Asymmetry', 'Stretch', 'Attenuation','Reverse Swim', ...
            'Curling', 'Travel Speed', 'Brush Stroke', 'Activity Index'...
            };
        
listOfMeasures = {'Wave_Initiation_Rate_Median', 'Body_Wave_Number_Median', 'Asymmetry_Median', 'Stretch_Median', 'Attenuation_Median', 'Reverse_Swimming', ...
            'Curling', 'Traveling_Speed_Mean', 'Brush_Stroke_Median', 'Activity_Index_Median'...
            };

listOfLabels =listOfButtons;

measuresToMultByMmPerPxl = {};
measuresToMultByFramesPerSec = {};
measuresToMultBySecPerMin = {};
measuresToMultByDegPerRadian = {};

nbOfMeasures = length(listOfMeasures);
nbOfSamples = length(samplesIdx);
totalVideos = sum(sum(cellfun(@length, samplesIdx)));
xAxisCommon = [0 1];
wormIndices = cell(1,0);
listOfStats = {'nbDataPoints', 'mean', 'std', 'sem', 'cimean', 'min', 'quart1', 'median', 'quart3', 'max', 'histoBounds', 'histoValues', 'raw'};
nbOfStats = length(listOfStats);

numberOfTopWorms = 6000;

for mm = 1:nbOfMeasures
    for ss = 1:nbOfStats
        measures.(listOfMeasures{mm}).(listOfStats{ss}) = [];
    end
end

histoSteps = 200;
statSelected = 1;
samplesListSelection = ones(1,nbOfSamples);
wormListSelection = ones(1,nbOfSamples);

% ============
% CREATE THE INTERFACE
% ============
mainPnlH = max(900, 130+150*nbOfSamples);
% ----------
% Main figure and sliders
% ----------
scrsz = get(0,'ScreenSize');
mainW = min(mainPnlW, scrsz(3) - 10);
mainH = min(mainPnlH, scrsz(4) - 70);
% mainPanelPosition = [2, mainH-mainPnlH-2, 1680, 900];
mainPanelPosition = [2, mainH-mainPnlH-2, mainPnlW, mainPnlH];
mainFigure = figure('Visible','off','Position',[5,40,mainW,mainH],'Name','CeleST: Statistics display and export - Select samples, videos or worms to display and export all measurements','numbertitle','off', 'menubar', 'none', 'resizefcn', @resizeMainFigure);
mainPanel = uipanel('parent', mainFigure,'BorderType', 'none','units','pixels', 'position', mainPanelPosition);
sliderHoriz = uicontrol('parent',mainFigure,'style','slider','position',[0 0 mainW-20 20],'max', 1,'min',0, 'value',0,'callback',@setMainPanelPositionBySliders);
sliderVert = uicontrol('parent',mainFigure,'style','slider','position',[mainW-20 20 20 mainH-20],'max', max(1,-mainPanelPosition(2)),'min',0, 'value',max(1,-mainPanelPosition(2)),'callback',@setMainPanelPositionBySliders);
set(mainFigure, 'color', get(mainPanel,'backgroundcolor'));

pnlTop = uipanel('parent', mainPanel , 'BorderType', 'none','units','pixels', 'position', [5 mainPnlH-100 mainPnlW-30 100]);
uicontrol('parent',pnlTop,'style','pushbutton', 'string', 'Close', 'position', [5 75 100 30], 'callback', @closeWindow);
uicontrol('parent',pnlTop,'style','pushbutton', 'string', 'Export...', 'position', [115 75 100 30], 'callback', @exportAll);
uicontrol('parent',pnlTop,'style','pushbutton', 'string', 'Tests...', 'position', [225 75 100 30], 'callback', @openTests);
btnMeas = zeros(1, nbOfMeasures);
for it = 1:nbOfMeasures
    btnMeas(it) = uicontrol('parent',pnlTop,'style','togglebutton', 'string', listOfButtons{it}, 'position', [220+120*ceil(it/2) 45+30*rem(it,2) 110 30], 'callback', @measureSelected);
end
% -----------
% Set the first button to selected
% -----------
set(btnMeas(statSelected),'value',1);

uicontrol('parent',pnlTop,'style','pushbutton', 'string', '2D histograms', 'position', [940 60 100 30], 'callback', @measure2DSelected);

% -----------
% Label of the graph and axis values
% -----------
hLabel = uicontrol('parent', pnlTop, 'style', 'text', 'FontWeight', 'bold', 'HorizontalAlignment', 'center', 'string', '', 'position', [330 5 1300 20]);

% -----------
% Number of usable worms
% -----------
uicontrol('parent', pnlTop, 'style', 'text', 'HorizontalAlignment', 'left', 'string', '# of worms:', 'position', [5 10 200 15]);
hEditNumberOfTopWorms = uicontrol('parent', pnlTop, 'style', 'edit', 'string', num2str(numberOfTopWorms), 'position', [125 6 50 25], 'callback', @setNumberOfTopWorms);

% -----------
% Colormap and number of bins
% -----------
uicontrol('parent', pnlTop, 'style', 'text', 'HorizontalAlignment', 'left', 'string', '# of histogram bins:', 'position', [5 30 200 15]);
hEditBins = uicontrol('parent', pnlTop, 'style', 'edit', 'string', num2str(histoSteps), 'position', [125 26 50 25], 'callback', @setNumberBins);
uicontrol('parent', pnlTop, 'style', 'text', 'HorizontalAlignment', 'left', 'string', 'Colors:', 'position', [5 52 150 15]);
idxColormap = 1;
currentColormap = colormap(listColormaps{idxColormap});
hPopColormap = uicontrol('parent', pnlTop, 'style', 'popupmenu', 'string', listColormaps,'value', idxColormap, 'position', [55 44 100 25], 'callback', @setColormap);
nbPxl = 100;
uicontrol('parent', pnlTop, 'style', 'text', 'HorizontalAlignment', 'left', 'string', 'low', 'position', [160 52 20 15]);
uicontrol('parent', pnlTop, 'style', 'text', 'HorizontalAlignment', 'left', 'string', 'high', 'position', [290 52 30 15]);
axeExample = axes('parent', mainPanel, 'units', 'pixels', 'position', [190 mainPnlH-100+50 100 20]);
imagesc(1:nbPxl, 'parent', axeExample)
set(axeExample,'xtick',[],'ytick',[]);


for sampTmp = 1:nbOfSamples
    hSamples.panel(sampTmp) = uipanel('parent', mainPanel,'units','pixels', 'position', [5 mainPnlH-100-sampTmp*150 mainPnlW-30 150]);
    listTmp = samplesDef([1,3:end],sampTmp);
    while isempty(listTmp{end})
        listTmp(end) = [];
    end
    % -----------
    % Popup lists of videos and worms within the sample
    % -----------
    hSamples.listVideos(sampTmp) = uicontrol('parent', hSamples.panel(sampTmp), 'style', 'popupmenu', 'string', listTmp,'value',1, 'position', [5 120 300 20], 'callback', @videoSelected);
    hSamples.listWoms(sampTmp) = uicontrol('parent', hSamples.panel(sampTmp), 'style', 'popupmenu', 'string', {''},'value',1, 'position', [55 95 150 20], 'enable', 'off', 'callback', @wormSelected);
    % -----------
    % Histogram
    % -----------
    hSamples.plotHisto(sampTmp) = axes('parent', mainPanel, 'units','pixels','position',[350 mainPnlH-100-sampTmp*150+95 mainPnlW-385 20],'xtick',[],'ytick',[],'color',[0.5 0.5 0.5],'XAxisLocation','top');
    uicontrol('parent', hSamples.panel(sampTmp), 'style', 'text', 'HorizontalAlignment', 'left', 'string', 'Number of data points:', 'position', [5 75 200 15]);
    hSamples.txtNbWorms(sampTmp) = uicontrol('parent', hSamples.panel(sampTmp), 'style', 'text', 'HorizontalAlignment', 'left', 'string', '000 ', 'position', [200 75 100 15]);
    % -----------
    % Quartiles
    % -----------
    uicontrol('parent', hSamples.panel(sampTmp), 'style', 'text', 'HorizontalAlignment', 'left', 'string', 'Quartiles:', 'position', [5 60 200 15]);
    hSamples.txtQuartiles(sampTmp) = uicontrol('parent', hSamples.panel(sampTmp), 'style', 'text', 'HorizontalAlignment', 'right', 'string', '0-25-50-75-100 ', 'position', [60 60 275 15]);
    hSamples.plotQuart(sampTmp) = axes('parent', mainPanel, 'units','pixels','position',[350 mainPnlH-100-sampTmp*150+50 mainPnlW-385 40],'xtick',[],'ytick',[]);
    % -----------
    % Mean and std
    % -----------
    hSamples.plotMean(sampTmp)  = axes('parent', mainPanel, 'units','pixels','position',[350 mainPnlH-100-sampTmp*150+5 mainPnlW-385 40],'xtick',[],'ytick',[]);
    uicontrol('parent', hSamples.panel(sampTmp), 'style', 'text', 'HorizontalAlignment', 'left', 'string', 'Mean +/- Standard error:', 'position', [5 35 200 15]);
    hSamples.txtMSE(sampTmp) = uicontrol('parent', hSamples.panel(sampTmp), 'style', 'text', 'HorizontalAlignment', 'left', 'string', '0.000 +/- 0.000 ', 'position', [200 35 125 15]);
    uicontrol('parent', hSamples.panel(sampTmp), 'style', 'text', 'HorizontalAlignment', 'left', 'string', 'Mean +/- 95% Conf. Interval:', 'position', [5 20 200 15]);
    hSamples.txtMCI(sampTmp) = uicontrol('parent', hSamples.panel(sampTmp), 'style', 'text', 'HorizontalAlignment', 'left', 'string', '0.000 +/- 0.000 ', 'position', [200 20 125 15]);
    uicontrol('parent', hSamples.panel(sampTmp), 'style', 'text', 'HorizontalAlignment', 'left', 'string', 'Mean +/- Standard deviation:', 'position', [5 5 200 15]);
    hSamples.txtMSD(sampTmp) = uicontrol('parent', hSamples.panel(sampTmp), 'style', 'text', 'HorizontalAlignment', 'left', 'string', '0.000 +/- 0.000 ', 'position', [200 5 125 15]);
end


% ============
% SHOW THE INTERFACE
% ============
set(mainFigure,'visible','on')
setMainPanelPositionBySliders
pause(0.1)
loadRawMeasures

% ------------
% Waiting for closure
% ------------
waitfor(mainFigure,'BeingDeleted','on');


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%            SUBFUNCTIONS
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    % =========
    % Close this window and exit the function.
    % =========
    function closeWindow(hObject,eventdata) %#ok<*INUSD>
        set(mainFigure,'Visible','off');
        delete(mainFigure);
    end

    % =========
    % Open the interface to select and display stat tests
    % =========
    function openTests(hObject,eventdata)
        set(mainFigure,'Visible','off');
        CSTShowAllStatTests
        set(mainFigure,'Visible','on');        
    end

    % =========
    % Export all data
    % =========
    function exportAll(hObject,eventdata)
        try
            defaultName = fullfile(filenames.export,['worm_data_',date,'.csv']);
            flagUserInput = true;
            if flagUserInput
                [csvFile,csvPath] = uiputfile('*.csv','Save to CSV file', defaultName);
                if ~csvPath % user pressed cancel
                    return
                end
                fileToWrite = fopen(fullfile(csvPath,csvFile),'a');
            else
                fileToWrite = fopen(defaultName,'a'); %#ok<UNRCH>
            end
            prevSelection = samplesListSelection;
            prevStat = statSelected;
            samplesListSelection(:) = 1;
            for statSelected = 1:nbOfMeasures %#ok<FXUP>
                showMeasures
            end
            output = ['Videos selected', sprintf('\n')];
            % List the samples and their contents
            for samp = 1:nbOfSamples
                output = [output, samplesDef{1,samp}]; %#ok<*AGROW>
                nbOfVideos = length(samplesIdx{samp});
                for vid = 1:nbOfVideos+1
                    output = [output, ' , ', samplesDef{vid+1,samp}];
                end
                output = [output, sprintf('\n')];
            end
            
            output = [output, sprintf(',\n\n\n'), 'Statistics , number of data points, mean , standard error of the mean , 95%% confidence interval around the mean , standard deviation , minimum value , first quartile , median , third quartile , maximum value', sprintf('\n\n')];
            % For each measure, list the samples, the videos and the stats
            for idx = 1:nbOfMeasures
                output = [output, sprintf(',\n'), listOfButtons{idx}, sprintf('\n')];
                for samp = 1:nbOfSamples
                    output = [output, samplesDef{1,samp}];
                    output = [output, ...
                        ' , ', sprintf('%f', measures.(listOfMeasures{idx}).nbDataPoints{samp}) , ...
                        ' , ', sprintf('%f', measures.(listOfMeasures{idx}).mean{samp}) , ...
                        ' , ', sprintf('%f', measures.(listOfMeasures{idx}).sem{samp}) , ...
                        ' , ', sprintf('%f', measures.(listOfMeasures{idx}).cimean{samp}) , ...
                        ' , ', sprintf('%f', measures.(listOfMeasures{idx}).std{samp}) , ...
                        ' , ', sprintf('%f', measures.(listOfMeasures{idx}).min{samp}) , ...
                        ' , ', sprintf('%f', measures.(listOfMeasures{idx}).quart1{samp}) , ...
                        ' , ', sprintf('%f', measures.(listOfMeasures{idx}).median{samp}) , ...
                        ' , ', sprintf('%f', measures.(listOfMeasures{idx}).quart3{samp}) , ...
                        ' , ', sprintf('%f', measures.(listOfMeasures{idx}).max{samp}) ...
                        ];
                    output = [output, sprintf('\n')];
                end
            end
            nbOfMeasures = length(listOfMeasures);
            nbOfSamples = length(samplesIdx);
            tableData = cell(2+(nbOfMeasures+1)*(nbOfSamples-1)-2, 1+4*(nbOfSamples-1));
            tableData{1,1} = 'p values';
            for head = 2:nbOfSamples
                tableData{1,4*(head-1)-1} = samplesDef{1,head};
            end
            for meas = 2:nbOfMeasures
                rawData = cell(1,nbOfSamples);
                for samp = 1:nbOfSamples
                    rawData{samp} = [];
                    for vid = 1:length(measures.(listOfMeasures{meas}).raw{samp})
                        rawData{samp} = [rawData{samp} ; measures.(listOfMeasures{meas}).raw{samp}{vid}];
                    end
                end
                for samp1 = 1:nbOfSamples-1
                    tableData{2+(nbOfMeasures+1)*(samp1-1), 1} = samplesDef{1,samp1};
                    tableData{2+(nbOfMeasures+1)*(samp1-1)+meas-1, 2} = listOfButtons{meas};
                    for samp2 = (1+samp1):nbOfSamples
                        tableData{2+(nbOfMeasures+1)*(samp1-1) , 3+4*(samp2-2)} = 'F test';
                        [~,pFtest] = vartest2(rawData{samp1},rawData{samp2},0.05, 'both');
                        tableData{2+(nbOfMeasures+1)*(samp1-1)+(meas-1) , 3+4*(samp2-2)} = sprintf('%.4f',pFtest);
                        
                        tableData{2+(nbOfMeasures+1)*(samp1-1) , 3+4*(samp2-2)+1} = 't test equal';
                        [~,pEqual] = ttest2(rawData{samp1},rawData{samp2},0.05, 'both','equal');
                        tableData{2+(nbOfMeasures+1)*(samp1-1)+(meas-1) , 3+4*(samp2-2)+1} = sprintf('%.4f',pEqual);
                        
                        tableData{2+(nbOfMeasures+1)*(samp1-1) , 3+4*(samp2-2)+2} = 't test diff.';
                        [~,pDiff] = ttest2(rawData{samp1},rawData{samp2},0.05, 'both','unequal');
                        tableData{2+(nbOfMeasures+1)*(samp1-1)+(meas-1) , 3+4*(samp2-2)+2} = sprintf('%.4f',pDiff);
                        
                    end
                end
            end
            output = [output, sprintf('\n\n\n')];
            for tmpRow = 1:size(tableData,1)
                for tmpCol = 1:size(tableData,2)
                    output = [output,tableData{tmpRow,tmpCol}, ' , '];
                end
                output = [output, sprintf('\n')];
            end
            
            output = [output, sprintf(',\n\n\n\n'), 'Data points', sprintf('\n\n\n')];
            % For each measure, list the samples, the videos and the values
            for idx = 1:nbOfMeasures
                output = [output, listOfButtons{idx}, sprintf('\n')];
                for samp = 1:nbOfSamples
                    output = [output, samplesDef{1,samp}];
                    nbOfVideos = length(samplesIdx{samp});
                    for vid = 1:nbOfVideos
                        newData = sprintf(', %f', measures.(listOfMeasures{idx}).raw{samp}{vid});
                        output = [output, newData(~isnan(newData))];
                    end
                    output = [output, sprintf('\n')];
                end
            end
            
            fprintf(fileToWrite,output);
            fclose(fileToWrite);
            samplesListSelection = prevSelection;
            statSelected = prevStat;
        catch em
            if flagRobustness
                fprintf(fileToLog, '***   There was an error writing export file \n');
                fprintf(fileToLog, [getReport(em, 'basic'),'\n']);
            else
                rethrow(em)
            end
        end
    end

    % =========
    % Change the colormap of all the window, based on what the user selected
    % =========
    function setColormap(hObject,eventdata)
        valueSelected = get(hPopColormap, 'value');
        if valueSelected <= 0
            % no change
            set(hPopColormap, 'value', idxColormap);
        else
            % change in selection
            idxColormap = valueSelected;
            currentColormap = colormap(listColormaps{idxColormap});
            colormap(axeExample, currentColormap);
            showMeasures
        end
    end

    % =========
    % Set the number of top worms
    % =========
    function setNumberOfTopWorms(hObject,eventdata)
        newnumber = round(str2double(get(hEditNumberOfTopWorms, 'string')));
        if ~isnan(newnumber) && newnumber >= 1
            numberOfTopWorms = newnumber;
            loadRawMeasures
        else
            set(hEditNumberOfTopWorms, 'string', num2str(histoSteps));
        end
    end

    % =========
    % Check that the number of bins entered by the user is a valid number
    % =========
    function setNumberBins(hObject,eventdata)
        newnumber = round(str2double(get(hEditBins, 'string')));
        if ~isnan(newnumber) && newnumber >= 5 && newnumber <= 500
            histoSteps = newnumber;
            showMeasures
        else
            set(hEditBins, 'string', num2str(histoSteps));
        end
    end

    % =========
    % Load the raw measures from the txt files, based on the videos selected within the samples
    % =========
    function loadRawMeasures(hObject,eventdata)
        if nargin <= 0 || isempty(measures.(listOfMeasures{statSelected}).raw)
            increm = 1/totalVideos;
            valWait = 0;
            hWait = waitbar(valWait, 'Loading measures...');
            for idx = 1:length(listOfMeasures)
                measures.(listOfMeasures{idx}).raw = cell(1,nbOfSamples);
            end
            wormIndices = cell(1,nbOfSamples);
            for samp = 1:nbOfSamples
                % load the data for each sample
                nbOfVideos = length(samplesIdx{samp});
                % Load the usabilities
                allUsab = [];
                allVids = [];
                allIdx = [];
                waitbar(valWait, hWait,['Loading usabilities for: ', samplesDef{1,samp}]);
                for vid = 1:nbOfVideos
                    [ measLoaded, wormIdx ] = CSTreadMeasuresFromTXT(fileDB(samplesIdx{samp}{vid}).name, false, {'usability'},true);
                    usabilities = measLoaded.usability;
                    nbOfPoints = length(usabilities);
                    allUsab = [allUsab ; usabilities(:) ];
                    allVids = [allVids ; samplesIdx{samp}{vid} * ones(nbOfPoints,1) ];
                    allIdx  = [ allIdx ; wormIdx(:) ];                   
                end
                % Sort the usabilities
                [~, idxsorted] = sort(allUsab, 'descend');
                % Find the indices to load
                allWormsToLoad = min(numberOfTopWorms, length(idxsorted));
                idxsorted = idxsorted(1:allWormsToLoad);
                videosToLoad = allVids(idxsorted);
                wormsToLoad = allIdx(idxsorted);
                % Re-load only the top worms
                waitbar(valWait, hWait,['Loading measures for: ', samplesDef{1,samp}]);
                for idx = 1:length(listOfMeasures)
                    measures.(listOfMeasures{idx}).raw{samp} = cell(1,nbOfVideos);
                end
                wormIndices{samp} = cell(1,nbOfVideos);
                for vid = 1:nbOfVideos
                    % check if video worth loading
                    flagOkToLoad = false;
                    for vidComp = 1:length(videosToLoad)
                        flagOkToLoad = flagOkToLoad || (videosToLoad(vidComp) == samplesIdx{samp}{vid});
                    end
                    flagOkToLoad = ~isempty(find(videosToLoad == samplesIdx{samp}{vid}, 1));
                    if flagOkToLoad
                        % load the data of each video
                        valWait = valWait + increm;
                        waitbar(valWait, hWait);
                        % check if worms worth keeping
                        wormsWorthKeeping = wormsToLoad(videosToLoad == samplesIdx{samp}{vid});
                        [measLoaded, ~] = CSTreadMeasuresFromTXT(fileDB(samplesIdx{samp}{vid}).name, false, listOfMeasures, true, wormsWorthKeeping);
                        wormIndices{samp}{vid} = wormsWorthKeeping;
                        for idx = 1:length(listOfMeasures)
                            if isfield(measLoaded, listOfMeasures{idx})
                                measures.(listOfMeasures{idx}).raw{samp}{vid} = measLoaded.(listOfMeasures{idx});
                            else
                                measures.(listOfMeasures{idx}).raw{samp}{vid} = NaN;
                            end
                        end
                        for idx = 1:length(measuresToMultByMmPerPxl)
                                measures.(measuresToMultByMmPerPxl{idx}).raw{samp}{vid} = measures.(measuresToMultByMmPerPxl{idx}).raw{samp}{vid} .* fileDB(samplesIdx{samp}{vid}).mm_per_pixel;
                        end
                        for idx = 1:length(measuresToMultByFramesPerSec)
                            measures.(measuresToMultByFramesPerSec{idx}).raw{samp}{vid} = measures.(measuresToMultByFramesPerSec{idx}).raw{samp}{vid} .* fileDB(samplesIdx{samp}{vid}).frames_per_second;
                        end
                        for idx = 1:length(measuresToMultBySecPerMin)
                            measures.(measuresToMultBySecPerMin{idx}).raw{samp}{vid} = measures.(measuresToMultBySecPerMin{idx}).raw{samp}{vid} .* 60;
                        end
                        for idx = 1:length(measuresToMultByDegPerRadian)
                            measures.(measuresToMultByDegPerRadian{idx}).raw{samp}{vid} = measures.(measuresToMultByDegPerRadian{idx}).raw{samp}{vid} .* 180 / pi;
                        end
                        if isfield(measures, 'distanceWhenReverse')
                            measures.('distanceWhenReverse').raw{samp}{vid}(measures.('distanceWhenReverse').raw{samp}{vid} < 0) = NaN;
                        end
                        if isfield(measures, 'BFthrashing')
                            measures.('BFthrashing').raw{samp}{vid}(measures.('BFthrashing').raw{samp}{vid} < 0) = NaN;
                            measures.('BFinflexion').raw{samp}{vid}(measures.('BFinflexion').raw{samp}{vid} < 0) = NaN;
                            measures.('BFsymmetry').raw{samp}{vid}(measures.('BFsymmetry').raw{samp}{vid} < 0) = NaN;
                            measures.('BFflexibility').raw{samp}{vid}(measures.('BFflexibility').raw{samp}{vid} < 0) = NaN;
                            measures.('Bthrashing').raw{samp}{vid}(measures.('Bthrashing').raw{samp}{vid} < 0) = NaN;
                            measures.('Bflexibility').raw{samp}{vid}(measures.('Bflexibility').raw{samp}{vid} < 0) = NaN;
                            measures.('Fthrashing').raw{samp}{vid}(measures.('Fthrashing').raw{samp}{vid} < 0) = NaN;
                            measures.('Fflexibility').raw{samp}{vid}(measures.('Fflexibility').raw{samp}{vid} < 0) = NaN;
                        end
                    end
                end
            end
            close(hWait);
        else
            % The data for the selected measure was already loaded, lazy list implementation
        end
        showMeasures
    end



    function measure2DSelected(hObject,eventdata)
        % Compute all measures
        hTmp2D = waitbar(0, 'Computing all measures...');
        for sss = 1:length(listOfMeasures)
            waitbar(sss/length(listOfMeasures), hTmp2D, ['Computing measure ', num2str(sss), ' / ', num2str(length(listOfMeasures))]);
            statSelected = sss;
            showMeasures;
        end
        close(hTmp2D);
        
        % Define the colorbars for histograms
        colorSteps = 100;
        histoSteps2D = 20;
        ramp = 1-linspace(0.01,1,colorSteps/2)';
        rampDark = 1-linspace(0.01,0.5,colorSteps/2)';
        zero = zeros(colorSteps/2,1);
        one = ones(colorSteps/2,1);
        colorsHisto{1} = [ ramp, ramp, one  ; zero, zero, rampDark];
        colorsHisto{2} = [ ramp, one,  one  ; zero, rampDark, rampDark];
        colorsHisto{3} = [ one,  ramp, ramp ; rampDark, zero, zero];
        colorsHisto{4} = [ one,  ramp, one  ; rampDark, zero, rampDark];
        colorsHisto{5} = [ ramp, one,  ramp ; zero, rampDark, zero];
        colorsHisto{6} = [ one,  one,  ramp ; rampDark, rampDark, zero];
        colorsHisto{5} = (colorsHisto{6} + colorsHisto{3})/2;
        colorsHisto{2} = (colorsHisto{2} + colorsHisto{5})/2;
        for other = 7:nbOfSamples
            colorsHisto{other} = [ one,  one,  ramp ; rampDark, rampDark, zero];
        end
        
        % Display the information for all selected samples
        sampleToShow = 1:nbOfSamples;
        nbBoxes = 10;
        mainHLocal = mainH;
        mainWLocal = mainW;
        subFig = figure('Position',[5,40,mainWLocal,mainHLocal],'Name','CeleST: 2D-graphs','numbertitle','off', 'color', get(mainPanel,'backgroundcolor'));
        hPlot2D = axes('parent', subFig, 'units','pixels','position',[340 80 mainWLocal-440 mainHLocal-100], 'color', [0.5 0.5 0.5]);
        for samps = sampleToShow
            uicontrol('parent', subFig, 'units', 'pixels', 'style', 'text', 'HorizontalAlignment', 'left', 'string', samplesDef(samplesListSelection(samps), samps), 'position', [10 mainHLocal-140-100*samps 200 20]);
            tmpAx = axes('parent', subFig, 'units', 'pixels', 'position', [10 mainHLocal-160-100*samps 200 20]);
            for bb = 1:nbBoxes
                fill(bb+[-1 -1 0 0],[0 1 1 0],colorsHisto{samps}(colorSteps/nbBoxes*bb,:),'parent', tmpAx);
                hold(tmpAx, 'on');
            end
            set(tmpAx,'xtick',[],'ytick',[]);
            uicontrol('parent', subFig, 'units', 'pixels', 'style', 'text', 'HorizontalAlignment', 'left', 'string', ' 1         samples in bin', 'position', [10 mainHLocal-180-100*samps 150 18]);
            hHistoMax(samps) = uicontrol('parent', subFig, 'units', 'pixels', 'style', 'text', 'HorizontalAlignment', 'center', 'string', '1', 'position', [190 mainHLocal-180-100*samps 20 18]);
        end
        
        uicontrol('parent', subFig,'style','pushbutton', 'string', 'Close', 'position', [10 mainHLocal-40 100 30], 'callback', @close2D);
        uicontrol('parent', subFig, 'style', 'text', 'HorizontalAlignment', 'left', 'string', 'Number of histogram bins:', 'position', [10 mainHLocal-200 200 20]);
        hEditBins2D = uicontrol('parent', subFig, 'style', 'edit', 'string', num2str(histoSteps2D), 'position', [175 mainHLocal-200 50 25], 'callback', @setNumberBins2D);
        
        statToShow = [1 2];
        uicontrol('parent', subFig, 'units', 'pixels', 'style', 'text', 'HorizontalAlignment', 'left', 'string', 'Measure on the X axis:', 'position', [10 mainHLocal-80 150 20]);
        hXMeasure = uicontrol('parent', subFig, 'style', 'popupmenu', 'string', listOfButtons,'value',statToShow(1), 'position', [10 mainHLocal-100 200 20], 'callback', @measSel);
        uicontrol('parent', subFig, 'units', 'pixels', 'style', 'text', 'HorizontalAlignment', 'left', 'string', 'Measure on the Y axis:', 'position', [10 mainHLocal-140 150 20]);
        hYMeasure = uicontrol('parent', subFig, 'style', 'popupmenu', 'string', listOfButtons,'value',statToShow(2), 'position', [10 mainHLocal-160 200 20], 'callback', @measSel);
        show2DPlot;
        function close2D(ha, hb)
            set(subFig,'Visible','off');
            delete(subFig);
        end
        function setNumberBins2D(hObject,eventdata)
            newnumber = round(str2double(get(hEditBins2D, 'string')));
            if ~isnan(newnumber) && newnumber >= 5 && newnumber <= 500
                histoSteps2D = newnumber;
                show2DPlot
            else
                set(hEditBins, 'string', num2str(histoSteps2D));
            end
        end

        function measSel(ha, hb)
            flagNew = false;
            val1 = get(hXMeasure, 'value');
            if val1 > 0 && val1 ~= statToShow(1)
                statToShow(1) = val1;
                flagNew = true;
            else
                set(hXMeasure, 'value', statToShow(1));
            end
            val2 = get(hYMeasure, 'value');
            if val2 > 0 && val2 ~= statToShow(2)
                statToShow(2) = val2;
                flagNew = true;
            else
                set(hYMeasure, 'value', statToShow(2));
            end
            if flagNew
                show2DPlot;
            end
        end
        
        % Show the histograms
        function show2DPlot
            hold(hPlot2D,'off');
            
            minValue(1) = min(cell2mat(measures.(listOfMeasures{statToShow(1)}).min));
            maxValue(1) = max(cell2mat(measures.(listOfMeasures{statToShow(1)}).max));
            minValue(2) = min(cell2mat(measures.(listOfMeasures{statToShow(2)}).min));
            maxValue(2) = max(cell2mat(measures.(listOfMeasures{statToShow(2)}).max));
            range = maxValue - minValue;
            
            histoBounds{1} = (0:histoSteps2D) * range(1) / histoSteps2D + minValue(1);
            histoBounds{2} = (0:histoSteps2D) * range(2) / histoSteps2D + minValue(2);
            
            
            maxHisto = 0;
            for samp = sampleToShow
                histo2D = zeros(histoSteps2D+1, histoSteps2D+1);
                % -----------
                % compute the stats for the sample 'samp'
                % -----------
                videoSelected = samplesListSelection(samp) - 1;
                if videoSelected == 0
                    % -----------
                    % use all videos
                    % -----------
                    vidIdx = 1:length(measures.(listOfMeasures{1}).raw{samp});
                    % -----------
                    % use all worms in all videos
                    % -----------
                    wormSelected = 0;
                else
                    % -----------
                    % use one video
                    % -----------
                    vidIdx = videoSelected;
                    % -----------
                    % wormSelected: 0 = use all worms, >0 = use only selected worm
                    % -----------
                    wormSelected = get(hSamples.listWoms(samp), 'value') - 1;
                end

                % -----------
                % Second pass: build the histogram
                % -----------
                raw = cell(1,2);
                for vid = vidIdx
                    % -----------
                    % Select which worms to use
                    % -----------
                    if wormSelected <= 0
                        wormIdx = 1:length(measures.(listOfMeasures{statToShow(1)}).raw{samp}{vid});
                    else
                        wormIdx = wormSelected;
                    end
                    % -----------
                    % Process all worms selected in the video
                    % -----------
                    raw{1} = [raw{1}; measures.(listOfMeasures{statToShow(1)}).raw{samp}{vid}(wormIdx)];
                    raw{2} = [raw{2}; measures.(listOfMeasures{statToShow(2)}).raw{samp}{vid}(wormIdx)];
                end
                for valIdx = 1:length(raw{1})
                    idx(1) = 1 + round(histoSteps2D * ( raw{1}(valIdx) - minValue(1) ) / range(1));
                    idx(2) = 1 + round(histoSteps2D * ( raw{2}(valIdx) - minValue(2) ) / range(2));
                    if ~isnan(idx(1)) && ~isnan(idx(2))
                        histo2D(idx(1),idx(2)) = histo2D(idx(1),idx(2)) + 1;
                    end
                end
                maxHistoTmp = max(histo2D(:));
                maxHisto = max(maxHisto, maxHistoTmp);
            end
            
            for samp = sampleToShow
                histo2D = zeros(histoSteps2D+1, histoSteps2D+1);
                % -----------
                % compute the stats for the sample 'samp'
                % -----------
                videoSelected = samplesListSelection(samp) - 1;
                if videoSelected == 0
                    % -----------
                    % use all videos
                    % -----------
                    vidIdx = 1:length(measures.(listOfMeasures{1}).raw{samp});
                    % -----------
                    % use all worms in all videos
                    % -----------
                    wormSelected = 0;
                else
                    % -----------
                    % use one video
                    % -----------
                    vidIdx = videoSelected;
                    % -----------
                    % wormSelected: 0 = use all worms, >0 = use only selected worm
                    % -----------
                    wormSelected = get(hSamples.listWoms(samp), 'value') - 1;
                end
                
                % -----------
                % Second pass: build the histogram
                % -----------
                raw = cell(1,2);
                for vid = vidIdx
                    % -----------
                    % Select which worms to use
                    % -----------
                    if wormSelected <= 0
                        wormIdx = 1:length(measures.(listOfMeasures{statToShow(1)}).raw{samp}{vid});
                    else
                        wormIdx = wormSelected;
                    end
                    % -----------
                    % Process all worms selected in the video
                    % -----------
                    raw{1} = [raw{1}; measures.(listOfMeasures{statToShow(1)}).raw{samp}{vid}(wormIdx)];
                    raw{2} = [raw{2}; measures.(listOfMeasures{statToShow(2)}).raw{samp}{vid}(wormIdx)];
                end
                for valIdx = 1:length(raw{1})
                    idx(1) = 1 + round(histoSteps2D * ( raw{1}(valIdx) - minValue(1) ) / range(1));
                    idx(2) = 1 + round(histoSteps2D * ( raw{2}(valIdx) - minValue(2) ) / range(2));
                    if ~isnan(idx(1)) && ~isnan(idx(2))
                        histo2D(idx(1),idx(2)) = histo2D(idx(1),idx(2)) + 1;
                    end
                end
                % -----------
                % Show graphs
                % -----------
                colormap(colorsHisto{samp});
                set(hHistoMax(samp), 'string', num2str(maxHisto));
                widthHisto = histoBounds{1}(2) - histoBounds{1}(1);
                heightHisto = histoBounds{2}(2) - histoBounds{2}(1);
                side = ceil(sqrt(nbOfSamples))+1;
                xLoc = 1 + rem(samp-1,side-1);
                yLoc = 1 + floor((samp-1)/(side-1));
                for samHistR = 1:histoSteps2D+1
                    for samHistC = 1:histoSteps2D+1
                        if histo2D(samHistR, samHistC) > 0
                            value = 1+round(histo2D(samHistR, samHistC) / maxHisto * (colorSteps-1));
                            x = -widthHisto/side*xLoc + histoBounds{1}(samHistR);
                            y = -heightHisto/side*yLoc + histoBounds{2}(samHistC);
                            xNext = x + widthHisto/side;
                            yNext = y + heightHisto/side;
                            fill([x,x,xNext,xNext],[y yNext yNext y],colorsHisto{samp}(value,:),'parent', hPlot2D);
                            hold(hPlot2D,'on');
                        end
                    end
                end
                axis(hPlot2D,[0 maxValue(1) 0 maxValue(2)])
                grid(hPlot2D, 'on')
                set(get(hPlot2D,'XLabel'),'String',listOfLabels{statToShow(1)})
                set(get(hPlot2D,'yLabel'),'String',listOfLabels{statToShow(2)})
                validNb = isfinite(raw{1}) & isfinite(raw{2});
                raw{1} = raw{1}(validNb);
                raw{2} = raw{2}(validNb);
                center{samp} = [mean(raw{1}), mean(raw{2})];
                cblCentered = [raw{1} - center{samp}(1) , raw{2} - center{samp}(2)];
                [ev, eigenTmp] = eig( cblCentered' * cblCentered / length(raw{1}));
                eigenVec{samp} = ev;
                eigenVal{samp} = sqrt(eigenTmp);
                a = eigenVal{samp}(2,2);
                b = eigenVal{samp}(1,1);
                cosPhi = eigenVec{samp}(1,2);
                sinPhi = eigenVec{samp}(2,2);
                alpha = 0:0.01:(2*pi);
                xEllipse(samp,:) = center{samp}(1) + a * cosPhi * cos(alpha) - b * sinPhi * sin(alpha);
                yEllipse(samp,:) = center{samp}(2) + a * sinPhi * cos(alpha) + b * cosPhi * sin(alpha);
            end
            idxColor = colorSteps/2;
            for samp = sampleToShow
                plot(hPlot2D,center{samp}(1), center{samp}(2), '*', 'linewidth', 2, 'color', colorsHisto{samp}(idxColor,:));
                plot(hPlot2D,center{samp}(1) + eigenVal{samp}(2,2)*eigenVec{samp}(1,2)*[-1,1], center{samp}(2) + eigenVal{samp}(2,2)*eigenVec{samp}(2,2)*[-1,1], '-', 'linewidth', 2, 'color', colorsHisto{samp}(idxColor,:));
                plot(hPlot2D,xEllipse(samp,:),yEllipse(samp,:), 'linewidth', 2, 'color', colorsHisto{samp}(idxColor,:));
            end
            axis(hPlot2D,'square')
        end
    end


    % =========
    % Check if a new measure was selected by the user
    % =========
    function measureSelected(hObject,eventdata)
        idx = find(btnMeas == hObject);
        for otheridx = 1:length(btnMeas)
            set(btnMeas(otheridx), 'value', 0);
        end
        set(btnMeas(idx), 'value', 1);
        if idx ~= statSelected
            statSelected = idx;
            showMeasures;
        end
    end

    % =========
    % Check if a new video was selected by the user
    % =========
    function videoSelected(hObject,eventdata)
        samp = find(hSamples.listVideos == hObject);
        valueSelected = get(hObject, 'value');
        if valueSelected <= 0
            % no change
            set(hObject, 'value', samplesListSelection(samp));
        else
            % change in selection
            samplesListSelection(samp) = valueSelected;
            if (valueSelected == 1)
                % The selection is the sample's name, disable the individual worms selection
                set(hSamples.listWoms(samp), 'string', {' '}, 'value', 1, 'enable', 'off');
            else
                % The selection is one video, fill in the worm selection and enable it
                vid = valueSelected - 1; % first line is sample's name
                nbOfWorms = length(wormIndices{samp}{vid});
                listNames = cell(1, 1+nbOfWorms);
                listNames{1} = 'All worms';
                for worm = 1:nbOfWorms
                    listNames{1+worm} = ['Worm ', num2str(wormIndices{samp}{vid}(worm))];
                end
                set(hSamples.listWoms(samp), 'string', listNames, 'value', 1, 'enable', 'on');
            end
            showMeasures(samp);
        end
    end

    % =========
    % Check if a new worm was selected by the user
    % =========
    function wormSelected(hObject,eventdata)
        samp = find(hSamples.listWoms == hObject);
        valueSelected = get(hObject, 'value');
        if valueSelected <= 0
            % no change
            set(hObject, 'value', wormListSelection(samp));
        else
            % change in selection
            wormListSelection(samp) = valueSelected;
            showMeasures(samp);
        end
    end

    % =========
    % Display the graphs for the selected measure, corresponding to either all samples, or only the samples selected as an argument
    % =========
    function showMeasures(sampleToShow)
        set(hLabel, 'string', listOfLabels{statSelected});
        if nargin <= 0
            sampleToShow = 1:nbOfSamples;
        end
        for samp = sampleToShow
            % -----------
            % compute the stats for the sample 'samp'
            % -----------
            videoSelected = samplesListSelection(samp) - 1;
            if videoSelected == 0
                % -----------
                % use all videos
                % -----------
                vidIdx = 1:length(measures.(listOfMeasures{statSelected}).raw{samp});
                % -----------
                % use all worms in all videos
                % -----------
                wormSelected = 0;
            else
                % -----------
                % use one video
                % -----------
                vidIdx = videoSelected;
                % -----------
                % wormSelected: 0 = use all worms, >0 = use only selected worm
                % -----------
                wormSelected = get(hSamples.listWoms(samp), 'value') - 1;
            end
            % -----------
            % Process all videos selected in the sample
            % -----------
            sumOfValues = 0;
            sumOfSq = 0;
            minValue = Inf;
            maxValue = -Inf;
            nbDataPoints = 0;
            
            % -----------
            % First pass: compute the mean, std, sem, cimean, min, max
            % -----------
            for vid = vidIdx
                % -----------
                % Select which worms to use
                % -----------
                if wormSelected <= 0
                    wormIdx = 1:length(measures.(listOfMeasures{statSelected}).raw{samp}{vid});
                else
                    wormIdx = wormSelected;
                end
                % -----------
                % Process all worms selected in the video
                % -----------
                values = measures.(listOfMeasures{statSelected}).raw{samp}{vid}(wormIdx);
                values(isnan(values))=[];
                nbDataPoints = nbDataPoints + length(wormIdx);
                sumOfValues = sumOfValues + sum(values);
                sumOfSq = sumOfSq + sum(values .^ 2);
                minValue = min([minValue; values],[],1);
                maxValue = max([maxValue; values],[],1);
            end
            meanSample = sumOfValues / nbDataPoints;
            varSample = sumOfSq/nbDataPoints - meanSample.^2;
            stdSample = sqrt(varSample);
            
            measures.(listOfMeasures{statSelected}).nbDataPoints{samp} = nbDataPoints;
            measures.(listOfMeasures{statSelected}).mean{samp} = meanSample;
            measures.(listOfMeasures{statSelected}).std{samp} = sqrt( varSample * nbDataPoints / (nbDataPoints-1) );
            measures.(listOfMeasures{statSelected}).sem{samp} = stdSample / sqrt(nbDataPoints);
            measures.(listOfMeasures{statSelected}).cimean{samp} = 1.96 * stdSample / sqrt(nbDataPoints);
            measures.(listOfMeasures{statSelected}).min{samp} = minValue;
            measures.(listOfMeasures{statSelected}).max{samp} = maxValue;
            
        end
        minValue = min(cell2mat(measures.(listOfMeasures{statSelected}).min));
        maxValue = max(cell2mat(measures.(listOfMeasures{statSelected}).max));
        range = maxValue - minValue;
        if range <= 0
            % -----------
            % only one value, make sure no division by zero, actual value is irrelevant
            % -----------
            range = 1;
        end
        histoBounds = (0:histoSteps) * range / histoSteps + minValue;
        namesHisto = cell(1, max(sampleToShow));
        for samp = sampleToShow
            % -----------
            % compute the stats for the sample 'samp'
            % -----------
            videoSelected = samplesListSelection(samp) - 1;
            if videoSelected == 0
                % -----------
                % use all videos
                % -----------
                vidIdx = 1:length(measures.(listOfMeasures{statSelected}).raw{samp});
                % -----------
                % use all worms in all videos
                % -----------
                wormSelected = 0;
            else
                % -----------
                % use one video
                % -----------
                vidIdx = videoSelected;
                % -----------
                % wormSelected: 0 = use all worms, >0 = use only selected worm
                % -----------
                wormSelected = get(hSamples.listWoms(samp), 'value') - 1;
            end
            
            % -----------
            % Second pass: build the histogram
            % -----------
            histogram = zeros(1, histoSteps+1);
            
            namesHisto{samp} = cell(1, histoSteps+1);
            
            measures.(listOfMeasures{statSelected}).histoBounds{samp} = histoBounds;
            for vid = vidIdx
                % -----------
                % Select which worms to use
                % -----------
                if wormSelected <= 0
                    wormIdx = 1:length(measures.(listOfMeasures{statSelected}).raw{samp}{vid});
                else
                    wormIdx = wormSelected;
                end
                % -----------
                % Process all worms selected in the video
                % -----------
                raw = measures.(listOfMeasures{statSelected}).raw{samp}{vid}(wormIdx);
                for valIdx = 1:length(raw)
                    idx = 1 + round(histoSteps * ( raw(valIdx) - minValue ) / range);
                    if ~isnan(idx)
                        
                        % add worm to the context menu
                        if isempty(namesHisto{samp}{idx})
                            namesHisto{samp}{idx} = cell(0);
                        end
                        namesHisto{samp}{idx}{end+1} = {samplesIdx{samp}{vid} ,  wormIndices{samp}{vid}(valIdx)};
                        histogram(idx) = histogram(idx) + 1;
                    end
                end
            end
            totalElements = sum(histogram);
            if totalElements >= 1
                measures.(listOfMeasures{statSelected}).histoValuesNotNorm{samp} = histogram;
                measures.(listOfMeasures{statSelected}).histoValues{samp} = histogram / totalElements;
                % -----------
                % Final step: compute the quartiles
                % -----------
                cumulNormHisto = cumsum(histogram) / totalElements;
                q1 = find(cumulNormHisto >= 0.25);
                measures.(listOfMeasures{statSelected}).quart1{samp} = histoBounds(q1(1));
                q2 = find(cumulNormHisto >= 0.5);
                measures.(listOfMeasures{statSelected}).median{samp} = histoBounds(q2(1));
                q3 = find(cumulNormHisto >= 0.75);
                measures.(listOfMeasures{statSelected}).quart3{samp} = histoBounds(q3(1));
            else
                % -----------
                % only rejected worms were selected
                % -----------
                for stat = 1:nbOfStats
                    if ~strcmp('raw', listOfStats{stat})
                        measures.(listOfMeasures{statSelected}).(listOfStats{stat}){samp} = [];
                    end
                end
            end
            set(hSamples.txtNbWorms(samp), 'string' , [num2str(measures.(listOfMeasures{statSelected}).nbDataPoints{samp}),' ']);
        end
        
        % -----------
        % Show graphs
        % -----------
        minValue = min(cell2mat(measures.(listOfMeasures{statSelected}).min));
        maxValue = max(cell2mat(measures.(listOfMeasures{statSelected}).max));
        deltaHisto = (maxValue - minValue) / histoSteps;
        if deltaHisto <= 0
            deltaHisto = 1;
        end
        xAxisCommon = [ minValue - deltaHisto/2 ,...
                        maxValue + deltaHisto/2 ];
        for samp = sampleToShow
            
            cla(hSamples.plotMean(samp))
            cla(hSamples.plotQuart(samp))
            cla(hSamples.plotHisto(samp))
            
            if measures.(listOfMeasures{statSelected}).nbDataPoints{samp} > 0
                % -----------
                % Mean, std, sem, cimean
                % -----------
                hold(hSamples.plotMean(samp), 'on')
                plot(hSamples.plotMean(samp), measures.(listOfMeasures{statSelected}).mean{samp} + measures.(listOfMeasures{statSelected}).sem{samp}*[-1,0,1], 3*[1,1,1],'+-g','linewidth',2)
                plot(hSamples.plotMean(samp), measures.(listOfMeasures{statSelected}).mean{samp} + measures.(listOfMeasures{statSelected}).cimean{samp}*[-1,0,1], 2*[1,1,1],'+-b','linewidth',2)
                plot(hSamples.plotMean(samp), measures.(listOfMeasures{statSelected}).mean{samp} + measures.(listOfMeasures{statSelected}).std{samp}*[-1,0,1], [1,1,1],'+-r','linewidth',2)
                axis(hSamples.plotMean(samp), [xAxisCommon(1), xAxisCommon(2), 0, 4]);
                set(hSamples.plotMean(samp),'xtickmode','auto','XMinorGrid','on','ytick',[],'xgrid','on','xticklabel',[],'TickLength',[0 0]);
                set(hSamples.txtMSE(samp), 'string', [...
                    num2str(measures.(listOfMeasures{statSelected}).mean{samp},'%5.4g'), ' +/- ',...
                    num2str(measures.(listOfMeasures{statSelected}).sem{samp},'%5.3g'), ' ']);
                set(hSamples.txtMCI(samp), 'string', [...
                    num2str(measures.(listOfMeasures{statSelected}).mean{samp},'%5.4g'), ' +/- ',...
                    num2str(measures.(listOfMeasures{statSelected}).cimean{samp},'%5.3g'), ' ']);
                set(hSamples.txtMSD(samp), 'string', [...
                    num2str(measures.(listOfMeasures{statSelected}).mean{samp},'%5.4g'), ' +/- ',...
                    num2str(measures.(listOfMeasures{statSelected}).std{samp},'%5.3g'), ' ']);
                
                % -----------
                % Quartiles
                % -----------
                hold(hSamples.plotQuart(samp), 'on')
                plot(hSamples.plotQuart(samp), [measures.(listOfMeasures{statSelected}).min{samp}, measures.(listOfMeasures{statSelected}).quart1{samp}], [1 1], '-r','linewidth',2);
                plot(hSamples.plotQuart(samp), [measures.(listOfMeasures{statSelected}).quart3{samp}, measures.(listOfMeasures{statSelected}).max{samp}], [1 1], '-r','linewidth',2);
                plot(hSamples.plotQuart(samp), measures.(listOfMeasures{statSelected}).median{samp}*[1,1], [0.5 1.5], '-r','linewidth',2);
                plot(hSamples.plotQuart(samp), [measures.(listOfMeasures{statSelected}).quart1{samp}, measures.(listOfMeasures{statSelected}).quart1{samp},...
                    measures.(listOfMeasures{statSelected}).quart3{samp}, measures.(listOfMeasures{statSelected}).quart3{samp},...
                    measures.(listOfMeasures{statSelected}).quart1{samp}], [0.5 1.5 1.5 0.5 0.5], '-r','linewidth',2);
                axis(hSamples.plotQuart(samp), [xAxisCommon(1), xAxisCommon(2), 0, 2]);
                set(hSamples.plotQuart(samp),'xtickmode','auto','XMinorGrid','on','ytick',[],'xgrid','on','xticklabel',[],'TickLength',[0 0]);
                set(hSamples.txtQuartiles(samp), 'string', [...
                    num2str(measures.(listOfMeasures{statSelected}).min{samp},'%5.3g'),' - ',...
                    num2str(measures.(listOfMeasures{statSelected}).quart1{samp},'%5.3g'),' - ',...
                    num2str(measures.(listOfMeasures{statSelected}).median{samp},'%5.3g'),' - ',...
                    num2str(measures.(listOfMeasures{statSelected}).quart3{samp},'%5.3g'),' - ',...
                    num2str(measures.(listOfMeasures{statSelected}).max{samp},'%5.3g'),' ']);
                
                % -----------
                % Histogram
                % -----------
                hold(hSamples.plotHisto(samp), 'on')
                colorSteps = 100;
                colorsHisto = eval([listColormaps{idxColormap},'(',num2str(2+colorSteps),')']);
                maxHisto = max(measures.(listOfMeasures{statSelected}).histoValues{samp});
                widthHisto = measures.(listOfMeasures{statSelected}).histoBounds{samp}(2) - measures.(listOfMeasures{statSelected}).histoBounds{samp}(1);
                for samHist = 1:histoSteps+1
                    if measures.(listOfMeasures{statSelected}).histoValues{samp}(samHist) > 0
                        value = 1+round(measures.(listOfMeasures{statSelected}).histoValues{samp}(samHist) / maxHisto*colorSteps);
                        x = - deltaHisto/2 + measures.(listOfMeasures{statSelected}).histoBounds{samp}(samHist) ;
                        xNext = x + widthHisto;
                        hcmenu = uicontextmenu;
                        for idxMenu = 1:length(namesHisto{samp}{samHist})
                            uimenu(hcmenu, 'Label', [fileDB(namesHisto{samp}{samHist}{idxMenu}{1}).name , ' : worm ',  num2str(namesHisto{samp}{samHist}{idxMenu}{2})]);
                        end
                        fill([x,x,xNext,xNext],[0 1 1 0],colorsHisto(value,:),'parent', hSamples.plotHisto(samp), 'UIContextMenu', hcmenu, 'edgecolor', 'c');
                    end
                end
                axis(hSamples.plotHisto(samp), [xAxisCommon(1), xAxisCommon(2), 0, 1]);
                set(hSamples.plotHisto(samp),'xtickmode','auto','XMinorGrid','on','ytick',[],'xgrid','on','XTickLabelMode','auto','ticklength',[0 0]);
            end
        end
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