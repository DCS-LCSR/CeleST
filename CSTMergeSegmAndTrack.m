function CSTMergeSegmAndTrack(fileDBEntry, listOfWormsSegm, currentImageFileName, currentFrame, axesImage, nbOfFrames)
% Copyright (c) 2013 Rutgers
% Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
% The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
% THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.


global listOfWorms traceOn timingOn timings timingsTime plotAllOn flagRobustness fileToLog;

if timingOn; tic; end
if traceOn; fprintf(fileToLog, ['comparing frame ', num2str(currentFrame), ' from ', fileDBEntry.name,' : ', currentImageFileName, '\n']); end
if plotAllOn; hold(axesImage, 'on'); end

% ===========
% LOAD THE IMAGE
% ===========
if plotAllOn
    try
        currentImage = double(imread( fullfile( fileDBEntry.directory, currentImageFileName) ));
    catch em
        if flagRobustness
            fprintf(fileToLog, ['***   There was an error reading file: ', num2str(currentImageFileName),' , skipping this file. ***','\n']);
            fprintf(fileToLog, [getReport(em, 'basic'),'\n']);
            return
        else
            rethrow(em)
        end
    end
    imagesc(currentImage,'parent', axesImage);
end

try    
    nbOfWormsSegm = length(listOfWormsSegm.skel);
    nbOfWormsTrack = length(listOfWorms.skel);
    cosDraw = cos(2*pi*(0:48)/48);
    sinDraw = sin(2*pi*(0:48)/48);
    % ===========
    % COMPUTE THE BOUNDING BOXES OF ALL WORMS
    % ===========
    bboxT = zeros(4, nbOfWormsTrack);
    for wormT = 1:nbOfWormsTrack
        cbl = listOfWorms.skel{wormT}{currentFrame};
        width = listOfWorms.width{wormT}{currentFrame};
        if plotAllOn
            listOfIndices = 1:length(cbl);
            tmp = zeros(2, length(listOfIndices)*length(cosDraw));
            for vv = 1:length(listOfIndices)
                tmp(:,(vv-1)*length(cosDraw)+(1:length(cosDraw))) = [cbl(1,listOfIndices(vv))+width(listOfIndices(vv))*cosDraw ; ...
                    cbl(2,listOfIndices(vv))+width(listOfIndices(vv))*sinDraw];
            end
            plot(tmp(1,:), tmp(2,:), '-r', 'parent', axesImage,'linewidth', 2)
            plot(cbl(1,:), cbl(2,:), '-r')
        end
        bboxT(:,wormT) = [ floor(min(cbl(2,:)-width));... % row min
            ceil( max(cbl(2,:)+width));... % row max
            floor(min(cbl(1,:)-width));... % col min
            ceil( max(cbl(1,:)+width))...  % col max
            ];
    end
    bboxS = zeros(4, nbOfWormsSegm);
    riskOfOverlap = false(nbOfWormsSegm, nbOfWormsTrack);
    for wormS = 1:nbOfWormsSegm
        cbl = listOfWormsSegm.skel{wormS};
        width = listOfWormsSegm.width{wormS};
        if plotAllOn
            listOfIndices = 1:length(cbl);
            tmp = zeros(2, length(listOfIndices)*length(cosDraw));
            for vv = 1:length(listOfIndices)
                tmp(:,(vv-1)*length(cosDraw)+(1:length(cosDraw))) = [cbl(1,listOfIndices(vv))+width(listOfIndices(vv))*cosDraw ; ...
                    cbl(2,listOfIndices(vv))+width(listOfIndices(vv))*sinDraw];
            end
            plot(tmp(1,:), tmp(2,:), '-g', 'parent', axesImage,'linewidth', 1)
            plot(cbl(1,:), cbl(2,:), '-g')
        end
        bboxS(:,wormS) = [  floor(min(cbl(2,:)-width));... % row min
            ceil( max(cbl(2,:)+width));... % row max
            floor(min(cbl(1,:)-width));... % col min
            ceil( max(cbl(1,:)+width))...  % col max
            ];
        riskOfOverlap(wormS, :) = ( (bboxS(1,wormS) <= bboxT(2,:)) & (bboxT(1,:) <= bboxS(2,wormS))...
                                  & (bboxS(3,wormS) <= bboxT(4,:)) & (bboxT(3,:) <= bboxS(4,wormS)));
    end
    % -----------
    % Compute the matching between the worms
    % -----------
    overlapVertices = Inf(nbOfWormsSegm,nbOfWormsTrack);
    for wormS = 1:nbOfWormsSegm
        cblS = listOfWormsSegm.skel{wormS};
        widthS = listOfWormsSegm.width{wormS};
        for wormT = 1:nbOfWormsTrack
            if riskOfOverlap(wormS, wormT)
                cblT = listOfWorms.skel{wormT}{currentFrame};
                widthT = listOfWorms.width{wormT}{currentFrame};
                distStoT = zeros(1,length(widthS));
                for idx = 1:length(widthS)
                    % ...........
                    % Take width into account
                    % ...........
                    distStoT(idx) = min(hypot(cblT(1,:) - cblS(1,idx), cblT(2,:) - cblS(2,idx)) - widthT - widthS(idx));
                end
                overlapVertices(wormS, wormT) = mean(distStoT);
            end
        end
    end
    % -----------
    % Match worms that agree with each other
    % -----------
    matchesTtoS = zeros(1,nbOfWormsTrack);
    unmatchedT = false(1,nbOfWormsTrack);
    for wormT = 1:nbOfWormsTrack
        % Find the best match
        [valTmp, bestMatchS] = min(overlapVertices(:, wormT));
        if valTmp < 0
            % found a match
            matchesTtoS(wormT) = bestMatchS;
        else
            unmatchedT(wormT) = true;
        end
    end
    finalMatchesStoT = zeros(1,nbOfWormsSegm);
    finalMatchesTtoS = zeros(1,nbOfWormsTrack);
    unmatchedS = false(1, nbOfWormsSegm);
    for wormS = 1:nbOfWormsSegm
        [valTmp, bestMatchT] = min(overlapVertices(wormS,:));
        if valTmp < 0
            if matchesTtoS(bestMatchT) == wormS
                % agreed
                finalMatchesStoT(wormS) = bestMatchT;
                finalMatchesTtoS(bestMatchT) = wormS;
            else
            end
        else
            % missed
            unmatchedS(wormS) = true;
        end
    end
    
    % -----------
    % Match worms that have been left out
    % -----------
    for wormT = find(unmatchedT)
        cblT = listOfWorms.skel{wormT}{currentFrame};
        widthT = listOfWorms.width{wormT}{currentFrame};
        for wormS = find(unmatchedS)
            % Compare how well they match
            cblS = listOfWormsSegm.skel{wormS};
            widthS = listOfWormsSegm.width{wormS};
            distStoT = zeros(1,length(widthS));
            for idx = 1:length(widthS)
                distStoT(idx) = min(hypot(cblT(1,:) - cblS(1,idx), cblT(2,:) - cblS(2,idx)) - widthT - widthS(idx));
            end
            ratioOverlapStoT = sum(distStoT < 0) / length(distStoT);
            distTtoS = zeros(1,length(widthT));
            for idx = 1:length(widthT)
                distTtoS(idx) = min(hypot(cblS(1,:) - cblT(1,idx), cblS(2,:) - cblT(2,idx)) - widthS - widthT(idx));
            end
            ratioOverlapTtoS = sum(distTtoS < 0) / length(distTtoS);
            if ratioOverlapTtoS * ratioOverlapStoT >= 0.25
                % ok, try to match them
                if finalMatchesStoT(wormS) == 0 && finalMatchesTtoS(wormT) == 0
                    % no other candidates so far
                    finalMatchesStoT(wormS) = wormT;
                    finalMatchesTtoS(wormT) = wormS;
                else
                    % there were other candidates, too ambiguous, leave all worms as such
                    if finalMatchesStoT(wormS) ~= 0
                        finalMatchesTtoS(finalMatchesStoT(wormS)) = Inf;
                    end
                    if finalMatchesTtoS(wormT) ~= 0
                        finalMatchesStoT(finalMatchesTtoS(wormT)) = Inf;
                    end
                    finalMatchesStoT(wormS) = Inf;
                    finalMatchesTtoS(wormT) = Inf;
                end
            end
        end
    end
    
    % -----------
    % Update matching worms
    % -----------
    for wormT = 1:nbOfWormsTrack
        if isfinite(finalMatchesTtoS(wormT)) && finalMatchesTtoS(wormT) ~= 0
            % update wormT by wormS
            listOfWorms.skel{wormT}{currentFrame} = listOfWormsSegm.skel{finalMatchesTtoS(wormT)};
            listOfWorms.width{wormT}{currentFrame} = listOfWormsSegm.width{finalMatchesTtoS(wormT)};
            listOfWorms.localthreshold{wormT} = listOfWormsSegm.localthreshold{finalMatchesTtoS(wormT)};
            listOfWorms.lengthWorms(wormT,currentFrame) = listOfWormsSegm.lengthWorms(finalMatchesTtoS(wormT));
        end
    end
    
    % -----------
    % Try to match to lost worms, even if no overlap
    % -----------
    lostWormsT = find(listOfWorms.lost(:, currentFrame))';
    if ~isempty(lostWormsT)
        for wormS = find(finalMatchesStoT == 0)
            centerS = mean(listOfWormsSegm.skel{wormS},2);
            % -----------
            % Compare with lost worms
            % -----------
            distances = Inf(1,nbOfWormsTrack);
            for lostWorm = lostWormsT
                centerT = mean(listOfWorms.skel{lostWorm}{currentFrame},2);
                distances(lostWorm) = norm(centerS - centerT);
            end
            [valTmp, wormT] = min(distances);
            if ~isinf(valTmp)
                listOfWorms.skel{wormT}{currentFrame} = listOfWormsSegm.skel{wormS};
                listOfWorms.width{wormT}{currentFrame} = listOfWormsSegm.width{wormS};
                listOfWorms.localthreshold{wormT} = listOfWormsSegm.localthreshold{wormS};
                listOfWorms.lengthWorms(wormT,currentFrame) = listOfWormsSegm.lengthWorms(wormS);
                finalMatchesStoT(wormS) = wormT;
                listOfWorms.missed(wormT,currentFrame) = false;
                listOfWorms.lost(wormT,currentFrame) = false;
                if traceOn; fprintf(fileToLog, ['found lost worm ', num2str(wormS), ' using ', num2str(wormT), '\n']); end
            end
        end
    end
        
    % -----------
    % Create new worms if need be
    % -----------
    for wormS = find(finalMatchesStoT == 0)
        newWorm = 1 + length(listOfWorms.skel);
        listOfWorms.skel{newWorm} = cell(nbOfFrames,1);
        listOfWorms.width{newWorm} = cell(nbOfFrames,1);
        for frame = 1:currentFrame
            listOfWorms.skel{newWorm}{frame} = listOfWormsSegm.skel{wormS};
            listOfWorms.width{newWorm}{frame} = listOfWormsSegm.width{wormS};
        end
        listOfWorms.lengthWorms(newWorm,currentFrame) = listOfWormsSegm.lengthWorms(wormS);
        listOfWorms.localthreshold{newWorm} = listOfWormsSegm.localthreshold{wormS};
        listOfWorms.missed(newWorm,:) = false;
        listOfWorms.lost(newWorm,nbOfFrames:end) = false;
        listOfWorms.lost(newWorm,1:nbOfFrames-1) = true;
        listOfWorms.overlapped(newWorm,:) = false;
    end
catch em
    if flagRobustness
        if traceOn; fprintf(fileToLog, ['***   There was an error matching worms ','\n']); end
        if traceOn; fprintf(fileToLog, [getReport(em, 'basic'),'\n']); end
    else
        rethrow(em)
    end
end
if timingOn; timings(11) = timings(11) + toc ;timingsTime(11) = timingsTime(11)+1; tic; end

end

