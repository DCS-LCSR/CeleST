function CSTwriteMeasuresToTXT(listOfMeasures, videoName, flagShowGUI)
% Copyright (c) 2013 Rutgers
% Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
% The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
% THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

global filenames;

if nargin < 3
    flagShowGUI = true;
end
fid = fopen(fullfile(filenames.measures, ['wormMeas_',videoName,'.txt']),'w+');
if fid >= 3
    if (flagShowGUI)
        hWaitBar = waitbar(0,'Saving measures...');
    end
    listOfFields = fieldnames(listOfMeasures);
    nbOfWorms = length(listOfMeasures.(listOfFields{1}));
    nbOfFields = length(listOfFields);
    % Header
    fprintf(fid,['fields ', num2str(nbOfFields),'\n']);
    fprintf(fid,['worms ', num2str(nbOfWorms),'\n']);
    for ff = 1:nbOfFields
        field = listOfFields{ff};
        fprintf(fid,[field,'\n']);
        if strcmp(field, 'status')
            for ww = 1:length(listOfMeasures.(field))
                fprintf(fid, [listOfMeasures.(field){ww},'\n']);
            end
        elseif strcmp(field, 'manualSeparators') || strcmp(field, 'separators')
            for ww = 1:length(listOfMeasures.(field))
                fprintf(fid, [num2str(listOfMeasures.(field){ww}),'\n']);
            end
        else
            for ww = 1:length(listOfMeasures.(field))
                fprintf(fid, sprintf('%f ',listOfMeasures.(field)(ww)));
            end
            fprintf(fid, '\n');
        end
    end
    fclose(fid);
    if flagShowGUI
        close(hWaitBar)
        pause(0.001)
    end
else
    disp(['Cannot write: ',fullfile(filenames.measures, ['wormMeas_',videoName,'.txt'])]);
end
end
