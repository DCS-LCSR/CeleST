function CSTShowMeasures
% Copyright (c) 2013 Rutgers
% Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
% The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
% THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

% This function creates a window displaying measures.

global fileDB filterSelection samplesDef colFtlWell mainPnlW mainPnlH samplesIdx;

samplesIdx = [];
samplesDef = [];
% ============
% CREATE THE INTERFACE
% ============
% ----------
% Main figure and sliders
% ----------
scrsz = get(0,'ScreenSize');
mainW = min(mainPnlW, scrsz(3) - 10);
mainH = min(mainPnlH, scrsz(4) - 70);
mainPanelPosition = [2, mainH-mainPnlH-2, mainPnlW, mainPnlH];
mainFigure = figure('Visible','off','Position',[5,40,mainW,mainH],'Name','CeleST: Statistics sample definition - Define the samples by grouping videos, launch the graph display','numbertitle','off', 'menubar', 'none', 'resizefcn', @resizeMainFigure);
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
pnlFilters = uipanel('parent', mainPanel,'BorderType', 'none','units','pixels', 'position', [1 yFilters mainPnlW hFilters]);%,'title','Filters'
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
listVideosFiltered =  uicontrol('parent',mainPanel,'style','listbox','String',{''},'max',2,'min',0,'position',[0 yVideos 2*filterW 3*filterH]); %,'callback', @checkSelectedVideo);
listVideosFilteredIdx = [];
uicontrol('parent',mainPanel,'style','pushbutton', 'string', 'Select all', 'position', [0 yVideos+3*filterH filterW-10 30], 'callback', @(a,b) set(listVideosFiltered, 'value', 1:length(get(listVideosFiltered,'string'))))
uicontrol('parent',mainPanel,'style','pushbutton', 'string', 'Deselect all', 'position', [filterW+10 yVideos+3*filterH filterW-10 30], 'callback', @(a,b) set(listVideosFiltered, 'value', []))

uicontrol('parent',mainPanel,'style','pushbutton', 'string', 'Close', 'position', [20 yVideos-50 filterW 30], 'callback', @closeWindow);

uicontrol('parent',mainPanel,'style','pushbutton', 'string', '>>      Add to a new sample     >>', 'position', [2*filterW yVideos+3*filterH-40 200 50], 'callback', @addVideosNew);
uicontrol('parent',mainPanel,'style','pushbutton', 'string', '>>  Add to the selected sample  >>', 'position', [2*filterW yVideos+3*filterH-90 200 50], 'callback', @addVideosExisting);
uicontrol('parent',mainPanel,'style','pushbutton', 'string', '<<  Remove the selected videos  <<', 'position', [2*filterW yVideos+3*filterH-170 200 50], 'callback', @removeVideos);
uicontrol('parent',mainPanel,'style','pushbutton', 'string', '<<  Remove the selected sample  <<', 'position', [2*filterW yVideos+3*filterH-220 200 50], 'callback', @removeSample);
uicontrol('parent',mainPanel,'style','pushbutton', 'string', 'Show graphs for these samples',        'position', [2*filterW yVideos+3*filterH-300 200 50], 'callback', @showGraphs);

uicontrol('parent',mainPanel,'style','text', 'HorizontalAlignment', 'left','String','Double-click on a sample name (first line) to change it.','position',[4*filterW+80 yVideos+3*filterH+35 500 20]);
tableSamples = uitable('parent',mainPanel,'position',[4*filterW-100 50 mainPnlW-4*filterW yVideos+3*filterH-10],'RearrangeableColumn','on','ColumnEditable',[],'CellEditCallback', @tableEdit, 'CellSelectionCallback', @tableSelect,'rowstriping','off');
selectedCellsData = [];

if isempty(samplesDef)
    samplesDef = {};
end

set(tableSamples, 'data', samplesDef)
setRowNames


