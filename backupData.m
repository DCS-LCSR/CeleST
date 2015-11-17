function backupData(original)

% Copyright (c) 2015 Rutgers
% Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
% The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
% THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

% backup data directory with folder named by current date and '_backup'
% then recursively copy files from data folder into backup

flagDisplayCopying = true;

if ~(ischar(original) && isdir(original))
    disp('Invalid Input, Path must be an existing directory provided as a string');
end

originalFiles = dir(original);
backupName = fullfile(original, '_backup_');

disp(['Creating backup data directory: ', backupName]);
if isdir(backupName)
    disp([backupName ' is already a directory.']);
    success = 0;
else
    success = mkdir(backupName);
end
if ~success
    disp(['Could not make directory: ' backupName]);
end

copyDataFolder(original, backupName, originalFiles);

    function copyDataFolder(src, dest, dc)
        %recursive file copying from directory src to backup directory dest
        %given directory contents (dc)
        dc(strncmp({dc.name},'.',1)) = [];
        dc(strncmp({dc.name},'_backup_',1)) = [];
        
        
        % compare the files and subdirectories one by one
        for f = 1:numel(dc)
            source = fullfile(src,dc(f).name);
            target = fullfile(dest, dc(f).name);
            if dc(f).isdir
                copyDataFolder(source, target, dir(source));
            else
                if flagDisplayCopying
                    disp(['Copying ' dc(f).name]);
                end
                if exist(target,'file') == 0
                    copyfile(source, dest, 'f');
                else
                    cbFile = dir(target);
                    if dc(f).datenum > cbFile.datenum
                        copyfile(source, dest, 'f');
                    end
                end
            end
        end
    end
end
