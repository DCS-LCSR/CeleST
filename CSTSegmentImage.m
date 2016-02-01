function [fileDBEntry,listOfWormsEntry] = CSTSegmentImage(fileDBEntry, currentImageFileName, currentFrameForProcessing, axesImage)

% Copyright (c) 2013 Rutgers
% Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
% The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
% THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

% -------------------
% Look for worms on single image
% -------------------
global currentImage zoneOkForCompleteWorms zoneOkForStartingWorms traceOn timingOn timings timingsTime plotAllOn flagRobustness fileToLog flagVIP;

plotAllOn = true;

if timingOn; tic; end
if traceOn; fprintf(fileToLog, ['processing frame ', num2str(currentFrameForProcessing), ' from ', fileDBEntry.name,' : ', currentImageFileName, '\n']); end

if plotAllOn; hold(axesImage, 'on');end

% -------------------
% Initialize variables
% -------------------
rangeImage = 0:256;
imHeight = 0;
imWidth = 0;
listOfWormsEntry.skel = cell(1,0);
listOfWormsEntry.width = cell(1,0);
listOfWormsEntry.localthreshold = cell(1,0);
filterMask = ones(5,5);
flatMask = ones(5,5);
flatMask([1,5,21,25]) = 0;
flatMask = flatMask / sum(sum(flatMask));
templateDistLength = 300;
templateDist = realsqrt(repmat((-templateDistLength:templateDistLength).^2,2*templateDistLength+1,1) + repmat((-templateDistLength:templateDistLength)'.^2,1,2*templateDistLength+1));
% ===========
% LOAD THE IMAGE
% ===========
try
    currentImage = double(imread( fullfile( fileDBEntry.directory, currentImageFileName) ));
    imHeight = size(currentImage,1);
    imWidth = size(currentImage,2);
catch em
    if flagRobustness
        fprintf(fileToLog, ['***   There was an error reading file: ',fullfile(fileDBEntry.directory, currentImageFileName),' , skipping this file. ***','\n']);
        fprintf(fileToLog, [getReport(em, 'basic'),'\n']);
        return
    else
        rethrow(em)
    end
end
if timingOn; timings(1) = timings(1) + toc ; timingsTime(1) = timingsTime(1) + 1 ; tic; end
% ===========
% GET THE INSIDE BORDER OF THE CICRLE WHERE WORMS ARE SWIMMING
% ===========
if isempty(fileDBEntry.well)
    maxX = round(imWidth/2);
    maxY = round(imHeight/2);
    newRayon = realsqrt(imWidth^2 + imHeight^2)/2;
else
    % -----------
    % If pre-defined, read it from the file entry
    % -----------
    if ischar(fileDBEntry.well)
        fileDBEntry.well = str2num(fileDBEntry.well); %#ok<*ST2NM>
    end
    maxX = fileDBEntry.well(1);
    maxY = fileDBEntry.well(2);
    newRayon = fileDBEntry.well(3);
end

% -----------
% Define the vertices at the edges of the well and the image
% -----------
nbVerticesEdge = 400;
wellMarginSize = 1;
imageMarginSize = 1;
xOkForCompleteWorms = min(imWidth-imageMarginSize, max(imageMarginSize, fix(maxX + (newRayon-wellMarginSize) .*cos(2.*(1:nbVerticesEdge)*pi/nbVerticesEdge))));
yOkForCompleteWorms = min(imHeight-imageMarginSize, max(imageMarginSize, fix(maxY + (newRayon-wellMarginSize) .*sin(2.*(1:nbVerticesEdge)*pi/nbVerticesEdge))));

if plotAllOn; plot(xOkForCompleteWorms, yOkForCompleteWorms,'--m', 'parent', axesImage);end
B = bwboundaries(zoneOkForCompleteWorms);
if plotAllOn; plot(B{1}(:,2), B{1}(:,1),'--r', 'parent', axesImage);end


% ===========
% PRE-PROCESS THE IMAGE
% ===========
% -----------
% Compute the standard deviation on small patches of smoothed image
% -----------
imageProcForBorders = stdfilt(medfilt2(currentImage,[3 3],'symmetric'),filterMask);
% -----------
% Compute the gradient on that preprocessed image
% -----------
[FXProc,FYProc] = gradient(imageProcForBorders,1);
% -----------
% Smooth that gradient
% -----------
FXProcSmooth = imfilter(FXProc,flatMask, 'symmetric');
FYProcSmooth = imfilter(FYProc, flatMask, 'symmetric');
FXProcSmooth = imfilter(FXProcSmooth,flatMask, 'symmetric');
FYProcSmooth = imfilter(FYProcSmooth, flatMask, 'symmetric');
intGradProc = hypot(FXProcSmooth, FYProcSmooth);

% -----------
% Clip the image to the disk where worms are swimming
% -----------
currentImage = currentImage .* zoneOkForCompleteWorms;
% -----------
% keep track of the potential pixels where to look for local maxima on the preprocessed image (they correspond to the worm's border)
% -----------
potentialMax = zoneOkForStartingWorms;
if timingOn; timings(2) = timings(2) + toc ; timingsTime(2) = timingsTime(2) + 1 ; tic; end

% ===========
% PREPARE THE ADJUSTMENT OF WORM MODELS TO THE PRE-PROCESSED IMAGE AND GRADIENT FIELDS
% ===========
% -----------
% Neighborhood to mask as investigated around pixels that have been included in a model
% -----------
se = strel('square',7);
% -----------
% Distance in pixel between vertices in the candidate border surrounding the worms
% -----------
stepSize = 0.2; % Previous parameter from 'Lab' Version
% stepSize = 0.1;
% -----------
% Neighborhood to mark as part of the candidate border, around vertices of that border, to check when the border get closed
% -----------
taggedPixels = [[ 0 1 1 0]; [ 0 0 1 1 ]];
% ...........
% Alternative 3x3 neighborhood:
% taggedPixels = [[-1 0 1 -1 0 1 -1 0 1]; [-1 -1 -1 0 0 0 1 1 1 ]];
% ...........
% -----------
% Number of vertices at the head of the candidate border that shouldn't be included in the test for closure
% -----------
tail = ceil(size(taggedPixels,2)* (1/stepSize) * 4) ;
% -----------
% Index of the latest worm being built
% -----------
worm = 0;
% -----------
% Minimum gradient intensity used to normalize gradient vectors into unit vector (to avoid division by zero or by very small number)
% -----------
% gradientMinimum = 0.01; % Previous parameter from 'Lab' Version
gradientMinimum = 0.001;

% -----------
% Maximum gradient intensity, half of it will be the minimum value to consider as a starting point for a candidate border
% -----------
valGradMax = Inf;
listOfWormsPotential.skel = cell(1,0);
listOfWormsPotential.width = cell(1,0);
listOfWormsPotential.localthreshold = cell(1,0);
for wormCandidate = 1:50
    try
        
        % ===========
        % BUILD A CANDIDATE BORDER
        % ===========
        % -----------
        % Find the point with maximum gradient value in the unexplored zone (indicated by potentialMax)
        % -----------
        [valMaxInCol, indicesInRows] = max(potentialMax .* intGradProc);
        [valM, maxX] = max(valMaxInCol);
        maxY = indicesInRows(maxX);
        % -----------
        % Construct a border from that point
        % -----------
        flagClosedWorm = false;
        flagGradientTooSmall = false;
        flagReachedTheEdge = false;
        direction = -1;
        % -----------
        % First point
        % -----------
        boundCandidate = [maxX ; maxY];
        if wormCandidate == 1
            % ...........
            % For the very first worm, store the maximum gradient intensity
            % ...........
            valGradMax = valM;
        elseif (valM <= valGradMax / 2)
            % ...........
            % For other worms, check that the starting point has an intensity above half of the global maximum, otherwise stop
            % ...........
            break
        end
        coordsInt = floor(0.5 + boundCandidate(:, end));
        
        % -----------
        % Successive points: interpolate the gradient at each point
        % -----------
        iter = 1;
        interpGradCandidate = [];
        while iter <= 10000 && ~(flagClosedWorm || flagReachedTheEdge || flagGradientTooSmall)
            iter = iter + 1;
            % -----------
            % Interpolate the gradient at the location of the latest point
            % -----------
            lastPoint = boundCandidate(:,end);
            lastPointInt = floor(lastPoint);
            lastPointRelative = lastPoint - lastPointInt;
            lastPointInt = max([1;1], min([imWidth-1;imHeight-1], lastPointInt));
            interpGradCandidate(1) = (1 - lastPointRelative(2)) * ( (1 - lastPointRelative(1)) * FXProcSmooth(lastPointInt(2),  lastPointInt(1))...
                + lastPointRelative(1)  * FXProcSmooth(lastPointInt(2),  lastPointInt(1)+1) )...
                + lastPointRelative(2) * ( (1 - lastPointRelative(1)) * FXProcSmooth(lastPointInt(2)+1,lastPointInt(1))...
                + lastPointRelative(1)  * FXProcSmooth(lastPointInt(2)+1,lastPointInt(1)+1) );
            interpGradCandidate(2) = (1 - lastPointRelative(2)) * ( (1 - lastPointRelative(1)) * FYProcSmooth(lastPointInt(2),  lastPointInt(1))...
                + lastPointRelative(1)  * FYProcSmooth(lastPointInt(2),  lastPointInt(1)+1) )...
                + lastPointRelative(2) * ( (1 - lastPointRelative(1)) * FYProcSmooth(lastPointInt(2)+1,lastPointInt(1))...
                + lastPointRelative(1)  * FYProcSmooth(lastPointInt(2)+1,lastPointInt(1)+1) );
            % -----------
            % Define the new point
            % -----------
            newPoint = boundCandidate(:, end) + direction * stepSize * [-interpGradCandidate(2); interpGradCandidate(1)] / max(gradientMinimum,norm(interpGradCandidate));
            boundCandidate(:, end + 1) = newPoint; %#ok<*AGROW>
            newPixel = min([imWidth-1; imHeight-1], max(2,floor(0.5 + newPoint)));
            % -----------
            % Store the intenger pixel coordinates belonging to the candidate border and its neighborhood, to check for closure
            % -----------
            coordsInt = [coordsInt , [newPixel(1) + taggedPixels(1,:); newPixel(2) + taggedPixels(2,:)]];
            % -----------
            % Check if the gradient is too small
            % -----------
            flagGradientTooSmall = (norm(interpGradCandidate) <= gradientMinimum);
            % -----------
            % Check if the border is closed yet
            % -----------
            flagClosedWorm = any( (coordsInt(1,1:end-tail)==newPixel(1)) & (coordsInt(2,1:end-tail)==newPixel(2)));
            % -----------
            % Check if the border has reached the edge of the well
            % -----------
            flagReachedTheEdge = ~(zoneOkForCompleteWorms(newPixel(2), newPixel(1))) ;
        end
        
        % -----------
        % Special case: when the border has reached the edge of the inner circle where worms swim, still need to investigate the other direction as well
        % -----------
        if flagReachedTheEdge
            % -----------
            % Construct the other side of the border from the starting point
            % -----------
            flagClosedWorm = false;
            flagGradientTooSmall = false;
            flagReachedTheEdge = false;
            % -----------
            % Opposite direction
            % -----------
            direction = 1;
            % -----------
            % Successive points: interpolate the gradient at each point
            % -----------
            iter = 1;
            interpGradCandidate = [];
            while iter <= 10000 && ~(flagClosedWorm || flagReachedTheEdge || flagGradientTooSmall)
                iter = iter + 1;
                % -----------
                % Interpolate the gradient at the location of the latest point: Opposite order
                % -----------
                lastPoint = boundCandidate(:,1);
                lastPointInt = floor(lastPoint);
                lastPointRelative = lastPoint - lastPointInt;
                lastPointInt = max([1;1], min([imWidth-1;imHeight-1], lastPointInt));
                interpGradCandidate(1) = (1 - lastPointRelative(2)) * ( (1 - lastPointRelative(1)) * FXProcSmooth(lastPointInt(2),  lastPointInt(1))...
                    + lastPointRelative(1)  * FXProcSmooth(lastPointInt(2),  lastPointInt(1)+1) )...
                    + lastPointRelative(2) * ( (1 - lastPointRelative(1)) * FXProcSmooth(lastPointInt(2)+1,lastPointInt(1))...
                    + lastPointRelative(1)  * FXProcSmooth(lastPointInt(2)+1,lastPointInt(1)+1) );
                interpGradCandidate(2) = (1 - lastPointRelative(2)) * ( (1 - lastPointRelative(1)) * FYProcSmooth(lastPointInt(2),  lastPointInt(1))...
                    + lastPointRelative(1)  * FYProcSmooth(lastPointInt(2),  lastPointInt(1)+1) )...
                    + lastPointRelative(2) * ( (1 - lastPointRelative(1)) * FYProcSmooth(lastPointInt(2)+1,lastPointInt(1))...
                    + lastPointRelative(1)  * FYProcSmooth(lastPointInt(2)+1,lastPointInt(1)+1) );
                % -----------
                % Define the new point: Opposite order (building the border the other way now)
                % -----------
                newPoint = boundCandidate(:, 1) + direction * stepSize * [-interpGradCandidate(2); interpGradCandidate(1)] / max(gradientMinimum,norm(interpGradCandidate));
                boundCandidate = [newPoint, boundCandidate];
                newPixel = min([imWidth-1; imHeight-1], max(2,floor(0.5 + newPoint)));
                % -----------
                % Store the intenger pixel coordinates belonging to the candidate border and its neighborhood, to check for closure
                % -----------
                coordsInt = [ [newPixel(1) + taggedPixels(1,:); newPixel(2) + taggedPixels(2,:)] , coordsInt];
                % -----------
                % Check if the gradient is too small
                % -----------
                flagGradientTooSmall = (norm(interpGradCandidate) <= gradientMinimum);
                % -----------
                % Check if the border is closed yet: Opposite start
                % -----------
                flagClosedWorm = any( (coordsInt(1,tail:end)==newPixel(1)) & (coordsInt(2,tail:end)==newPixel(2)));
                % -----------
                % Check if the border has reached the edge of the well
                % -----------
                flagReachedTheEdge = ~(zoneOkForCompleteWorms(newPixel(2), newPixel(1))) ;
            end
            % -----------
            % Final check: if the other side of the border has also reached the edge
            % -----------
            if flagReachedTheEdge
                % -----------
                % Find the edge vertex closest to the head of the border
                % -----------
                [valTmp, locHead] = min(hypot(xOkForCompleteWorms - boundCandidate(1,1), yOkForCompleteWorms - boundCandidate(2,1))); %#ok<*ASGLU>
                [valTmp, locTail] = min(hypot(xOkForCompleteWorms - boundCandidate(1,end), yOkForCompleteWorms - boundCandidate(2,end)));
                locMin = min(locHead, locTail);
                locMax = max(locHead, locTail);
                nbVertices = length(xOkForCompleteWorms);
                if ( locMax-locMin < nbVertices - (locMax-locMin))
                    % short edge: direct from min to max
                    edgePath = locMin:locMax;
                else
                    % short edge: indirect from max to min via 1
                    edgePath = [locMin:-1:1,nbVertices:-1:locMax];
                end
                if (locMin == locHead)
                    boundCandidate = [ boundCandidate, [xOkForCompleteWorms(edgePath') ; yOkForCompleteWorms(edgePath')] ];
                else
                    boundCandidate = [ boundCandidate, [xOkForCompleteWorms(edgePath) ; yOkForCompleteWorms(edgePath)] ];
                end
                % -----------
                % Now the border is closed
                % -----------
                flagClosedWorm = true;
            end
        end
        
        % ===========
        % MARK THE ZONE SURROUNDING THE CANDIDATE BORDER AS 'EXPLORED'
        % ===========
        maskWorm = zeros(size(potentialMax));
        if flagClosedWorm
            % -----------
            % If the border is closed, mark its inside as explored
            % -----------
            maskWorm = poly2mask(boundCandidate(1,:), boundCandidate(2,:), size(potentialMax,1), size(potentialMax,2));
            maskWorm(sub2ind(size(potentialMax), coordsInt(2,:), coordsInt(1,:))) = 1;
        else
            % -----------
            % If the border is not closed, only mark the pixels on its vertices as explored
            % -----------
            maskWorm(sub2ind(size(potentialMax), coordsInt(2,:), coordsInt(1,:))) = 1;
        end
        potentialMax(imdilate(maskWorm,se) > 0) = false;
        if plotAllOn; plot(boundCandidate(1,[1:end,1]), boundCandidate(2,[1:end,1]),':m', 'parent', axesImage); end
        if timingOn; timings(3) = timings(3) + toc ; timingsTime(3) = timingsTime(3) + 1 ; tic; end
        
        % =============
        % BUILD A WORM BORDER WITHIN THE CANDIDATE BORDER
        % =============
        bound = boundCandidate;
        % -------------
        % Smooth the border at the connection between the two ends
        % -------------
        % .............
        % five new points are going to be added to the border
        % .............
        smoothedVertices = zeros(size(bound) + [0,5]);
        % .............
        % smooth several times, with increasing range
        % .............
        nbOfIter = 0;
        for sizeTmp = 1:25
            try
                smoothedVertices = smoothedVertices + [bound(:,1+sizeTmp:end-sizeTmp) , interp1([1,5+2*sizeTmp], bound(:,[end-sizeTmp+1,sizeTmp])', 1:5+2*sizeTmp)'];
                nbOfIter = nbOfIter + 1;
            catch  %#ok<CTCH>
                break
            end
        end
        bound = smoothedVertices / max(1, nbOfIter);
        if plotAllOn; plot(bound(1,[1:end,1]), bound(2,[1:end,1]),':r', 'parent', axesImage); end
        
        % -------------
        % Tighten the vertices
        % -------------
        interpGrad = zeros(size(bound));
        for iterTight = 1:20
            % -------------
            % Compute the unit vectors normal to the border, they show the direction of the tightening
            % -------------
            normals = bound(:,[2:end,1]) - bound;
            norms = hypot(normals(1,:), normals(2,:));
            normals = [-normals(2,:)./norms; normals(1,:)./norms];
            % -------------
            % Interpolate the gradient value at the location of the vertices
            % -------------
            coords = bound;
            coordsInteg = floor(coords);
            coordsDecim = coords - coordsInteg;
            nbOfRows = size(FXProc,1);
            coordsIdx = nbOfRows * max(1, min(imWidth,coordsInteg(1,:))) + max(1,min(imHeight-1,coordsInteg(2,:)));
            interpGrad(1,:) = (1-coordsDecim(2,:)) .* ( (1-coordsDecim(1,:)) .* FXProc(coordsIdx - nbOfRows)...
                +   coordsDecim(1,:)  .* FXProc(coordsIdx))...
                +  coordsDecim(2,:)  .* ( (1-coordsDecim(1,:)) .* FXProc(coordsIdx - nbOfRows + 1)...
                +   coordsDecim(1,:)  .* FXProc(coordsIdx + 1));
            interpGrad(2,:) = (1-coordsDecim(2,:)) .* ( (1-coordsDecim(1,:)) .* FYProc(coordsIdx - nbOfRows)...
                +   coordsDecim(1,:)  .* FYProc(coordsIdx))...
                +  coordsDecim(2,:)  .* ( (1-coordsDecim(1,:)) .* FYProc(coordsIdx - nbOfRows + 1)...
                +   coordsDecim(1,:)  .* FYProc(coordsIdx + 1));
            % -------------
            % Compute the intensity of the move of all the vertices, depending on the dot product between the normal and the gradient
            % -------------
            dotProd = abs(dot(normals, interpGrad));
            normGrad = max(0.001,hypot(interpGrad(1,:), interpGrad(2,:)));
            move = interpGrad .* [dotProd ./ (30*normGrad) ; dotProd ./ (30*normGrad)];
            % -------------
            % Compute the new location of the vertices
            % -------------
            bound = bound + move;
            % -------------
            % Re-sample the vertices to smooth the border and avoid vertex clustering
            % -------------
            curvCoord = cumsum(max(0.0001,hypot(bound(1,[2:end,1]) - bound(1,:), bound(2,[2:end,1]) - bound(2,:))));
            bound = interp1q(curvCoord', bound', linspace(curvCoord(1),curvCoord(end),floor(length(curvCoord)/5))')';
            bound = interp1q((1:length(bound))', bound', linspace(1,length(bound),length(curvCoord))')';
        end
        if timingOn; timings(2) = timings(2) + toc ; timingsTime(2) = timingsTime(2) + 1 ; tic; end
        if plotAllOn; plot(bound(1,[1:end,1]), bound(2,[1:end,1]),':y', 'parent', axesImage); end
        
        % -------------
        % Compute the appearance threshold
        % -------------
        thresholdAppearance = getThresholdIntensityAroundWorm(bound);
        if timingOn; timings(4) = timings(4) + toc ; timingsTime(4) = timingsTime(4) + 1 ; tic; end
        
        % -------------
        % Find a point inside the worm, for future reference
        % -------------
        pointInside = getPointInsideWorm(bound, thresholdAppearance);
        
        % ------------
        % Define a subimage containing the border, with extra margin that may contain unsegmented worm parts
        % ------------
        extRange = 50;
        bbox = [    floor(min(bound(2,:)))-extRange,... % row min
            ceil( max(bound(2,:)))+extRange,... % row max
            floor(min(bound(1,:)))-extRange,... % col min
            ceil( max(bound(1,:)))+extRange ... % col max
            ];
        bbox = min(max(bbox, [1, -Inf, 1, -Inf]), [Inf imHeight Inf imWidth]);
        % ------------
        % Compute the CBL inside the worm border
        % ------------
        [xyskel, width] = findWormCBLWithinSubRegion(bbox, thresholdAppearance, pointInside);
        if timingOn; timings(5) = timings(5) + toc ; timingsTime(5) = timingsTime(5) + 1 ; tic; end
        
        if ~(isempty(xyskel) || any(isnan(xyskel(:))))
            intCoord = round(xyskel);
            intCoord(1,:) = max(1, min(size(currentImage,2), intCoord(1,:)));
            intCoord(2,:) = max(1, min(size(currentImage,1), intCoord(2,:)));
            valuesCBL = currentImage(sub2ind(size(currentImage), intCoord(2,:), intCoord(1,:)));
            cblMean = mean(valuesCBL(:));
            threshMinAcceptable = cblMean / 3;
            if (thresholdAppearance < threshMinAcceptable)
                thresholdAppearance = threshMinAcceptable;
                [xyskel, width] = findWormCBLWithinSubRegion(bbox, thresholdAppearance, pointInside);
            end
            if timingOn; timings(5) = timings(5) + toc ; timingsTime(5) = timingsTime(5) + 1 ; tic; end
        else
            if timingOn; timings(5) = timings(5) + toc ; timingsTime(5) = timingsTime(5) + 1 ; tic; end
            if plotAllOn; plot(bound(1,[1:end,1]), bound(2,[1:end,1]),':c', 'parent', axesImage); end
            continue
        end
        
        oldBound = bound;
        % ------------
        % Compute the new worm border from the CBL
        % ------------
        worm = worm + 1;
        listOfWormsPotential.skel{worm} = xyskel;
        listOfWormsPotential.width{worm} = width;
        listOfWormsPotential.localthreshold{worm} = thresholdAppearance;
        if timingOn; timings(6) = timings(6) + toc ; timingsTime(6) = timingsTime(6) + 1 ; tic; end
        % ===========
        % LOOK FOR OTHER WORMS IN THE BORDER THAT MAY HAVE BEEN LEFT OUT DURING THE WORM RECONSTRUCTION
        % ===========
        % Compare the border obtained from CBL+width with the original borders:
        %  - if a large bit is missing, try and segment another worm inside the missing part.
        %  - if they don't overlap, discard as noise
        extRange = max(width) + 10; %
        bbox = [    floor(min([xyskel(2,:) - extRange, oldBound(2,:)])),... % row min
            ceil(max([xyskel(2,:)  + extRange, oldBound(2,:)])),... % row max
            floor(min([xyskel(1,:) - extRange, oldBound(1,:)])),... % col min
            ceil(max([xyskel(1,:)  + extRange, oldBound(1,:)]))...  % col max
            ];
        bbox = min(max(bbox, [1, -Inf, 1, -Inf]), [Inf imHeight Inf imWidth]);
        bbox = double(bbox);
        subImage = currentImage(bbox(1):bbox(2), bbox(3):bbox(4));
        maskCBLWidth = false(size(subImage));
        for vv = 1:length(xyskel)
            localCenter = templateDistLength + 1 - fix(xyskel(:,vv)-[bbox(3);bbox(1)]+1);
            maskCBLWidth((templateDist(localCenter(2)+1:localCenter(2)+size(subImage,1),localCenter(1)+1:localCenter(1)+size(subImage,2)) < (width(vv) + 1))) = true;
        end
        % ------------
        % Find connected regions that were in the original worm border (post tightening) and left out by the worm reconstruction from CBL+width
        % ------------
        maskOriginal = poly2mask(oldBound(1,:)-bbox(3)+1, oldBound(2,:)-bbox(1)+1, size(subImage,1), size(subImage,2));
        forgotten = ~maskCBLWidth & maskOriginal & (subImage > thresholdAppearance);
        [labelForgotten, numForgotten] = bwlabel(forgotten);
        if timingOn; timings(7) = timings(7) + toc ; timingsTime(7) = timingsTime(7) + 1 ; tic; end
        for numtmp = 1:numForgotten
            currentNum = numel(find(labelForgotten == numtmp));
            % ------------
            % Only consider regions of sufficient size
            % ------------
            if currentNum >= 10
                possiblePixels = forgotten .* (labelForgotten == numtmp);
                % ------------
                % Compute a CBL+width within those pixels
                % ------------
                [xyskelNew, widthNew] = findWormCBLWithinFixedMask(bbox, possiblePixels);
                if isempty(xyskelNew); continue; end
                % ------------
                % Reconstruct a border
                % ------------
                boundNew = wormGetVariableBorderFromSkeleton(xyskelNew, widthNew);
                if isempty(boundNew)
                    continue
                end
                % ------------
                % Store as a potential worm
                % ------------
                thresholdAppearanceNew = getThresholdIntensityAroundWorm(boundNew);
                worm = worm + 1;
                listOfWormsPotential.skel{worm} = xyskelNew;
                listOfWormsPotential.width{worm} = widthNew;
                listOfWormsPotential.localthreshold{worm} = thresholdAppearanceNew;
                if timingOn; timings(6) = timings(6) + toc ; timingsTime(6) = timingsTime(6) + 1 ; tic; end
            end
        end
    catch em
        if flagRobustness
            fprintf(fileToLog, ['***   There was an error segmenting worm candidate: ',num2str(worm),' , skipping this worm. ***','\n']);
            fprintf(fileToLog, [getReport(em, 'basic'),'\n']);
        else
            rethrow(em)
        end
        continue
    end
end


% =============
% CHECK THE QUALITY OF THE SEGMENTED WORMS, AND DECIDE WHICH ONES TO KEEP
% =============
listOfWormsFiltered.skel = cell(1,0);
listOfWormsFiltered.width = cell(1,0);
listOfWormsFiltered.localthreshold = cell(1,0);
for currentWorm = 1:length(listOfWormsPotential.skel)
    try
        % -------------
        % Check the lengths and widths of the worms
        % -------------
        longueur = floor(sum(hypot(listOfWormsPotential.skel{currentWorm}(1,2:end)-listOfWormsPotential.skel{currentWorm}(1,1:end-1),...
            listOfWormsPotential.skel{currentWorm}(2,2:end)-listOfWormsPotential.skel{currentWorm}(2,1:end-1))));
        maxWidth = max(listOfWormsPotential.width{currentWorm});
        meanWidth = mean(listOfWormsPotential.width{currentWorm});
        flagLength = (longueur >= 15) && (longueur <= 120);
        flagWidth1 = (maxWidth <= 2 * meanWidth);
        flagWidth2 = (maxWidth <= 8) && (meanWidth <= 5);
        if flagLength && flagWidth1 && flagWidth2
            listOfWormsFiltered.skel{end+1} = listOfWormsPotential.skel{currentWorm};
            listOfWormsFiltered.width{end+1} = listOfWormsPotential.width{currentWorm};
            listOfWormsFiltered.localthreshold{end+1} = listOfWormsPotential.localthreshold{currentWorm};
        else
            if flagVIP
                % figure to let users choose if it's a worm or not
                % including a yes or no button, the image in question, and
                % a question
            end
        end
    catch em
        if flagRobustness
            fprintf(fileToLog, ['***   There was an error segmenting worm candidate: ',num2str(currentWorm),' , skipping this worm. ***','\n']);
            fprintf(fileToLog, [getReport(em, 'basic'),'\n']);
        else
            rethrow(em)
        end
        continue
    end
end
if timingOn; timings(8) = timings(8) + toc ; timingsTime(8) = timingsTime(8) + 1 ; tic; end
flagsFilteredToKeep = true(size(listOfWormsFiltered.skel));
for currentWorm = 1:length(listOfWormsFiltered.skel)
    try
        currentCBL = listOfWormsFiltered.skel{currentWorm};
        currentWidth = mean(listOfWormsFiltered.width{currentWorm});
        currentStd = std(listOfWormsFiltered.width{currentWorm});
        for concurrentWorm = (currentWorm+1):length(listOfWormsFiltered.skel)
            concurrentCBL = listOfWormsFiltered.skel{concurrentWorm};
            % compare the CBL
            minDistCurrentToConc = Inf;
            for currentVertex = 1:size(currentCBL,2)
                minDistCurrentToConc = min([minDistCurrentToConc, hypot( concurrentCBL(1,:) - currentCBL(1,currentVertex) , concurrentCBL(2,:) - currentCBL(2,currentVertex) ) ]);
            end
            concurrentStd = std(listOfWormsFiltered.width{concurrentWorm});
            if (minDistCurrentToConc < currentWidth)
                extra = ' ********';
                if traceOn; fprintf(fileToLog, ['worm ', num2str(currentWorm), ' vs ', num2str(concurrentWorm), ': dist= ', num2str(minDistCurrentToConc), ' vs ', num2str(currentWidth),...
                        ' ; width ', num2str(currentStd), ' vs ', num2str(concurrentStd), extra,'\n']); end
                if concurrentStd > currentStd
                    flagsFilteredToKeep(concurrentWorm) = false;
                else
                    flagsFilteredToKeep(currentWorm) = false;
                end
            end
        end
    catch em
        if flagRobustness
            fprintf(fileToLog, ['***   There was an error segmenting worm candidate: ',num2str(worm),' , skipping this worm. ***','\n']);
            fprintf(fileToLog, [getReport(em, 'basic'),'\n']);
        else
            rethrow(em)
        end
        continue
    end
end
if timingOn; timings(8) = timings(8) + toc ; timingsTime(8) = timingsTime(8) + 1 ; tic; end
nbOfWorms = sum(flagsFilteredToKeep(:));
newWormIdx = 0;
listOfWormsEntry.skel = cell(1,nbOfWorms);
listOfWormsEntry.width = cell(1,nbOfWorms);
listOfWormsEntry.localthreshold = cell(1,nbOfWorms);
listOfWormsEntry.lengthWorms = zeros(nbOfWorms);
for currentWorm = 1:length(flagsFilteredToKeep)
    try
        if flagsFilteredToKeep(currentWorm)
            newWormIdx = newWormIdx + 1;
            listOfWormsEntry.skel{newWormIdx} = listOfWormsFiltered.skel{currentWorm};
            listOfWormsEntry.width{newWormIdx} = listOfWormsFiltered.width{currentWorm};
            listOfWormsEntry.localthreshold{newWormIdx} = listOfWormsFiltered.localthreshold{currentWorm};
            listOfWormsEntry.lengthWorms(newWormIdx) = sum(hypot(listOfWormsEntry.skel{newWormIdx}(1,2:end)-listOfWormsEntry.skel{newWormIdx}(1,1:end-1),...
                listOfWormsEntry.skel{newWormIdx}(2,2:end)-listOfWormsEntry.skel{newWormIdx}(2,1:end-1)));
        end
    catch em
        if flagRobustness
            fprintf(fileToLog, ['***   There was an error segmenting worm candidate: ',num2str(worm),' , skipping this worm. ***','\n']);
            fprintf(fileToLog, [getReport(em, 'basic'),'\n']);
        else
            rethrow(em)
        end
        continue
    end
end
if timingOn; timings(6) = timings(6) + toc ; timingsTime(6) = timingsTime(6) + 1 ; tic; end


% ******************************************
% ******************************************
% **                                      **
% **           SUBFUNCTIONS               **
% **                                      **
% ******************************************
% ******************************************



% -------------
% compute the appearance threshold
% -------------
    function thresholdAppearance = getThresholdIntensityAroundWorm(bound)
        bound = double(bound);
        distMinForBck = 5;
        distMaxForBck = 20;
        extRange = distMaxForBck;
        bbox = [    floor(min(bound(2,:)-extRange)),... % row min
            ceil( max(bound(2,:)+extRange)),... % row max
            floor(min(bound(1,:)-extRange)),... % col min
            ceil( max(bound(1,:)+extRange))...  % col max
            ];
        bbox = min(max(bbox, [1, -Inf, 1, -Inf]), [Inf imHeight Inf imWidth]);
        subImage = currentImage(bbox(1):bbox(2), bbox(3):bbox(4));
        localBound = [bound(1,:)- bbox(3)+1 ; bound(2,:) - bbox(1)+1];
        maskWorm = poly2mask(localBound(1,:), localBound(2,:), size(subImage,1), size(subImage,2));
        inside = cumsum(hist(subImage(maskWorm),rangeImage));
        inside = inside / inside(end);
        maskOutside = bwdist(maskWorm);
        outside = cumsum(hist(subImage(maskOutside > distMinForBck & maskOutside < distMaxForBck),rangeImage));
        outside = 1 - outside / outside(end);
        [tmpV, thresholdAppearance] = max((inside - outside) > 0);
        thresholdAppearance = thresholdAppearance - 1;
    end

% -------------
% Find a point inside the worm, for future reference
% -------------
    function pointInside = getPointInsideWorm(bound, thresholdAppearance)
        extRange = 0;
        bbox = [    floor(min(bound(2,:))-extRange),... % row min
            ceil( max(bound(2,:))+extRange),... % row max
            floor(min(bound(1,:))-extRange),... % col min
            ceil( max(bound(1,:))+extRange)...  % col max
            ];
        bbox = min(max(bbox, [1, -Inf, 1, -Inf]), [Inf imHeight Inf imWidth]);
        subImage = currentImage(bbox(1):bbox(2), bbox(3):bbox(4));
        localBound = [bound(1,:)- bbox(3)+1 ; bound(2,:) - bbox(1)+1];
        maskWorm = poly2mask(localBound(1,:), localBound(2,:), size(subImage,1), size(subImage,2));
        intCoord = floor(0.5+localBound);
        intCoord(1,:) = max(1, min(size(maskWorm,2), intCoord(1,:)));
        intCoord(2,:) = max(1, min(size(maskWorm,1), intCoord(2,:)));
        maskWorm(sub2ind(size(maskWorm), intCoord(2,:), intCoord(1,:))) = true;
        [valMaxInCol, indicesInRows] = max(bwdist(~maskWorm) .* (subImage - thresholdAppearance));
        [widthMax, maxX] = max(valMaxInCol);
        maxY = indicesInRows(maxX);
        pointInside = [maxX+bbox(3)-1; maxY+bbox(1)-1];
    end

% ------------
% Find a worm (CBL + width) within a sub-rectangular part of currentImage, above a given threshold, and optionnally containing a given pixel location.
% ------------
    function [xyskel, width] = findWormCBLWithinSubRegion(bbox, appearThreshold, pointInside)
        if nargin < 2; xyskel = []; width = []; return; end
        flagPointInside = (nargin >= 3);
        if timingOn; tic; end
        subImage = currentImage(bbox(1):bbox(2), bbox(3):bbox(4));
        % ------------
        % supersample this subpart of the image
        % ------------
        magnifFactor = 2;
        bboxNew = bbox;
        bboxNew = magnifFactor * bboxNew;
        [xgg,ygg] = meshgrid(1:(1/magnifFactor):size(subImage,2)-1, 1:(1/magnifFactor):size(subImage,1)-1);
        coords = [xgg(:)';ygg(:)'];
        coordsInteg = floor(coords);
        coordsDecim = coords - coordsInteg;
        nbOfRows = size(subImage,1);
        coordsIdx = nbOfRows * coordsInteg(1,:) + coordsInteg(2,:);
        subImageSurSampled = zeros(size(xgg));
        subImageSurSampled(:) = (1-coordsDecim(2,:)) .* ( (1-coordsDecim(1,:)) .* subImage(coordsIdx - nbOfRows)...
            +   coordsDecim(1,:)  .* subImage(coordsIdx))...
            +  coordsDecim(2,:)  .* ( (1-coordsDecim(1,:)) .* subImage(coordsIdx - nbOfRows + 1)...
            +   coordsDecim(1,:)  .* subImage(coordsIdx + 1));
        if timingOn; timings(9) = timings(9) + toc ; timingsTime(9) = timingsTime(9) + 1 ; tic; end
        % ------------
        % threshold the supersampled image with appearance, keep the binary component containing the inside point found above,
        % compute the distance transform of that component, where the CBL will be constructed
        % ------------
        if flagPointInside
            tmpLbls = bwlabel( subImageSurSampled >= appearThreshold);
            maskWorm = (tmpLbls == tmpLbls(magnifFactor*pointInside(2)-bboxNew(1)+1, magnifFactor*pointInside(1)-bboxNew(3)+1));
        else
            maskWorm = (subImageSurSampled >= appearThreshold);
        end
        if timingOn; timings(9) = timings(9) + toc ; timingsTime(9) = timingsTime(9) + 1 ; tic; end
        [xyskel, width] = findWormCBLWithinMask(maskWorm, bboxNew, magnifFactor);
    end

% ------------
% Find a worm (CBL + width) within a pregiven mask (no other parts of the image will be investigated), which is going to be supersampled
% ------------
    function [xyskel, width] = findWormCBLWithinFixedMask(bbox, maskOriginal)
        if timingOn; tic; end
        % ------------
        % supersample the submask
        % ------------
        magnifFactor = 2;
        bbox = magnifFactor * bbox;
        [xgg,ygg] = meshgrid(1:(1/magnifFactor):size(maskOriginal,2)-1, 1:(1/magnifFactor):size(maskOriginal,1)-1);
        coords = [xgg(:)';ygg(:)'];
        coordsInteg = floor(coords);
        coordsDecim = coords - coordsInteg;
        nbOfRows = size(maskOriginal,1);
        coordsIdx = nbOfRows * coordsInteg(1,:) + coordsInteg(2,:);
        subImageSurSampled = zeros(size(xgg));
        subImageSurSampled(:) = (1-coordsDecim(2,:)) .* ( (1-coordsDecim(1,:)) .* maskOriginal(coordsIdx - nbOfRows)...
            +   coordsDecim(1,:)  .* maskOriginal(coordsIdx))...
            +  coordsDecim(2,:)  .* ( (1-coordsDecim(1,:)) .* maskOriginal(coordsIdx - nbOfRows + 1)...
            +   coordsDecim(1,:)  .* maskOriginal(coordsIdx + 1));
        if timingOn; timings(9) = timings(9) + toc ; timingsTime(9) = timingsTime(9) + 1 ; tic; end
        % ------------
        % threshold the supersampled image with appearance
        % ------------
        maskWorm = (subImageSurSampled >= 0.5);
        if timingOn; timings(9) = timings(9) + toc ; timingsTime(9) = timingsTime(9) + 1 ; tic; end
        [xyskel, width] = findWormCBLWithinMask(maskWorm, bbox, magnifFactor);
    end

% ------------
% Build a CBL+width out of binary mask supposed to be the location of a worm. The 1 values should be foreground. First, this function inverts the
% image to compute the distance transform in the foreground. Then, it builds a CBL along the crest of that distance transform, and returns the CBL
% location and width. It is finally resampled to ensure the CBL vertices are 0.2 pxl apart.
% ------------
    function [xyskel, width] = findWormCBLWithinMask(maskWhereToLook, bbox, magnifFactor)
        maskInside = bwdist(~maskWhereToLook);
        
        rangeAnglesMax = 48;
        rangeAngles = 1:rangeAnglesMax;
        % ------------
        % find the deepest point
        % ------------
        [valMaxInCol, indicesInRows] = max(maskInside);
        [widthMax, maxX] = max(valMaxInCol);
        maxY = indicesInRows(maxX);
        if widthMax > 10*magnifFactor
            xyskel = [];
            width = [];
            return
        end
        % ------------
        % start growing the CBL from there
        % ------------
        xyskel = [maxX; maxY];
        width = widthMax;
        lastAngle = 0;
        searchForward = true;
        flagFirst = true;
        firstAngle = 0;
        firstWidth = 0;
        keepBuildingCBL = true;
        stepCBLSize = widthMax;
        % ------------
        % find successive points
        % ------------
        while keepBuildingCBL
            iter = 0;
            % ------------
            % need two iterations, one in each direction (forward and backward from the starting point)
            % ------------
            keepLookingInCurrentDirection = true;
            while keepLookingInCurrentDirection
                iter = iter + 1;
                % ------------
                % compute the coordinates for all the candidates for the next point
                % ------------
                if searchForward
                    candidsX = xyskel(1,end) + (stepCBLSize+4) * cos( 2*pi* (lastAngle+rangeAngles)/rangeAnglesMax);
                    candidsY = xyskel(2,end) + (stepCBLSize+4) * sin( 2*pi* (lastAngle+rangeAngles)/rangeAnglesMax);
                else
                    candidsX = xyskel(1,1) + (stepCBLSize+4) * cos( 2*pi* (lastAngle+rangeAngles)/rangeAnglesMax);
                    candidsY = xyskel(2,1) + (stepCBLSize+4) * sin( 2*pi* (lastAngle+rangeAngles)/rangeAnglesMax);
                end
                % ------------
                % compute the distance values at the candidates
                % ------------
                coords = [candidsX;candidsY];
                coordsInteg = floor(coords);
                coordsDecim = coords - coordsInteg;
                nbOfRows = size(maskInside,1);
                nbOfCols = size(maskInside,2);
                coordsIdx = nbOfRows * max(2,min(nbOfCols-1,coordsInteg(1,:))) + max(1,min(nbOfRows-1,coordsInteg(2,:)));
                interpDist = (1-coordsDecim(2,:)) .* ( (1-coordsDecim(1,:)) .* maskInside(coordsIdx - nbOfRows)...
                    +   coordsDecim(1,:)  .* maskInside(coordsIdx))...
                    +  coordsDecim(2,:)  .* ( (1-coordsDecim(1,:)) .* maskInside(coordsIdx - nbOfRows + 1)...
                    +   coordsDecim(1,:)  .* maskInside(coordsIdx + 1));
                % ------------
                % find the maximum value, that's the next point
                % ------------
                [widthMax,indNext] = max(interpDist);
                newPoint = [candidsX(indNext);candidsY(indNext)];
                lastAngle = lastAngle + rangeAngles(indNext);
                localCenter = templateDistLength+1-fix(newPoint);
                nbRowsTmp = size(maskInside,1);
                nbColsTmp = size(maskInside,2);
                maskInside((templateDist(max(1,min(size(templateDist,1),localCenter(2)+(1:nbRowsTmp))),max(1,min(size(templateDist,2),localCenter(1)+(1:nbColsTmp)))) < (widthMax + 1))) = 0;
                stepCBLSize = widthMax;
                % ------------
                % after the very first point, change the range of angles to search for other points
                % ------------
                if flagFirst
                    flagFirst = false;
                    firstAngle = rangeAngles(indNext);
                    firstWidth = widthMax;
                    rangeAngles = -(rangeAnglesMax/8):(rangeAnglesMax/8);
                end
                % ------------
                % store the latest point
                % ------------
                flagTimeOut = (newPoint(1) <= 1) || (newPoint(1) >= nbOfCols) || (newPoint(2) <= 1) || (newPoint(2) >= nbOfRows);
                if ~flagTimeOut
                    if searchForward
                        xyskel(:,end+1) = newPoint;
                        width(end+1) = widthMax;
                    else
                        xyskel = [newPoint , xyskel];
                        width = [widthMax, width];
                    end
                end
                keepLookingInCurrentDirection = (~flagTimeOut) && (iter <= 50) && (widthMax > 1);
            end
            % ------------
            % repeat a second time, to grow the CBL in the other direction
            % ------------
            if searchForward
                searchForward = false;
                keepBuildingCBL = true;
                lastAngle = firstAngle + rangeAnglesMax/2;
                lastWidth = firstWidth;
                stepCBLSize = lastWidth;
            else
                keepBuildingCBL = false;
            end
        end
        % ------------
        % adjust the coordinates to the original image coordinates
        % ------------
        xyskel(1,:) = (xyskel(1,:) + bbox(3)) / magnifFactor;
        xyskel(2,:) = (xyskel(2,:) + bbox(1)) / magnifFactor;
        
        width = width / magnifFactor;
    end

    function xyBorder = wormGetVariableBorderFromSkeleton(xySkel, wormWidth)
        % This function returns the x,y coordinates of the vertices forming the
        % border of a worm specified by its skeleton vertices x,y coordinates
        % xySkel and the typical half-width in pixels, wormWidth
        %
        % Paramters:
        %  . xySkel: the x,y coordinates of the skeleton vertices, from head to
        %     tail with one column per vertex.
        %  . wormWidth: the half-width of the worm, in pixels
        %
        % Returns:
        %  . xyBorder: the x,y coordinates of the border vertices, from head to
        %     tail clockwise and back to head at the other side. The head vertex is
        %     repeated at the end. There is one column per vertex.
        nbOfPoints = size(xySkel,2);
        if nbOfPoints <= 0
            xyBorder = [];
            return
        elseif nbOfPoints == 1
            xyBorder = [xySkel(1,1)+[-wormWidth 0 wormWidth 0 -wormWidth] ; xySkel(2,1)+[0 wormWidth 0 -wormWidth 0]];
            return
        end
        sides = xySkel(:,[2:end,end]) - xySkel(:,[1:end-1,end-1]);
        norms = hypot(sides(1,:), sides(2,:));
        normals = [-sides(2,:)./norms ; sides(1,:)./norms];
        normals = (normals(:,[1:end-1,end-1]) + normals(:,[2:end,end])) / 2;
        norms = hypot(normals(1,:), normals(2,:));
        normals = [wormWidth.*normals(1,:)./norms ; wormWidth.*normals(2,:)./norms];
        xyBorder = [xySkel(:,1)-wormWidth(:,1).*sides(:,1) , xySkel + normals ,...
            xySkel(:,end)+wormWidth(:,end).*sides(:,end) , xySkel(:,end:-1:1) - normals(:,end:-1:1)];
    end

end