% ============
% SHOW THE INTERFACE
% ============
populateFilters
set(mainFigure,'visible','on')
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

    function showGraphs(hObject,eventdata)
        CSTShowGraphs;
    end

    function addVideosNew(hObject,eventdata)
        listOfFiltered = get(listVideosFiltered,'string');
        listOfSelection = get(listVideosFiltered,'value');
        samplesDef = get(tableSamples, 'data');
        newCol = 1 + size(samplesDef,2);
        samplesIdx{newCol} = num2cell(listVideosFilteredIdx(listOfSelection));
        totWorms = 0;
        for sel = 1:length(samplesIdx{newCol})
            totWorms = totWorms + fileDB(samplesIdx{newCol}{sel}).worms;
        end
        selectedNames = [['Sample ',num2str(newCol)];[num2str(totWorms),' worms'];listOfFiltered(listOfSelection)];
        samplesDef(1:length(selectedNames),newCol) = selectedNames;
        set(tableSamples, 'data', samplesDef);
        setRowNames
    end

    function addVideosExisting(hObject,eventdata)
        if isfield(selectedCellsData,'Indices') && ~isempty(selectedCellsData.Indices)
            colToAdd = selectedCellsData.Indices(1,2);
            listOfFiltered = get(listVideosFiltered,'string');
            listOfSelection = get(listVideosFiltered,'value');
            samplesDef = get(tableSamples, 'data');
            namesToAdd = listOfFiltered(listOfSelection);
            idxToAdd = 1;
            while (idxToAdd <= size(samplesDef,1)) && ~isempty(samplesDef{idxToAdd,colToAdd})
                idxToAdd = idxToAdd + 1;
            end
            for name = 1:length(namesToAdd)
                if ~any(strcmp(namesToAdd{name}, samplesDef(:,colToAdd)))
                    samplesDef{idxToAdd, colToAdd} = namesToAdd{name};
                    samplesIdx{colToAdd}{idxToAdd-2} = listVideosFilteredIdx(listOfSelection(name));
                    idxToAdd = idxToAdd + 1;
                end
            end
            set(tableSamples, 'data', samplesDef);
            setRowNames
        end
    end

    function removeVideos(hObject,eventdata)
        if isfield(selectedCellsData,'Indices') && ~isempty(selectedCellsData.Indices)
            samplesDef = get(tableSamples, 'data');
            for item = size(selectedCellsData.Indices,1):-1:1
                row = selectedCellsData.Indices(item,1);
                if row >= 3
                    col = selectedCellsData.Indices(item,2);
                    samplesDef(row:end-1, col) = samplesDef(row+1:end, col);
                    samplesDef{end, col} = [];
                    samplesIdx{col}(row-2) = [];
                end
            end
            set(tableSamples, 'data', samplesDef);
            trimEmptyLines
        end
    end

    function removeSample(hObject,eventdata)
        if isfield(selectedCellsData,'Indices') && ~isempty(selectedCellsData.Indices)
            samplesDef = get(tableSamples, 'data');
            colToDelete = selectedCellsData.Indices(1,2);
            button = questdlg(['Are you sure you want to delete sample ', samplesDef{1,colToDelete}, '?'],'CeleST','Delete','Cancel','Cancel');
            if strcmp(button, 'Delete')
                samplesDef(:, colToDelete) = [];
                set(tableSamples, 'data', samplesDef);
                samplesIdx(colToDelete) = [];
                trimEmptyLines
            end
        end
    end

    function trimEmptyLines
        samplesDef = get(tableSamples, 'data');
        for row = size(samplesDef,1):-1:3
            flagRemove = true;
            for col = 1:size(samplesDef,2)
                flagRemove = flagRemove && isempty(samplesDef{row,col});
            end
            if flagRemove
                samplesDef(row,:) = [];
            else
                break
            end
        end
        set(tableSamples, 'data', samplesDef);
        setRowNames
    end

    function setRowNames
        samplesDef = get(tableSamples, 'data');
        rowNames = cell(size(samplesDef,1),1);
        rowNames{1} = 'Sample name';
        rowNames{2} = '# worms';
        if ~isempty(samplesDef)
            for row = 1:length(rowNames)-2
                rowNames{2+row} = ['Video ', num2str(row)];
            end
            set(tableSamples, 'rowname',rowNames);
            for col = 1:size(samplesDef,2)
                totWorms = 0;
                for sel = 1:length(samplesIdx{col})
                    totWorms = totWorms + fileDB(samplesIdx{col}{sel}).worms;
                end
                samplesDef{2, col} = [num2str(totWorms),' worms'];
            end
            set(tableSamples, 'data', samplesDef);
            ww = cell(1,size(samplesDef,2));
            for it = 1:length(ww)
                ww{it} = filterW;
            end
            set(tableSamples, 'columnwidth',ww)
        end
    end

    function tableSelect(hObject,eventdata) %#ok<*INUSL>
        selectedCellsData = eventdata;
        if size(eventdata.Indices, 1) == 1 && eventdata.Indices(1) == 1
            set(tableSamples, 'ColumnEditable', true)
        else
            set(tableSamples, 'ColumnEditable', false)
        end
    end

    function tableEdit(hObject,eventdata)
        if size(eventdata.Indices, 1) ~= 1 || eventdata.Indices(1) ~= 1
            samplesDef = get(tableSamples, 'data');
            samplesDef(eventdata.Indices(1), eventdata.Indices(2)) = eventdata.PreviousData;
            set(tableSamples, 'data', samplesDef);
        end
        set(tableSamples, 'ColumnEditable', false)
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
            if flagKeep && fileDB(vv).measured
                currentVal = currentVal + 1;
                result{currentVal} = [fileDB(vv).name, '   (', num2str(fileDB(vv).worms), ' worms)'];
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
