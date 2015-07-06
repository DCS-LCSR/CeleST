function CSTwriteSegmentationToTXT(listOfWorms, videoName, flagShowGUI, precision)
% Copyright (c) 2013 Rutgers
% Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
% The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
% THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

global filenames;

if nargin < 3
    flagShowGUI = true;
end
if nargin < 4
    precision = 2;
end

flagVersion29 = false;
factor = 10^precision;

blockSize = 2 + length(fieldnames(listOfWorms));

if (flagShowGUI)
    hWaitBar = waitbar(0,'Saving segmentation results...');
end
nbOfWorms = length(listOfWorms.skel);
nbOfFrames = length(listOfWorms.skel{1});
formatting = '%s %02d %s %04d';
header = ['format ',strrep(strrep(formatting, '%','%%'),' ','_'),'\nblock ',num2str(blockSize),'\nworms ',num2str(nbOfWorms),'\nframes ',num2str(nbOfFrames),'\nprecision ', num2str(precision),'\n'];
fid = fopen(fullfile(filenames.segmentation, ['wormSegm_',videoName,'.txt']),'w+');

if isfield(listOfWorms, 'valid')
    fprintf(fid, 'version 2.9.01\n');
    flagVersion29 = true;
end

fprintf(fid, header);

for ww = 1:nbOfWorms
    if flagShowGUI
        waitbar(ww/nbOfWorms, hWaitBar);
    end
    for ff = 1:nbOfFrames
        if (length(listOfWorms.skel{ww}) >= ff) && (~isempty(listOfWorms.skel{ww}{ff}))
            coordX = round(factor*listOfWorms.skel{ww}{ff}(1,:));
            coordY = round(factor*listOfWorms.skel{ww}{ff}(2,:));
        else
            coordX = [];
            coordY = [];
        end
        
        stringToSave = [sprintf(formatting, 'worm', ww, 'frame', ff),'\n'...
                , 'x ', sprintf('%d,',coordX),'\n'...
                , 'y ', sprintf('%d,',coordY),'\n'...
                , 'w ', sprintf('%d,',round(factor*listOfWorms.width{ww}{ff})),'\n'...
                , 't ', sprintf('%d,',round(factor*listOfWorms.localthreshold{ww})),'\n'...
                , 'g ', sprintf('%d,',round(factor*listOfWorms.lengthWorms(ww,ff))),'\n'...
                , 'm ', sprintf('%d,',listOfWorms.missed(ww,ff)),'\n'...
                , 'l ', sprintf('%d,',listOfWorms.lost(ww,ff)),'\n'...
                , 'o ', sprintf('%d,',listOfWorms.overlapped(ww,ff)),'\n'];
        if flagVersion29
            if (length(listOfWorms.cblSubSampled{ww}) >= ff) && (~isempty(listOfWorms.cblSubSampled{ww}{ff}))
                coordX = round(factor*listOfWorms.cblSubSampled{ww}{ff}(1,:));
                coordY = round(factor*listOfWorms.cblSubSampled{ww}{ff}(2,:));
            else
                coordX = [];
                coordY = [];
            end
            stringToSave = [stringToSave...
                , 'v ', sprintf('%d,',listOfWorms.valid(ww,ff)),'\n'...
                , 'h ', sprintf('%d,',listOfWorms.outOfLengths(ww,ff)),'\n'...
                , 'p ', sprintf('%d,',listOfWorms.outOfPrevious(ww,ff)),'\n'...
                , 'z ', sprintf('%d,',listOfWorms.inGlareZone(ww,ff)),'\n'...
                , 's ', sprintf('%d,',listOfWorms.selfOverlap(ww,ff)),'\n'...
                , 'a ', sprintf('%d,',round(factor*listOfWorms.positionCenterX(ww,ff))),'\n'...
                , 'b ', sprintf('%d,',round(factor*listOfWorms.positionCenterY(ww,ff))),'\n'...
                , 'c ', sprintf('%d,',round(factor*listOfWorms.widthCenter(ww,ff))),'\n'...
                , 'd ', sprintf('%d,',coordX),'\n'...
                , 'e ', sprintf('%d,',coordY),'\n'...
                , 'f ', sprintf('%d,',round(factor*listOfWorms.angleHead(ww,ff))),'\n'...
                , 'q ', sprintf('%d,',round(factor*listOfWorms.angleTail(ww,ff))),'\n'...
                , 'I ', sprintf('%d,',round(factor*listOfWorms.I(ww,ff))),'\n'...
                , 'J ', sprintf('%d,',round(factor*listOfWorms.J(ww,ff))),'\n'...
                , 'C ', sprintf('%d,',round(factor*listOfWorms.C(ww,ff))),'\n'...
                , 'S ', sprintf('%d,',round(factor*listOfWorms.S(ww,ff))),'\n'...
                , 'O ', sprintf('%d,',round(factor*listOfWorms.O(ww,ff))),'\n'...
                , 'k ', sprintf('%d,',round(factor*listOfWorms.overlapPrev(ww,ff))),'\n'...
                , 'n ', sprintf('%d,',listOfWorms.manualInvalid(ww,ff)),'\n'...
                , 'r ', sprintf('%d,',listOfWorms.manualValid(ww,ff)),'\n'...
                , 'u ', sprintf('%d,',round(factor*listOfWorms.headThrashCount(ww,ff))),'\n'...
                , 'U ', sprintf('%d,',round(factor*listOfWorms.headThrashCount(ww,ff))),'\n']; %#ok<AGROW>
            
        end
        fprintf(fid, stringToSave);
    end
end
fclose(fid);
if flagShowGUI
    close(hWaitBar)
    pause(0.001)
end

end
