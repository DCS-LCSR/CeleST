function listOfWorms = CSTreadSegmentationFromTXT(videoName, flagShowGUI)
% Copyright (c) 2013 Rutgers
% Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
% The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
% THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

% Read segmentation results from txt file, returns a struct array with all the fields

global filenames;

if nargin < 2
    flagShowGUI = true;
end

if (flagShowGUI)
    hWaitBar = waitbar(0,'Loading segmentation results...');
end

fid = fopen(fullfile(filenames.segmentation, ['wormSegm_',videoName,'.txt']));
line1 = textscan(fgetl(fid), '%s %s');
flagVersion29 = false;

if strcmp(line1{1}{1}, 'version') && strcmp(line1{2}{1}, '2.9.01')
    flagVersion29 = true;
    line1 = textscan(fgetl(fid), '%s %s');
end

line2 = textscan(fgetl(fid), '%s %s');
line3 = textscan(fgetl(fid), '%s %s');
line4 = textscan(fgetl(fid), '%s %s');
nbOfWorms = str2double(line3{2}{1});
nbOfFrames = str2double(line4{2}{1});
line5 = textscan(fgetl(fid), '%s %s');
precision = str2double(line5{2}{1});
factor = 10^precision;
listBoolean = {'missed', 'lost', 'overlapped'};
listCell = {'skel', 'width'};
listCellSingle = {'localthreshold'};
listDouble = {'lengthWorms'};
if flagVersion29
    listBoolean = [listBoolean, 'valid', 'outOfLengths', 'outOfPrevious', 'inGlareZone', 'selfOverlap', 'manualInvalid', 'manualValid'];
    listCell = [listCell, 'cblSubSampled'];
    listDouble = [listDouble, 'positionCenterX', 'positionCenterY', 'widthCenter', 'angleHead', 'angleTail', 'I', 'J', 'C', 'S', 'O', 'overlapPrev', 'headThrashCount'];
end
for field = 1:length(listBoolean)
    listOfWorms.(listBoolean{field}) = false(nbOfWorms, nbOfFrames);
end
for field = 1:length(listCell)
    listOfWorms.(listCell{field}) = cell(1,nbOfWorms);
    for ww = 1:nbOfWorms
        listOfWorms.(listCell{field}){ww} = cell(1,nbOfFrames);
    end
end
for field = 1:length(listCellSingle)
    listOfWorms.(listCellSingle{field}) = cell(1,nbOfWorms);
end
for field = 1:length(listDouble)
    listOfWorms.(listDouble{field}) = zeros(nbOfWorms, nbOfFrames);
end

if strcmp(line1{1}{1}, 'format') && strcmp(line2{1}{1}, 'block')
    ww = 0;
    tline = fgetl(fid);
    while ischar(tline)
        % read the worm and frame indices
        items = sscanf(tline, 'worm %d frame %d');
        if flagShowGUI && ww < items(1)
            waitbar(items(1)/nbOfWorms, hWaitBar);
        end
        ww = items(1);
        ff = items(2);
            % read the coordinates
            listOfWorms.skel{ww}{ff} = [str2num(sscanf(fgetl(fid),'x %s'));str2num(sscanf(fgetl(fid),'y %s'))]/factor; %#ok<ST2NM>
            % read the width
            listOfWorms.width{ww}{ff} = str2num(sscanf(fgetl(fid),'w %s'))/factor; %#ok<ST2NM>
            % read the local threshold
            listOfWorms.localthreshold{ww} = str2double(sscanf(fgetl(fid),'t %s'))/factor;
            % read the lengthWorms
            listOfWorms.lengthWorms(ww,ff) = str2double(sscanf(fgetl(fid),'g %s'))/factor;
            % read the missed
            listOfWorms.missed(ww,ff) = (str2double(sscanf(fgetl(fid),'m %s')) > 0);
            % read the lost
            listOfWorms.lost(ww,ff) = (str2double(sscanf(fgetl(fid),'l %s')) > 0);
            % read the overlapped
            listOfWorms.overlapped(ww,ff) = (str2double(sscanf(fgetl(fid),'o %s')) > 0);
            if flagVersion29
                listOfWorms.valid(ww,ff) = (str2double(sscanf(fgetl(fid),'v %s')) > 0);
                listOfWorms.outOfLengths(ww,ff) = (str2double(sscanf(fgetl(fid),'h %s')) > 0);
                listOfWorms.outOfPrevious(ww,ff) = (str2double(sscanf(fgetl(fid),'p %s')) > 0);
                listOfWorms.inGlareZone(ww,ff) = (str2double(sscanf(fgetl(fid),'z %s')) > 0);
                listOfWorms.selfOverlap(ww,ff) = (str2double(sscanf(fgetl(fid),'s %s')) > 0);
                listOfWorms.positionCenterX(ww,ff) = str2double(sscanf(fgetl(fid),'a %s'))/factor;
                listOfWorms.positionCenterY(ww,ff) = str2double(sscanf(fgetl(fid),'b %s'))/factor;
                listOfWorms.widthCenter(ww,ff) = str2double(sscanf(fgetl(fid),'c %s'))/factor;
                listOfWorms.cblSubSampled{ww}{ff} = [str2num(sscanf(fgetl(fid),'d %s'));str2num(sscanf(fgetl(fid),'e %s'))]/factor; %#ok<ST2NM>
                listOfWorms.angleHead(ww,ff) = str2double(sscanf(fgetl(fid),'f %s'))/factor;
                listOfWorms.angleTail(ww,ff) = str2double(sscanf(fgetl(fid),'q %s'))/factor;
                listOfWorms.I(ww,ff) = str2double(sscanf(fgetl(fid),'I %s'))/factor;
                listOfWorms.J(ww,ff) = str2double(sscanf(fgetl(fid),'J %s'))/factor;
                listOfWorms.C(ww,ff) = str2double(sscanf(fgetl(fid),'C %s'))/factor;
                listOfWorms.S(ww,ff) = str2double(sscanf(fgetl(fid),'S %s'))/factor;
                listOfWorms.O(ww,ff) = str2double(sscanf(fgetl(fid),'O %s'))/factor;
                listOfWorms.overlapPrev(ww,ff) = str2double(sscanf(fgetl(fid),'k %s'))/factor;
                listOfWorms.manualInvalid(ww,ff) = (str2double(sscanf(fgetl(fid),'n %s')) > 0);
                listOfWorms.manualValid(ww,ff) = (str2double(sscanf(fgetl(fid),'r %s')) > 0);
                listOfWorms.headThrashCount(ww,ff) = str2double(sscanf(fgetl(fid),'u %s'))/factor;
                listOfWorms.tailThrashCount(ww,ff) = str2double(sscanf(fgetl(fid),'U %s'))/factor;
            end
        tline = fgetl(fid);
    end
end
fclose(fid);
if flagShowGUI
    close(hWaitBar)
    pause(0.001)
end

end
