function CSTShowAllStatTests
% Copyright (c) 2013 Rutgers
% Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
% The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
% THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.


global samplesIdx mainPnlW samplesDef measures listOfMeasures listOfButtons;


% ============
% CREATE THE INTERFACE
% ============
mainPnlH = 800;
% ----------
% Main figure and sliders
% ----------
scrsz = get(0,'ScreenSize');
mainW = min(mainPnlW, scrsz(3) - 10);
mainH = min(mainPnlH, scrsz(4) - 70);
mainPanelPosition = [2, mainH-mainPnlH-2, mainPnlW, mainPnlH];
mainFigure = figure('Visible','off','Position',[5,40,mainW,mainH],'Name','CeleST: Statistics tests display and export','numbertitle','off', 'menubar', 'none', 'resizefcn', @resizeMainFigure);
mainPanel = uipanel('parent', mainFigure,'BorderType', 'none','units','pixels', 'position', mainPanelPosition);
sliderHoriz = uicontrol('parent',mainFigure,'style','slider','position',[0 0 mainW-20 20],'max', 1,'min',0, 'value',0,'callback',@setMainPanelPositionBySliders);
sliderVert = uicontrol('parent',mainFigure,'style','slider','position',[mainW-20 20 20 mainH-20],'max', max(1,-mainPanelPosition(2)),'min',0, 'value',max(1,-mainPanelPosition(2)),'callback',@setMainPanelPositionBySliders);
set(mainFigure, 'color', get(mainPanel,'backgroundcolor'));
uicontrol('parent',mainPanel,'style','pushbutton', 'string', 'Close', 'position', [10 mainPnlH-25 100 30], 'callback', @closeWindow);
tableTests = uitable('parent',mainPanel,'position',[0 30 mainPnlW-30 mainPnlH-55],'RearrangeableColumn','on','ColumnEditable',false,'ColumnWidth','auto');
set(tableTests,'columnname',{' '}, 'rowname', {' '});
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
set(tableTests,'data', tableData);
set(tableTests,'ColumnWidth','auto');

% ============
% SHOW THE INTERFACE
% ============
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

    function closeWindow(hObject,eventdata) %#ok<*INUSD>
        set(mainFigure,'Visible','off');
        delete(mainFigure);
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