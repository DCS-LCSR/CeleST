function updateData
global fileDB filenames CeleSTVersion;

flagDataBackedUp = false;

try
    if isempty(fileDB)
        return
    end
    
    dbLen = 1:length(fileDB);
    segmented = dbLen([fileDB(:).segmented]);
    measured = dbLen([fileDB(:).measured]);
    
    for segCheck = setdiff(segmented, measured)
        tmpFID = fopen(fullfile(filenames.segmentation,['wormSegm_',fileDB(segCheck).name,'.txt']), 'r');
        if tmpFID >= 3
            line1 = fgetl(tmpFID);
            if line1 ~= -1
                version = sscanf(line1, 'version %s');
                
                if ~strcmp(version, CeleSTVersion)
                    if ~flagDataBackedUp
                        backupData
                        flagDataBackedUp = true;
                    end
                    fileOut = {['version ' CeleSTVersion]};
                    if isempty(version)
                        fileOut{end+1} = line1;
                    end
                    textLine = fgetl(tmpFID);
                    while textLine ~= -1
                        fileOut{end+1} = textLine;
                        textLine = fgetl(tmpFID);
                    end
                    fclose(tmpFID);
                    
                    tmpFID = fopen(fullfile(filenames.segmentation,['wormSegm_',fileDB(segCheck).name,'.txt']), 'w');
                    for i = 1:length(fileOut)
                        fprintf(tmpFID, '%s\n', fileOut{i});
                    end
                end
            end
            fclose(tmpFID);
        end
    end
    
    for measAndSegCheck = intersect(segmented, measured)
        tmpMeasFID = fopen(fullfile(filenames.measures,['wormMeas_',fileDB(measAndSegCheck).name,'.txt']), 'r');
        if tmpMeasFID >= 3
            line1 = fgetl(tmpMeasFID);
            if line1 ~= -1
                version = sscanf(line1, 'version %s');
                
                if ~strcmp(version, CeleSTVersion)
                    if ~flagDataBackedUp
                        backupData
                        flagDataBackedUp = true;
                    end
                    fileOut = {['version ' CeleSTVersion]};
                    if isempty(version)
                        fileOut{end+1} = line1;
                    end
                    textLine = fgetl(tmpMeasFID);
                    while textLine ~= -1
                        if strcmp(textLine,'status')
                            status{1} = textLine;
                            fileOut{end+1} = textLine;
                            textLine = fgetl(tmpMeasFID);
                            while any(strcmpi(textLine, {'valid', 'reject', 'unchecked'}))
                                status{end+1} = textLine;
                                fileOut{end+1} = textLine;
                                textLine = fgetl(tmpMeasFID);
                            end
                        end
                        fileOut{end+1} = textLine;
                        textLine = fgetl(tmpMeasFID);
                    end
                    fclose(tmpMeasFID);
                    
                    tmpMeasFID = fopen(fullfile(filenames.measures,['wormMeas_',fileDB(measAndSegCheck).name,'.txt']), 'w');
                    for i = 1:length(fileOut)
                        fprintf(tmpMeasFID, '%s\n', fileOut{i});
                    end
                    
                end
            end
            fclose(tmpMeasFID);
        end
        
        
        tmpSegFID = fopen(fullfile(filenames.segmentation,['wormSegm_',fileDB(measAndSegCheck).name,'.txt']), 'r');
        if tmpSegFID >= 3
            line1 = fgetl(tmpSegFID);
            if line1 ~= -1
                version = sscanf(line1, 'version %s');
                
                if ~strcmp(version, CeleSTVersion)
                    if ~flagDataBackedUp
                        backupData
                        flagDataBackedUp = true;
                    end
                    fileOut = {['version ' CeleSTVersion]};
                    if isempty(version)
                        fileOut{end+1} = line1;
                    end
                    textLine = fgetl(tmpSegFID);
                    
                    while textLine ~= -1
                        if strncmpi(textLine, 'precision', 9)
                            fileOut{end+1} = textLine;
                            for i = 1:length(status)
                                fileOut{end+1} = status{i};
                            end
                            textLine = fgetl(tmpSegFID);
                        end
                        fileOut{end+1} = textLine;
                        textLine = fgetl(tmpSegFID);
                    end
                    fclose(tmpSegFID);
                    
                    tmpSegFID = fopen(fullfile(filenames.segmentation,['wormSegm_',fileDB(measAndSegCheck).name,'.txt']), 'w');
                    for i = 1:length(fileOut)
                        fprintf(tmpSegFID, '%s\n', fileOut{i});
                    end
                end
            end
            fclose(tmpSegFID);
        end
    end
catch exception
    generateReport(exception)
end
end
%#ok<*AGROW>