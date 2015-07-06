function [listOfMeasures, listOfWormIdx] = CSTreadMeasuresFromTXT(videoName, flagShowGUI, listOfFields, flagOnlyUsable, listOfWormsToLoad)
% Copyright (c) 2013 Rutgers
% Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
% The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
% THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

% Read segmentation listOfMeasures from txt file, returns a struct array with all the fields

global filenames;

if nargin <= 1
    flagShowGUI = true;
end
if nargin <= 2
    listOfFields = {};
end
if nargin <= 3
    flagOnlyUsable = false;
end
if nargin <= 4
    flagLoadAllWorms = true;
else
    flagLoadAllWorms = false;
end

listOfMeasures = [];
fid = fopen(fullfile(filenames.measures, ['wormMeas_',videoName,'.txt']),'r');
if fid >= 3
    if (flagShowGUI)
        hWaitBar = waitbar(0,'Loading measures...');
    end
    nbOfFields = sscanf(fgetl(fid), 'fields %d');
    nbOfWorms = sscanf(fgetl(fid), 'worms %d');
    for ff = 1:nbOfFields
        field = fgetl(fid);
        if strcmp(field, 'status')
            % always store status anyway
            listOfMeasures.(field) = cell(1,nbOfWorms);
            if flagLoadAllWorms
                for ww = 1:nbOfWorms
                    listOfMeasures.(field){ww} = fgetl(fid);
                end
            else
                listOfMeasures.(field) = cell(1,0);
                for ww = 1:nbOfWorms
                    if ~isempty(find( listOfWormsToLoad == ww , 1))
                        listOfMeasures.(field){end+1} = fgetl(fid);
                    else
                        fgetl(fid);
                    end
                end
            end
        elseif strcmp(field, 'manualSeparators') || strcmp(field, 'separators')
            % always store status anyway
            listOfMeasures.(field) = cell(1,nbOfWorms);
            for ww = 1:nbOfWorms
                listOfMeasures.(field){ww} = str2num(fgetl(fid)); %#ok<ST2NM>
            end

        else
            if flagOnlyUsable
                line = fgetl(fid);
                if any(strcmp(field, listOfFields))
                    listOfMeasures.(field) = sscanf(line, '%f ');
                    if ~flagLoadAllWorms
                        listOfMeasures.(field) = listOfMeasures.(field)(listOfWormsToLoad);
                    end
                end
            else
                listOfMeasures.(field) = sscanf(fgetl(fid), '%f ');
                    if ~flagLoadAllWorms
                        listOfMeasures.(field) = listOfMeasures.(field)(listOfWormsToLoad);
                    end
            end
        end
    end
    fclose(fid);
    listOfWormIdx = 1:nbOfWorms;
    
    if flagOnlyUsable && flagLoadAllWorms
        for ww = nbOfWorms:-1:1
            if strcmp('rejected', listOfMeasures.status{ww})
                listOfWormIdx(ww) = [];
                for ff = 1:length(listOfFields)
                    try
                        listOfMeasures.(listOfFields{ff})(ww) = [];
                    catch  %#ok<CTCH>
                    end
                end
            end
        end
        if ~strcmp('status', flagOnlyUsable)
            listOfMeasures = rmfield(listOfMeasures, 'status');
        end
    end
    
    if flagShowGUI
        close(hWaitBar)
        pause(0.001)
    end
else
    disp(['Cannot read: ',fullfile(filenames.measures, ['wormMeas_',videoName,'.txt'])]);
end
end
