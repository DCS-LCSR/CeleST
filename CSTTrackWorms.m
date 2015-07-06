function CSTTrackWorms(fileDBEntry, currentImageFileName, currentFrame, axesImage)
% Copyright (c) 2013 Rutgers
% Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
% The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
% THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.


global listOfWorms currentImage zoneOkForCompleteWorms traceOn timingOn timings  timingsTime plotAllOn flagRobustness fileToLog;

% -------------------
% Adjust worms on single image
% -------------------

if timingOn; tic; end
if traceOn; fprintf(fileToLog, ['processing frame ', num2str(currentFrame), ' from ', fileDBEntry.name,' : ', currentImageFileName, '\n']); end %#ok<*UNRCH>
if plotAllOn; hold(axesImage, 'on'); end

% -------------------
% Initialize variables
% -------------------
cosDraw = cos(2*pi*(0:48)/48);
sinDraw = sin(2*pi*(0:48)/48);

pointsCircleTr = (2*pi*(1:48)/48)';
cosCircleTr = cos(pointsCircleTr);
onesCircleTr = ones(length(cosCircleTr),1);
sinCircleTr = sin(pointsCircleTr);
% -----------
% Points surrounding each vertex, where the image values will be compared to the local threshold
% -----------
nbOfPoints = 48;
pointsCircle = (2*pi*(1:nbOfPoints)/nbOfPoints);
cosCircle = cos(pointsCircle);
sinCircle = sin(pointsCircle);

% -----------
% Range of angles used to define the candidates for the new location of the joint and the extremity
% -----------
angleAddVertex = 5;
thetaAddVertex = angleAddVertex/360*2*pi;
nbAnglesAddVertex = 6;
kJointRangeAddVertex = ([0, kron(1:nbAnglesAddVertex, [1 -1])]) * thetaAddVertex;

% -----------
% Range of angles used to define the candidates for the new location of the joint and the extremity
% -----------
angleFit = 5;
nbAnglesFit = 4;
theta = angleFit/360*2*pi;
kJointRange = ([0, kron(1:nbAnglesFit, [1 -1])])*theta;
kExtremRange = ([0, kron(1:nbAnglesFit, [1 -1])])*theta;
cosMin = 0.5;

nbOfWorms = length(listOfWorms.skel);


imHeight = size(currentImage,1);
imWidth = size(currentImage,2);
if plotAllOn; imagesc(currentImage,'parent', axesImage); end

% ===========
% GET THE INSIDE BORDER OF THE CICRLE WHERE WORMS ARE SWIMMING
% ===========
% -----------
% Clip the image
% -----------
currentImage = zoneOkForCompleteWorms .* currentImage;
B = bwboundaries(zoneOkForCompleteWorms);
if plotAllOn; plot(B{1}(:,2), B{1}(:,1),'--r', 'parent', axesImage);end

rangeToExtrem = 0.1;
rangeToMiddle = 0.35;

idxStationHead = zeros(nbOfWorms);
idxStationTail = zeros(nbOfWorms);

% ===========
% DETECT POTENTIAL OVERLAP BETWEEN WORMS
% ===========
% -----------
% bounding box of the potential locations of the worm
% -----------
bbox = zeros(4,nbOfWorms);
% -----------
% pairs of worm which may overlap: boolean riskOfOverlap(worm, prevWorm) with 1 <= prevWorm < worm
% -----------
riskOfOverlap = false(nbOfWorms, nbOfWorms);

% ===========
% COMPUTE AND STORE THE POSSIBLE EXTREME LOCATIONS OF EACH WORM
% ===========
% -----------
% potential locations of the CBL: same spot, twitching to one side, twitching to the other side
% -----------
cblSame = cell(1,nbOfWorms);
cblRot1 = cell(1,nbOfWorms);
cblRot2 = cell(1,nbOfWorms);
for worm = 1:nbOfWorms
    if listOfWorms.lost(worm, currentFrame-1); continue; end
    try
        % -----------
        % Start from the location on the previous frame
        % -----------
        localThr = listOfWorms.localthreshold{worm};
        cblOri = listOfWorms.skel{worm}{currentFrame-1};
        widthOri = listOfWorms.width{worm}{currentFrame-1};
        cblNew = cblOri;
        nbOfIndices = length(widthOri);
        longueurs = [0, cumsum(hypot(cblNew(1,2:end)-cblNew(1,1:end-1), cblNew(2,2:end)-cblNew(2,1:end-1)))];
        totalLongueur = longueurs(end);
        
        % -----------
        % Find a stationary point in each half of the body
        % -----------
        % ...........
        % Find a stationary point towards the head
        % ...........
        [valTmp, idxStationHeadLow] = max(longueurs >= rangeToExtrem*totalLongueur); %#ok<*ASGLU>
        [valTmp, idxStationHeadHigh] = max(longueurs >= rangeToMiddle*totalLongueur);
        rangeSearch = max(3, idxStationHeadLow):max(4, idxStationHeadHigh);
        pointsTested = round(onesCircleTr*cblOri(1,rangeSearch) + cosCircleTr*widthOri(rangeSearch) -1)*imHeight + round(onesCircleTr*cblOri(2,rangeSearch) + sinCircleTr*widthOri(rangeSearch));
        fitness = sum(max(0,localThr-currentImage(pointsTested)));
        [valTmp, idx] = min(fitness);
        idxStationHead(worm) = rangeSearch(idx);
        % ...........
        % Find a stationary point towards the tail
        % ...........
        [valTmp, idxStationTailLow] = max(longueurs >= (1-rangeToMiddle)*totalLongueur);
        [valTmp, idxStationTailHigh] = max(longueurs >= (1-rangeToExtrem)*totalLongueur);
        rangeSearch = min(nbOfIndices-3, idxStationTailLow-1):min(nbOfIndices-2, idxStationTailHigh-1);
        pointsTested = round(onesCircleTr*cblOri(1,rangeSearch) + cosCircleTr*widthOri(rangeSearch) -1)*imHeight + round(onesCircleTr*cblOri(2,rangeSearch) + sinCircleTr*widthOri(rangeSearch));
        fitness = sum(max(0,localThr-currentImage(pointsTested)));
        [valTmp, idx] = min(fitness);
        idxStationTail(worm) = rangeSearch(idx);
        % ...........
        % Define the mid-point
        % ...........
        idxMiddle = round((idxStationHead(worm)+idxStationTail(worm))/2);
        
        % -----------
        % Compute the two extreme rotations of the CBL
        % -----------
        cbl1 = cblOri;
        cbl2 = cblOri;
        % ...........
        % Define the extreme angles
        % ...........
        angleExtrem = 30/360*2*pi;
        angleMiddle = 20/360*2*pi;
        % ...........
        % Compute the extreme positions of the heading part of the cbl
        % ...........
        rangeToRotate = 1:(idxStationHead(worm)-1);
        onesTmp = ones(size(rangeToRotate));
        cbl1(:,rangeToRotate) = cbl1(:,idxStationHead(worm))*onesTmp + [cos(angleExtrem), sin(angleExtrem) ; -sin(angleExtrem), cos(angleExtrem)] * (cbl1(:,rangeToRotate) - cbl1(:,idxStationHead(worm))*onesTmp);
        cbl2(:,rangeToRotate) = cbl2(:,idxStationHead(worm))*onesTmp + [cos(angleExtrem), -sin(angleExtrem) ; sin(angleExtrem), cos(angleExtrem)] * (cbl2(:,rangeToRotate) - cbl2(:,idxStationHead(worm))*onesTmp);
        % ...........
        % Compute the extreme positions of the tailing part of the cbl
        % ...........
        rangeToRotate = (idxStationTail(worm)+1):nbOfIndices;
        onesTmp = ones(size(rangeToRotate));
        cbl1(:,rangeToRotate) = cbl1(:,idxStationTail(worm))*onesTmp + [cos(angleExtrem), -sin(angleExtrem) ; sin(angleExtrem), cos(angleExtrem)] * (cbl1(:,rangeToRotate) - cbl1(:,idxStationTail(worm))*onesTmp);
        cbl2(:,rangeToRotate) = cbl2(:,idxStationTail(worm))*onesTmp + [cos(angleExtrem), sin(angleExtrem) ; -sin(angleExtrem), cos(angleExtrem)] * (cbl2(:,rangeToRotate) - cbl2(:,idxStationTail(worm))*onesTmp);
        % ...........
        % Compute the extreme positions of the middle part of the cbl
        % ...........
        rangeToRotate = (idxStationHead(worm)+1):idxMiddle;
        onesTmp = ones(size(rangeToRotate));
        cbl1(:,rangeToRotate) = cbl1(:,idxStationHead(worm))*onesTmp + [cos(angleMiddle), -sin(angleMiddle) ; sin(angleMiddle), cos(angleMiddle)] * (cbl1(:,rangeToRotate) - cbl1(:,idxStationHead(worm))*onesTmp);
        cbl2(:,rangeToRotate) = cbl2(:,idxStationHead(worm))*onesTmp + [cos(angleMiddle), sin(angleMiddle) ; -sin(angleMiddle), cos(angleMiddle)] * (cbl2(:,rangeToRotate) - cbl2(:,idxStationHead(worm))*onesTmp);
        rangeToRotate = (idxMiddle+1):(idxStationTail(worm)-1);
        onesTmp = ones(size(rangeToRotate));
        cbl1(:,rangeToRotate) = cbl1(:,idxStationTail(worm))*onesTmp + [cos(angleMiddle), sin(angleMiddle) ; -sin(angleMiddle), cos(angleMiddle)] * (cbl1(:,rangeToRotate) - cbl1(:,idxStationTail(worm))*onesTmp);
        cbl2(:,rangeToRotate) = cbl2(:,idxStationTail(worm))*onesTmp + [cos(angleMiddle), -sin(angleMiddle) ; sin(angleMiddle), cos(angleMiddle)] * (cbl2(:,rangeToRotate) - cbl2(:,idxStationTail(worm))*onesTmp);
        
        % -----------
        % Store all the potential positions
        % -----------
        cblSame{worm} = cblOri;
        cblRot1{worm} = cbl1;
        cblRot2{worm} = cbl2;
        % ...........
        % Plot the potential positions if need be
        % ...........
        if plotAllOn
            plot(cblOri(1,[idxStationHead(worm), idxStationTail(worm)]), cblOri(2,[idxStationHead(worm), idxStationTail(worm)]), '-*m');
            listOfIndices = 1:length(cblOri);
            tmp = zeros(2, length(listOfIndices)*length(cosDraw));
            for vv = 1:length(listOfIndices)
                tmp(:,(vv-1)*length(cosDraw)+(1:length(cosDraw))) = [cbl1(1,listOfIndices(vv))+widthOri(listOfIndices(vv))*cosDraw ; ...
                    cbl1(2,listOfIndices(vv))+widthOri(listOfIndices(vv))*sinDraw];
            end
            plot(tmp(1,:), tmp(2,:), ':b', 'parent', axesImage)
            for vv = 1:length(listOfIndices)
                tmp(:,(vv-1)*length(cosDraw)+(1:length(cosDraw))) = [cbl2(1,listOfIndices(vv))+widthOri(listOfIndices(vv))*cosDraw ; ...
                    cbl2(2,listOfIndices(vv))+widthOri(listOfIndices(vv))*sinDraw];
            end
            plot(tmp(1,:), tmp(2,:), ':b', 'parent', axesImage)
        end
        
        % -----------
        % Compute the bounding box of all potential positions
        % -----------
        bbox(:,worm) = [ floor(min([cblOri(2,:)-widthOri, cbl1(2,:)-widthOri, cbl2(2,:)-widthOri]));... % row min
            ceil( max([cblOri(2,:)+widthOri, cbl1(2,:)+widthOri, cbl2(2,:)+widthOri]));... % row max
            floor(min([cblOri(1,:)-widthOri, cbl1(1,:)-widthOri, cbl2(1,:)-widthOri]));... % col min
            ceil( max([cblOri(1,:)+widthOri, cbl1(1,:)+widthOri, cbl2(1,:)+widthOri]))...  % col max
            ];
        bbox(:,worm) = min(max(bbox(:,worm), [1; -Inf; 1; -Inf]), [Inf; imHeight; Inf; imWidth]);
        % -----------
        % Check the overlap of the bounding box with the previous worms
        % -----------
        rangePrev = 1:(worm-1);
        riskOfOverlap(worm, rangePrev) = ( (bbox(1,worm) <= bbox(2,rangePrev)) & (bbox(1,rangePrev) <= bbox(2,worm))...
            & (bbox(3,worm) <= bbox(4,rangePrev)) & (bbox(3,rangePrev) <= bbox(4,worm)));
    catch em
        if flagRobustness
            fprintf(fileToLog, ['***   There was an error tracking worm: ',num2str(worm),' , skipping this worm. ***','\n']);
            fprintf(fileToLog, [getReport(em, 'basic'),'\n']);
            listOfWorms.skel{worm}{currentFrame} = listOfWorms.skel{worm}{currentFrame-1};
            listOfWorms.width{worm}{currentFrame} = listOfWorms.width{worm}{currentFrame-1};
            listOfWorms.missed(worm, currentFrame) = true;
        else
            rethrow(em)
        end
    end
end
% ...........
% Plot the bounding boxes if need be
% ...........
if plotAllOn
    for worm = 1:nbOfWorms
        if any(riskOfOverlap(worm,:)) || any(riskOfOverlap(:,worm)); couleur = '-r'; else couleur = '-c'; end
        plot(bbox([3 3 4 4 3 ], worm), bbox([1 2 2 1 1 ], worm), couleur);
    end
end

% ===========
% DETECT POTENTIAL OVERLAP OF INVIDIDUAL VERTICES
% ===========
% -----------
% riskyVertices{worm}: contains a boolean array, one value per vertex.
% -----------
riskyVertices = cell(1,nbOfWorms);
for worm = 1:nbOfWorms
    if listOfWorms.lost(worm, currentFrame-1); continue; end
    try
        riskyVertices{worm} = false(size(listOfWorms.width{worm}{currentFrame-1}));
        for prevWorm = 1:(worm-1)
            if (~listOfWorms.lost(prevWorm, currentFrame-1)) && riskOfOverlap(worm, prevWorm)
                for idx = 1:length(cblSame{worm})
                    % -----------
                    % check against Same
                    % -----------
                    longueursOri =                   hypot(cblSame{prevWorm}(1,:) - cblSame{worm}(1,idx), cblSame{prevWorm}(2,:) - cblSame{worm}(2,idx));
                    longueursOri = min(longueursOri, hypot(cblRot1{prevWorm}(1,:) - cblSame{worm}(1,idx), cblRot1{prevWorm}(2,:) - cblSame{worm}(2,idx)));
                    longueursOri = min(longueursOri, hypot(cblRot2{prevWorm}(1,:) - cblSame{worm}(1,idx), cblRot2{prevWorm}(2,:) - cblSame{worm}(2,idx)));
                    % -----------
                    % check against Rot1
                    % -----------
                    longueursOri = min(longueursOri, hypot(cblSame{prevWorm}(1,:) - cblRot1{worm}(1,idx), cblSame{prevWorm}(2,:) - cblRot1{worm}(2,idx)));
                    longueursOri = min(longueursOri, hypot(cblRot1{prevWorm}(1,:) - cblRot1{worm}(1,idx), cblRot1{prevWorm}(2,:) - cblRot1{worm}(2,idx)));
                    longueursOri = min(longueursOri, hypot(cblRot2{prevWorm}(1,:) - cblRot1{worm}(1,idx), cblRot2{prevWorm}(2,:) - cblRot1{worm}(2,idx)));
                    % -----------
                    % check against Rot2
                    % -----------
                    longueursOri = min(longueursOri, hypot(cblSame{prevWorm}(1,:) - cblRot2{worm}(1,idx), cblSame{prevWorm}(2,:) - cblRot2{worm}(2,idx)));
                    longueursOri = min(longueursOri, hypot(cblRot1{prevWorm}(1,:) - cblRot2{worm}(1,idx), cblRot1{prevWorm}(2,:) - cblRot2{worm}(2,idx)));
                    longueursOri = min(longueursOri, hypot(cblRot2{prevWorm}(1,:) - cblRot2{worm}(1,idx), cblRot2{prevWorm}(2,:) - cblRot2{worm}(2,idx)));
                    % -----------
                    % Take width into account
                    % -----------
                    longueursOri = longueursOri - listOfWorms.width{prevWorm}{currentFrame-1};
                    longueursOri = longueursOri - listOfWorms.width{worm}{currentFrame-1}(idx);
                    % -----------
                    % Detect potential vertex overlap
                    % -----------
                    if any(longueursOri <= 0)
                        riskyVertices{prevWorm} = riskyVertices{prevWorm} | (longueursOri <= 0);
                        riskyVertices{worm}(idx) = any(longueursOri <= 0);
                    end
                end
            end
        end
    catch em
        if flagRobustness
            fprintf(fileToLog, ['***   There was an error tracking worm: ',num2str(worm),' , skipping this worm. ***','\n']);
            fprintf(fileToLog, [getReport(em, 'basic'),'\n']);
            listOfWorms.skel{worm}{currentFrame} = listOfWorms.skel{worm}{currentFrame-1};
            listOfWorms.width{worm}{currentFrame} = listOfWorms.width{worm}{currentFrame-1};
            listOfWorms.missed(worm, currentFrame) = true;
        else
            rethrow(em)
        end
    end
end
% ...........
% Plot the risky vertices if need be
% ...........
if plotAllOn
    for worm = 1:nbOfWorms
        listRisk = riskyVertices{worm};
        if ~isempty(listRisk) && any(listRisk)
            plot(listOfWorms.skel{worm}{currentFrame-1}(1,listRisk), listOfWorms.skel{worm}{currentFrame-1}(2,listRisk),'*y')
        end
    end
end

        if timingOn; timings(12) = timings(12) + toc ; timingsTime(12) = timingsTime(12) + 1 ; tic; end


% ===========
% ADJUST WORMS ONE BY ONE, STARTING WITH THE NON-RISKY VERTICES
% ===========

for worm = 1:nbOfWorms
    if listOfWorms.lost(worm, currentFrame-1); continue; end
    try
        
        % ===========
        % START FROM THE LOCATION ON THE PREVIOUS FRAME
        % ===========
        localThr = listOfWorms.localthreshold{worm};
        cblOri = listOfWorms.skel{worm}{currentFrame-1};
        widthOri = listOfWorms.width{worm}{currentFrame-1};
        cblNew = cblOri;
        nbOfIndices = length(widthOri);
        
        % ===========
        % RETRIEVE THE STATIONARY POINTS IN EACH HALF OF THE BODY
        % ===========
        fixedHead = idxStationHead(worm);
        cblNew(:,fixedHead) = cblOri(:,fixedHead);
        fixedTail = idxStationTail(worm);
        cblNew(:,fixedTail) = cblOri(:,fixedTail);
        
        % ===========
        % FIT THE VERTICES, STARTING FROM THE STATIONARY POINTS: 4 PASSES
        %  1. from the first stationary point towards the head (one extremity)
        %  2. from the second stationary point towards the tail (the other extremity)
        %  3. from before the first stationary point towards the tail (most of the body)
        %  4. from after the second stationary point towards the head (most of the body)
        % In each pass, from a stationary vertex, find the best fit for the two vertices after, rotate the rest of the body according to that fit, and
        %   consider the next vertex as stationary, and loop until the extremity is reached. If no fit is valid, try increasing the range, if still not
        %   enough, keep the current location as the best.
        % ===========
        % -----------
        % indicesToFit(pp,vv): rank of vertex 'vv' for fitting at pass 'pp'
        % rank: Inf means don't take it into account
        %       1 means use it as a starting point, fit 2 and 3
        %       n means use it after n fittings, fit n+1 and n+2
        % -----------
        indicesToFit = Inf(4, nbOfIndices);
        range = fixedHead:-1:1;
        indicesToFit(1,range) = 1:length(range);
        range = fixedTail:nbOfIndices;
        indicesToFit(2,range) = 1:length(range);
        range = (fixedHead-1):nbOfIndices;
        indicesToFit(3,range) = 1:length(range);
        range = (fixedTail+1):-1:1;
        indicesToFit(4,range) = 1:length(range);
        
        % -----------
        % Sort the passes so that: the passes with no risky vertex are first, then the passes whose first risky vertex is the furthest; in case of
        % equality, the shortest pass is first (due to the order in which they are defined in the first place)
        % -----------
        valuesRisky = zeros(1,size(indicesToFit,1));
        for pass = 1:length(valuesRisky)
            if any(riskyVertices{worm})
                valuesRisky(pass) = min(indicesToFit(pass, riskyVertices{worm}),[],2);
                indicesToFit(pass,(indicesToFit(pass,:)) >= valuesRisky(pass)) = Inf;
            end
        end
        [tmp, order] = sort(valuesRisky, 'descend');
        indicesToFit = indicesToFit(order,:);
        
        % -----------
        % Fit the vertices, one pass at a time
        % -----------
        riskyIndices = riskyVertices{worm};
        for pass = 1:size(indicesToFit,1)
            ranksIndices = indicesToFit(pass,:);
            % -----------
            % Find the non-risky index with lowest rank
            % -----------
            rankStart = min(ranksIndices(~riskyIndices));
            % -----------
            % Define the list of vertices to be rotated and fit to the image
            % -----------
            if isempty(rankStart) || isinf(rankStart)
                continue
            end
            idxStart = find(ranksIndices == rankStart);
            idxJoint = find(ranksIndices == rankStart+1);
            idxExtrem = find(ranksIndices == rankStart+2);
            idxPrev = 2*idxStart - idxJoint;
            flagUsePrev = ~isempty(idxPrev) && (idxPrev >= 1) && (idxPrev <= length(ranksIndices));
            flagContinue = (isfinite(rankStart)) && (~isempty(idxExtrem)) && (~isempty(idxStart)) && (~riskyIndices(idxStart));
            while flagContinue
                oldVal = cblNew(:, idxExtrem);
                fixedPoint = cblNew(:,idxStart);
                joint = cblNew(:,idxJoint);
                widthJoint = widthOri(idxJoint);
                extremity = cblNew(:,idxExtrem);
                widthExtremity = widthOri(idxExtrem);
                % ...........
                % Vecteurs linking the vertices, they are going to be rotated
                % ...........
                if flagUsePrev
                    priorPoint = cblNew(:, idxPrev);
                    linkPriorToFixed = fixedPoint - priorPoint;
                    linkPriorToFixed = linkPriorToFixed' / norm(linkPriorToFixed);
                end;
                linkFixedToJoint = joint - fixedPoint;
                normFixedToJoint = norm(linkFixedToJoint);
                linkJointToExtremity = extremity - joint;
                normJointToExtremity = norm(linkJointToExtremity);
                % ...........
                % Values defining the angles for the fittest rotations
                % ...........
                fitnessBest = Inf;
                jointBest = joint;
                extremityBest = extremity;
                angleExtremBest = 0;
                % ...........
                % Try all the rotations for the joint
                % ...........
                for kJoint = kJointRange
                    rotatedJoint = [ fixedPoint(1) + cos(kJoint)*linkFixedToJoint(1) + sin(kJoint)*linkFixedToJoint(2);...
                        fixedPoint(2) - sin(kJoint)*linkFixedToJoint(1) + cos(kJoint)*linkFixedToJoint(2)];
                    if (~flagUsePrev) || (linkPriorToFixed*(rotatedJoint-fixedPoint) >= cosMin * normFixedToJoint)
                        pointsAroundJoint = round(rotatedJoint(1,:) + widthJoint*cosCircle -1)*imHeight + round(rotatedJoint(2,:) + widthJoint*sinCircle);
                        fitnessNeck = sum(max(0, localThr - currentImage(pointsAroundJoint)));
                        % ...........
                        % Try all the rotations for the extremity
                        % ...........
                        for kExtrem = kJoint + kExtremRange
                            rotatedExtremity = [ rotatedJoint(1) + cos(kExtrem)*linkJointToExtremity(1) + sin(kExtrem)*linkJointToExtremity(2);...
                                rotatedJoint(2) - sin(kExtrem)*linkJointToExtremity(1) + cos(kExtrem)*linkJointToExtremity(2)];
                            if (~flagUsePrev) || (linkPriorToFixed*(rotatedExtremity-rotatedJoint) >= cosMin * normJointToExtremity)
                                pointsAroundExtremity = round(rotatedExtremity(1) + widthExtremity * cosCircle -1)*imHeight + round(rotatedExtremity(2) + widthExtremity * sinCircle);
                                fitnessHead = fitnessNeck + sum(max(0, localThr - currentImage(pointsAroundExtremity)));
                                % ...........
                                % Store the best values
                                % ...........
                                if fitnessHead < fitnessBest
                                    fitnessBest = fitnessHead;
                                    jointBest = rotatedJoint;
                                    extremityBest = rotatedExtremity;
                                    angleExtremBest = (kExtrem-kJoint);
                                end
                            end
                        end
                    end
                end
                cblNew(:, idxExtrem) = extremityBest;
                cblNew(:, idxJoint) = jointBest;
                % -----------
                % Rotate the rest of the vertices
                % -----------
                newVal = cblNew(:, idxExtrem);
                startingRot = rankStart+3;
                rangeToRotate = find(isfinite(ranksIndices) & ranksIndices >= startingRot);
                if ~isempty(rangeToRotate)
                    onesTmp = ones(size(rangeToRotate));
                    cblNew(:,rangeToRotate) = newVal*onesTmp...
                        + [cos(angleExtremBest), sin(angleExtremBest) ; -sin(angleExtremBest), cos(angleExtremBest)] * (cblNew(:,rangeToRotate) - oldVal*onesTmp);
                end
                rankStart = rankStart+1;
                idxStart = find(ranksIndices == rankStart);
                idxJoint = find(ranksIndices == rankStart+1);
                idxExtrem = find(ranksIndices == rankStart+2);
                idxPrev = find(ranksIndices == rankStart-1);
                flagUsePrev = (~isempty(idxPrev));
                flagContinue = (~isempty(idxExtrem)) && (~riskyIndices(idxStart));
            end
        end
        
        
        % ===========
        % ADJUST THE RISKY VERTICES BY INTERPOLATION FIRST, TO HAVE A FIRST GUESS WHERE THEY MIGHT BE
        % ===========
        listOfIndicesLeftOut = isinf(min(indicesToFit));
        % -----------
        % Treat the head if need be
        % -----------
        idxHeadLeftOut = 0;
        while (idxHeadLeftOut + 2 <= length(listOfIndicesLeftOut)) && (listOfIndicesLeftOut(1+idxHeadLeftOut))
            idxHeadLeftOut = idxHeadLeftOut + 1;
        end
        rangeToRotate = 1:idxHeadLeftOut;
        listOfIndicesLeftOut(rangeToRotate) = false;
        if (idxHeadLeftOut + 2 <= length(listOfIndicesLeftOut)) && ~isempty(rangeToRotate)
            % ...........
            % Find the angle by which the head was rotated
            % ...........
            oldSegment = cblOri(:, idxHeadLeftOut + 1) - cblOri(:, idxHeadLeftOut + 2);
            newSegment = cblNew(:, idxHeadLeftOut + 1) - cblNew(:, idxHeadLeftOut + 2);
            cosRot = oldSegment' * newSegment / (max(0.1,norm(oldSegment)) * max(0.1,norm(newSegment)));
            sinRot = det([newSegment, oldSegment]) / (max(0.1,norm(oldSegment)) * max(0.1,norm(newSegment)));
            % ...........
            % Rotate the extremity
            % ...........
            oldVal = cblOri(:, idxHeadLeftOut + 1);
            newVal = cblNew(:, idxHeadLeftOut + 1);
            onesTmp = ones(size(rangeToRotate));
            cblNew(:,rangeToRotate) = newVal*onesTmp + [cosRot sinRot ; -sinRot cosRot] * (cblOri(:,rangeToRotate) - oldVal*onesTmp);
        end
        % -----------
        % Treat the tail if need be
        % -----------
        idxTailLeftOut = length(listOfIndicesLeftOut);
        while (idxTailLeftOut >= 3) && (listOfIndicesLeftOut(idxTailLeftOut-1))
            idxTailLeftOut = idxTailLeftOut - 1;
        end
        rangeToRotate = idxTailLeftOut:length(listOfIndicesLeftOut);
        listOfIndicesLeftOut(rangeToRotate) = false;
        if (idxTailLeftOut >= 3) && ~isempty(rangeToRotate)
            % -----------
            % Find the angle by which the tail was rotated
            % -----------
            oldSegment = cblOri(:, idxTailLeftOut - 1) - cblOri(:, idxTailLeftOut - 2);
            newSegment = cblNew(:, idxTailLeftOut - 1) - cblNew(:, idxTailLeftOut - 2);
            cosRot = oldSegment' * newSegment / (max(0.1,norm(oldSegment)) * max(0.1,norm(newSegment)));
            sinRot = det([newSegment, oldSegment]) / (max(0.1,norm(oldSegment)) * max(0.1,norm(newSegment)));
            % ...........
            % Rotate the extremity
            % ...........
            oldVal = cblOri(:, idxTailLeftOut - 1);
            newVal = cblNew(:, idxTailLeftOut - 1);
            onesTmp = ones(size(rangeToRotate));
            cblNew(:,rangeToRotate) = newVal*onesTmp + [cosRot sinRot ; -sinRot cosRot] * (cblOri(:,rangeToRotate) - oldVal*onesTmp);
        end
        % -----------
        % Treat the middle if need be
        % -----------
        idxMidStart = idxHeadLeftOut + 1 ;
        % ...........
        % There might be multiple risky segments
        % ...........
        while (idxMidStart < idxTailLeftOut)
            while (idxMidStart < idxTailLeftOut) && (~listOfIndicesLeftOut(idxMidStart+1))
                idxMidStart = idxMidStart + 1;
            end
            % ...........
            % listOfIndicesLeftOut(idxMidStart+1) is the lowest location true, listOfIndicesLeftOut(idxMidStart) is false
            % ...........
            idxMidEnd = idxMidStart + 1 ;
            while (idxMidEnd < idxTailLeftOut) && (listOfIndicesLeftOut(idxMidEnd))
                idxMidEnd = idxMidEnd + 1;
            end
            % ...........
            % listOfIndicesLeftOut(idxMidEnd) is the next highest location false
            % ...........
            rangeToFix = (idxMidStart+1):(idxMidEnd-1);
            listOfIndicesLeftOut(rangeToFix) = false;
            if ~isempty(rangeToFix)
                % ...........
                % Linearly interpolate the vertices
                % ...........
                longs = hypot(cblNew(1,(idxMidStart+1):(idxMidEnd+1))-cblNew(1,(idxMidStart):(idxMidEnd)),...
                    cblNew(2,(idxMidStart+1):(idxMidEnd+1))-cblNew(2,(idxMidStart):(idxMidEnd)));
                cumlen = cumsum(longs);
                % compute the directions
                midStartUnit = cblNew(:,idxMidStart) - cblNew(:,idxMidStart-1);
                midStartUnit = midStartUnit / max(0.1, norm(midStartUnit));
                midEndUnit = cblNew(:,idxMidEnd+1) - cblNew(:,idxMidEnd);
                midEndUnit = midEndUnit / max(0.1, norm(midEndUnit));
                interpDir = zeros(2,length(cumlen)-1);
                interpDir(1,:) = interp1([0 cumlen(end)], [midStartUnit(1), midEndUnit(1)], cumlen(1:end-1)) .* longs(1:end-1);
                interpDir(2,:) = interp1([0 cumlen(end)], [midStartUnit(2), midEndUnit(2)], cumlen(1:end-1)) .* longs(1:end-1);
                newValues1 = cumsum([cblNew(:,idxMidStart), interpDir],2);
                newValues2 = cumsum([cblNew(:,idxMidEnd), -fliplr(interpDir)],2);
                newValues = (newValues1 .* (cumlen(end)-[cumlen;cumlen]) + newValues2(:,end:-1:1) .* [cumlen;cumlen]) / cumlen(end);
                cblNew(:,rangeToFix) = newValues(:,2:end-1);
            end
            idxMidStart = idxMidEnd;
        end
        
        if plotAllOn
            listOfIndices = 1:length(cblNew);
            tmp = zeros(2, length(listOfIndices)*length(cosDraw));
            for vv = 1:length(listOfIndices)
                tmp(:,(vv-1)*length(cosDraw)+(1:length(cosDraw))) =  [cblNew(1,listOfIndices(vv))+widthOri(listOfIndices(vv))*cosDraw ; ...
                    cblNew(2,listOfIndices(vv))+widthOri(listOfIndices(vv))*sinDraw];
            end
            plot(tmp(1,:), tmp(2,:), '-y', 'parent', axesImage)
            plot(cblNew(1,riskyIndices), cblNew(2,riskyIndices), '*b', 'parent', axesImage,'markersize',10)
        end
        
        
        listOfWorms.skel{worm}{currentFrame} = cblNew;
        listOfWorms.width{worm}{currentFrame} = widthOri;
        
    catch em
        if flagRobustness
            fprintf(fileToLog, ['***   There was an error tracking worm: ',num2str(worm),' , skipping this worm. ***','\n']);
            fprintf(fileToLog, [getReport(em, 'basic'),'\n']);
            listOfWorms.skel{worm}{currentFrame} = listOfWorms.skel{worm}{currentFrame-1};
            listOfWorms.width{worm}{currentFrame} = listOfWorms.width{worm}{currentFrame-1};
            listOfWorms.missed(worm, currentFrame) = true;
        else
            rethrow(em)
        end
    end
end

        if timingOn; timings(13) = timings(13) + toc ; timingsTime(13) = timingsTime(13) + 1 ; tic; end

% ===========
% RE-ASSESS THE RISK OF THE RISKY VERTICES
% ===========
% -----------
% riskyVertices{worm}: contains a boolean array, one value per vertex.
% -----------
riskyVerticesUpdated = cell(1,nbOfWorms);
for worm = 1:nbOfWorms
    if listOfWorms.lost(worm, currentFrame-1); continue; end
    riskyVerticesUpdated{worm} = false(size(listOfWorms.width{worm}{currentFrame-1}));
    for prevWorm = 1:(worm-1)
        if listOfWorms.lost(prevWorm, currentFrame-1); continue; end
        if riskOfOverlap(worm, prevWorm)
            for idx = find(riskyVertices{worm})
                longueursOri = hypot(listOfWorms.skel{prevWorm}{currentFrame}(1,:) - listOfWorms.skel{worm}{currentFrame}(1,idx),...
                    listOfWorms.skel{prevWorm}{currentFrame}(2,:) - listOfWorms.skel{worm}{currentFrame}(2,idx));
                % ...........
                % Take width into account
                % ...........
                longueursOri = longueursOri - listOfWorms.width{prevWorm}{currentFrame-1};
                longueursOri = longueursOri - listOfWorms.width{worm}{currentFrame-1}(idx);
                % ...........
                % Detect potential vertex overlap
                % ...........
                if any(longueursOri <= 0)
                    riskyVerticesUpdated{prevWorm} = riskyVerticesUpdated{prevWorm} | (longueursOri <= 0);
                    riskyVerticesUpdated{worm}(idx) = any(longueursOri <= 0);
                end
            end
        end
    end
end
% ...........
% Plot the risky vertices if need be
% ...........
if plotAllOn
    for worm = 1:nbOfWorms
        listRisk = riskyVerticesUpdated{worm};
        if ~isempty(listRisk) && any(listRisk)
            plot(listOfWorms.skel{worm}{currentFrame}(1,listRisk), listOfWorms.skel{worm}{currentFrame}(2,listRisk),'*k','markersize',20)
        end
    end
end


        if timingOn; timings(12) = timings(12) + toc ; timingsTime(12) = timingsTime(12) + 1 ; tic; end

% ===========
% ADJUST THE NOW-SAFE VERTICES
% ===========
for worm = 1:nbOfWorms
    if listOfWorms.lost(worm, currentFrame-1); continue; end
    try
        localThr = listOfWorms.localthreshold{worm};
        cblNew = listOfWorms.skel{worm}{currentFrame};
        widthOri = listOfWorms.width{worm}{currentFrame};
        
        indicesNowSafe = ~riskyVerticesUpdated{worm} & riskyVertices{worm};
        if plotAllOn; plot(listOfWorms.skel{worm}{currentFrame}(1,indicesNowSafe), listOfWorms.skel{worm}{currentFrame}(2,indicesNowSafe),'x-r','markersize',15); end
        [lblNowSafe, numRegions] = bwlabel(indicesNowSafe);
        if numRegions <= 0
            continue
        end
        % -----------
        % Treat the head if need be
        % -----------
        if (lblNowSafe(1) > 0)
            listOfIndicesToFit = find(lblNowSafe(1:end-2) == lblNowSafe(1));
            idxStart = 1 + max(listOfIndicesToFit);
            idxJoint = max(listOfIndicesToFit);
            idxExtrem = max(listOfIndicesToFit) - 1;
            useExtrem = (idxExtrem >= 1);
            idxPrev = 2*idxStart - idxJoint;
            flagContinue = true;
            while flagContinue
                if useExtrem; oldVal = cblNew(:, idxExtrem); end
                fixedPoint = cblNew(:,idxStart);
                joint = cblNew(:,idxJoint);
                widthJoint = widthOri(idxJoint);
                if useExtrem; extremity = cblNew(:,idxExtrem); end
                if useExtrem; widthExtremity = widthOri(idxExtrem); end
                % ...........
                % Vecteurs linking the vertices, they are going to be rotated
                % ...........
                priorPoint = cblNew(:, idxPrev);
                linkPriorToFixed = fixedPoint - priorPoint;
                linkPriorToFixed = linkPriorToFixed' / norm(linkPriorToFixed);
                linkFixedToJoint = joint - fixedPoint;
                normFixedToJoint = norm(linkFixedToJoint);
                if useExtrem; linkJointToExtremity = extremity - joint; end
                if useExtrem; normJointToExtremity = norm(linkJointToExtremity); end
                % ...........
                % Values defining the angles for the fittest rotations
                % ...........
                fitnessBest = Inf;
                jointBest = joint;
                if useExtrem; extremityBest = extremity; end
                if useExtrem; angleExtremBest = 0; end
                % ...........
                % Try all the rotations for the joint
                % ...........
                for kJoint = kJointRange
                    rotatedJoint = [ fixedPoint(1) + cos(kJoint)*linkFixedToJoint(1) + sin(kJoint)*linkFixedToJoint(2);...
                        fixedPoint(2) - sin(kJoint)*linkFixedToJoint(1) + cos(kJoint)*linkFixedToJoint(2)];
                    if (linkPriorToFixed*(rotatedJoint-fixedPoint) >= cosMin * normFixedToJoint)
                        pointsAroundJoint = round(rotatedJoint(1,:) + widthJoint*cosCircle -1)*imHeight + round(rotatedJoint(2,:) + widthJoint*sinCircle);
                        fitnessNeck = sum(max(0, localThr - currentImage(pointsAroundJoint)));
                        % ...........
                        % Try all the rotations for the extremity
                        % ...........
                        if useExtrem
                            for kExtrem = kJoint + kExtremRange
                                rotatedExtremity = [ rotatedJoint(1) + cos(kExtrem)*linkJointToExtremity(1) + sin(kExtrem)*linkJointToExtremity(2);...
                                    rotatedJoint(2) - sin(kExtrem)*linkJointToExtremity(1) + cos(kExtrem)*linkJointToExtremity(2)];
                                if (~flagUsePrev) || (linkPriorToFixed*(rotatedExtremity-rotatedJoint) >= cosMin * normJointToExtremity)
                                    pointsAroundExtremity = round(rotatedExtremity(1) + widthExtremity * cosCircle -1)*imHeight + round(rotatedExtremity(2) + widthExtremity * sinCircle);
                                    fitnessHead = fitnessNeck + sum(max(0, localThr - currentImage(pointsAroundExtremity)));
                                    % ...........
                                    % Store the best values
                                    % ...........
                                    if fitnessHead < fitnessBest
                                        fitnessBest = fitnessHead;
                                        jointBest = rotatedJoint;
                                        extremityBest = rotatedExtremity;
                                        angleExtremBest = (kExtrem-kJoint);
                                    end
                                end
                            end
                        else
                            if fitnessNeck < fitnessBest
                                fitnessBest = fitnessNeck;
                                jointBest = rotatedJoint;
                            end
                        end
                    end
                end
                if useExtrem
                    cblNew(:, idxExtrem) = extremityBest;
                end
                cblNew(:, idxJoint) = jointBest;
                % -----------
                % Rotate the rest of the vertices
                % -----------
                if useExtrem
                    newVal = cblNew(:, idxExtrem);
                    rangeToRotate = 1:(idxExtrem-1);
                    if ~isempty(rangeToRotate)
                        onesTmp = ones(size(rangeToRotate));
                        cblNew(:,rangeToRotate) = newVal*onesTmp...
                            + [cos(angleExtremBest), sin(angleExtremBest) ; -sin(angleExtremBest), cos(angleExtremBest)] * (cblNew(:,rangeToRotate) - oldVal*onesTmp);
                    end
                end
                idxStart = idxStart-1;
                idxJoint = idxJoint-1;
                idxExtrem = idxExtrem-1;
                idxPrev = idxStart+1;
                useExtrem = (idxExtrem >= 1);
                flagContinue = (idxJoint >= 1);
            end
        end
        % -----------
        % Treat the tail if need be
        % -----------
        if (lblNowSafe(end) > 0)
            listOfIndicesToFit = 2+find(lblNowSafe(3:end) == lblNowSafe(end));
            idxStart = min(listOfIndicesToFit)-1;
            idxJoint = min(listOfIndicesToFit);
            idxExtrem = min(listOfIndicesToFit) + 1;
            useExtrem = (idxExtrem <= length(lblNowSafe));
            idxPrev = 2*idxStart - idxJoint;
            flagContinue = true;
            while flagContinue
                if useExtrem; oldVal = cblNew(:, idxExtrem); end
                fixedPoint = cblNew(:,idxStart);
                joint = cblNew(:,idxJoint);
                widthJoint = widthOri(idxJoint);
                if useExtrem; extremity = cblNew(:,idxExtrem); end
                if useExtrem; widthExtremity = widthOri(idxExtrem); end
                % ...........
                % Vecteurs linking the vertices, they are going to be rotated
                % ...........
                priorPoint = cblNew(:, idxPrev);
                linkPriorToFixed = fixedPoint - priorPoint;
                linkPriorToFixed = linkPriorToFixed' / norm(linkPriorToFixed);
                linkFixedToJoint = joint - fixedPoint;
                normFixedToJoint = norm(linkFixedToJoint);
                if useExtrem; linkJointToExtremity = extremity - joint; end
                if useExtrem; normJointToExtremity = norm(linkJointToExtremity); end
                % ...........
                % Values defining the angles for the fittest rotations
                % ...........
                fitnessBest = Inf;
                jointBest = joint;
                if useExtrem; extremityBest = extremity; end
                if useExtrem; angleExtremBest = 0; end
                % ...........
                % Try all the rotations for the joint
                % ...........
                for kJoint = kJointRange
                    rotatedJoint = [ fixedPoint(1) + cos(kJoint)*linkFixedToJoint(1) + sin(kJoint)*linkFixedToJoint(2);...
                        fixedPoint(2) - sin(kJoint)*linkFixedToJoint(1) + cos(kJoint)*linkFixedToJoint(2)];
                    if (linkPriorToFixed*(rotatedJoint-fixedPoint) >= cosMin * normFixedToJoint)
                        pointsAroundJoint = round(rotatedJoint(1,:) + widthJoint*cosCircle -1)*imHeight + round(rotatedJoint(2,:) + widthJoint*sinCircle);
                        fitnessNeck = sum(max(0, localThr - currentImage(pointsAroundJoint)));
                        % ...........
                        % Try all the rotations for the extremity
                        % ...........
                        if useExtrem
                            for kExtrem = kJoint + kExtremRange
                                rotatedExtremity = [ rotatedJoint(1) + cos(kExtrem)*linkJointToExtremity(1) + sin(kExtrem)*linkJointToExtremity(2);...
                                    rotatedJoint(2) - sin(kExtrem)*linkJointToExtremity(1) + cos(kExtrem)*linkJointToExtremity(2)];
                                if (~flagUsePrev) || (linkPriorToFixed*(rotatedExtremity-rotatedJoint) >= cosMin * normJointToExtremity)
                                    pointsAroundExtremity = round(rotatedExtremity(1) + widthExtremity * cosCircle -1)*imHeight + round(rotatedExtremity(2) + widthExtremity * sinCircle);
                                    fitnessHead = fitnessNeck + sum(max(0, localThr - currentImage(pointsAroundExtremity)));
                                    % ...........
                                    % Store the best values
                                    % ...........
                                    if fitnessHead < fitnessBest
                                        fitnessBest = fitnessHead;
                                        jointBest = rotatedJoint;
                                        extremityBest = rotatedExtremity;
                                        angleExtremBest = (kExtrem-kJoint);
                                    end
                                end
                            end
                        else
                            if fitnessNeck < fitnessBest
                                fitnessBest = fitnessNeck;
                                jointBest = rotatedJoint;
                            end
                        end
                    end
                end
                if useExtrem
                    cblNew(:, idxExtrem) = extremityBest;
                end
                cblNew(:, idxJoint) = jointBest;
                % -----------
                % Rotate the rest of the vertices
                % -----------
                if useExtrem
                    newVal = cblNew(:, idxExtrem);
                    rangeToRotate = (idxExtrem+1):length(lblNowSafe);
                    if ~isempty(rangeToRotate)
                        onesTmp = ones(size(rangeToRotate));
                        cblNew(:,rangeToRotate) = newVal*onesTmp...
                            + [cos(angleExtremBest), sin(angleExtremBest) ; -sin(angleExtremBest), cos(angleExtremBest)] * (cblNew(:,rangeToRotate) - oldVal*onesTmp);
                    end
                end
                idxStart = idxStart+1;
                idxJoint = idxJoint+1;
                idxExtrem = idxExtrem+1;
                idxPrev = idxStart-1;
                useExtrem = (idxExtrem <= length(lblNowSafe));
                flagContinue = (idxJoint <= length(lblNowSafe));
            end
        end
        if plotAllOn; plot(cblNew(1,:), cblNew(2,:), ':r', 'parent', axesImage,'linewidth',2); end
        listOfWorms.skel{worm}{currentFrame} = cblNew;
        listOfWorms.width{worm}{currentFrame} = widthOri;
    catch em
        if flagRobustness
            fprintf(fileToLog, ['***   There was an error tracking worm: ',num2str(worm),' , skipping this worm. ***','\n']);
            fprintf(fileToLog, [getReport(em, 'basic'),'\n']);
            listOfWorms.skel{worm}{currentFrame} = listOfWorms.skel{worm}{currentFrame-1};
            listOfWorms.width{worm}{currentFrame} = listOfWorms.width{worm}{currentFrame-1};
            listOfWorms.missed(worm, currentFrame) = true;
        else
            rethrow(em)
        end
    end
end

        if timingOn; timings(13) = timings(13) + toc ; timingsTime(13) = timingsTime(13) + 1 ; tic; end

% ===========
% ADJUST WORMS ONE BY ONE: ADJUST THE EXTREMITIES TO KEEP THE LENGTH, AND ADJUST THE WIDTH
% ===========
for worm = 1:nbOfWorms
    if listOfWorms.lost(worm, currentFrame-1); continue; end
    try
        localThr = listOfWorms.localthreshold{worm};
        cblOri = listOfWorms.skel{worm}{currentFrame};
        widthOri = listOfWorms.width{worm}{currentFrame};
        cblNew = cblOri;
        % ===========
        % REMOVE VERTICES AT THE EXTREMITIES THAT ARE BELOW THE LOCAL THRESHOLD
        % ===========
        riskyIndices = riskyVerticesUpdated{worm};
        % ------------
        % Look for vertices below the threshold
        % ------------
        pointsTested = round(cblNew(1,:)-1)*imHeight + round(cblNew(2,:));
        removeVertex = (currentImage(pointsTested) < localThr);
        % ------------
        % Remove only at the two extremities (it may happen that another vertex is below threshold, but removing it would unlink the chain of widths)
        % ------------
        if riskyIndices(1)
            % The head is overlapping another worm, check if the rest of the body is disconnected, by having a vertex below threshold
            idxEndOfOverlap = 1;
            while idxEndOfOverlap <= length(riskyIndices)-3 && riskyIndices(idxEndOfOverlap)
                idxEndOfOverlap = idxEndOfOverlap + 1;
            end
            if any(removeVertex(1:idxEndOfOverlap))
                [valTmp, idxRemove] = max(removeVertex(1:idxEndOfOverlap));
                if plotAllOn; plot(cblNew(1,1:idxRemove), cblNew(2,1:idxRemove), '-y*', 'markersize', 15); end
                cblNew = cblNew(:,idxRemove+1:end);
                widthOri = widthOri(idxRemove+1:end);
                riskyIndices = riskyIndices(idxRemove+1:end);
                removeVertex = removeVertex(idxRemove+1:end);
            end
        else
            idxRemove = 1;
            totalLength = length(removeVertex);
            while (idxRemove <= totalLength-2) && removeVertex(idxRemove)
                idxRemove = idxRemove + 1;
                cblNew = cblNew(:,2:end);
                widthOri = widthOri(2:end);
                riskyIndices = riskyIndices(2:end);
                removeVertex = removeVertex(2:end);
            end
        end
        if riskyIndices(end)
            % The tail is overlapping another worm, check if the rest of the body is disconnected, by having a vertex below threshold
            idxEndOfOverlap = length(riskyIndices);
            while idxEndOfOverlap >= 4 && riskyIndices(idxEndOfOverlap)
                idxEndOfOverlap = idxEndOfOverlap - 1;
            end
            if any(removeVertex(idxEndOfOverlap:end))
                [valTmp, idxRemove] = max( (idxEndOfOverlap:length(removeVertex)) .* removeVertex(idxEndOfOverlap:end) );
                idxRemove = idxRemove + idxEndOfOverlap - 1;
                if plotAllOn; plot(cblNew(1,idxRemove), cblNew(2,idxRemove), 'b*', 'markersize', 15); end
                if plotAllOn; plot(cblNew(1,idxRemove:end), cblNew(2,idxRemove:end), '-b', 'markersize', 15); end
                cblNew = cblNew(:,1:idxRemove-1);
                widthOri = widthOri(1:idxRemove-1);
                riskyIndices = riskyIndices(1:idxRemove-1);
                removeVertex = removeVertex(1:idxRemove-1); %#ok<NASGU>
            end
        else
            idxRemove = length(removeVertex);
            while (idxRemove >= 3) && removeVertex(idxRemove)
                idxRemove = idxRemove - 1;
                cblNew = cblNew(:,1:end-1);
                widthOri = widthOri(1:end-1);
                riskyIndices = riskyIndices(1:end-1);
            end
        end
        % ===========
        % ADD VERTICES AT THE EXTREMITIES IF NEED BE
        % ===========
        lengthBefore = listOfWorms.lengthWorms(worm, currentFrame-1);
        lengthAfter  = sum(hypot(cblNew(1,2:end)-cblNew(1,1:end-1), cblNew(2,2:end)-cblNew(2,1:end-1)));
        for direction = [-1,1]
            lengthLost = lengthBefore - lengthAfter;
            while lengthLost > 1
                if direction < 0 ; extremIdx = length(widthOri); else extremIdx = 1; end
                newLength = min(max(2,widthOri(extremIdx)), lengthLost);
                lengthLost = lengthLost - newLength;
                lastSegment = cblNew(:,extremIdx) - cblNew(:, extremIdx+direction);
                lastSegment = newLength * lastSegment / max(1,norm(lastSegment));
                lastPoint = cblNew(:,extremIdx);
                widthBest = newLength;
                widthRange = max(1,newLength+(2:-0.5:0));
                fitnessBest = Inf;
                for kJoint = kJointRangeAddVertex
                    newPointCandidates = [lastPoint(1)+cos(kJoint)*lastSegment(1)+sin(kJoint)*lastSegment(2);lastPoint(2)-sin(kJoint)*lastSegment(1)+cos(kJoint)*lastSegment(2)];
                    newPointCandidates(1) = min(imWidth, max(1, newPointCandidates(1)));
                    newPointCandidates(2) = min(imHeight, max(1, newPointCandidates(2)));
                    for newWidth = widthRange
                        pointsAroundJoint = round(newPointCandidates(1,:) + newWidth*cosCircle -1)*imHeight + round(newPointCandidates(2,:) + newWidth*sinCircle);
                        fitnessNeck = sum(max(0, localThr - currentImage(pointsAroundJoint)));
                        if fitnessNeck < fitnessBest
                            fitnessBest = fitnessNeck;
                            bestPoint = newPointCandidates;
                            widthBest = newWidth;
                        end
                    end
                end
                if isfinite(fitnessBest) && currentImage(round(bestPoint(2)), round(bestPoint(1))) >= localThr
                    if direction < 0
                        cblNew = [cblNew, bestPoint]; %#ok<*AGROW>
                        widthOri = [widthOri, widthBest];
                        riskyIndices = [riskyIndices, false];
                    else
                        cblNew = [bestPoint, cblNew];
                        widthOri = [widthBest, widthOri];
                        riskyIndices = [false, riskyIndices];
                    end
                else
                    break;
                end
            end
            lengthAfter = sum(hypot(cblNew(1,2:end)-cblNew(1,1:end-1), cblNew(2,2:end)-cblNew(2,1:end-1)));
        end
        
        if plotAllOn
            listOfIndices = 1:length(cblNew);
            tmp = zeros(2, length(listOfIndices)*length(cosDraw));
            for vv = 1:length(listOfIndices)
                tmp(:,(vv-1)*length(cosDraw)+(1:length(cosDraw))) =  [cblNew(1,listOfIndices(vv))+widthOri(listOfIndices(vv))*cosDraw ; ...
                    cblNew(2,listOfIndices(vv))+widthOri(listOfIndices(vv))*sinDraw];
            end
            plot(tmp(1,:), tmp(2,:), '-c', 'parent', axesImage)
        end
        
        
        
        % ===========
        % ADJUST THE WIDTH OF CIRCLES
        % ===========
        for idxVertex = 1:length(widthOri)
            % -----------
            % Don't adjust the width of risky vertices, they may lie on an edge because they haven't been fitted properly, and thus their width might get
            % suddenly too small
            % -----------
            if ~riskyIndices(idxVertex)
                widthMax = 1+widthOri(idxVertex);
                rangeW = -widthMax:widthMax;
                rangeX = round(cblNew(1,idxVertex)+rangeW);
                rangeY = round(cblNew(2,idxVertex)+rangeW);
                % -----------
                % Keep these values within the image range
                % -----------
                rangeX = rangeX( (rangeX >= 1) & (rangeX <= imWidth));
                rangeY = rangeY( (rangeY >= 1) & (rangeY <= imHeight));
                subregion = (currentImage(rangeY,rangeX) > localThr);
                xc = cblNew(1,idxVertex) -( rangeX(1)-1);
                yc = cblNew(2,idxVertex) -( rangeY(1)-1);
                % -----------
                % Compute the distance to the nearest pixel below the threshold
                % -----------
                tmp = [];
                for ii=1:size(subregion,2)
                    for jj=1:size(subregion,1)
                        if ~subregion(jj,ii)
                            tmp(end+1)=hypot(xc-ii,yc-jj);
                        end
                    end
                end
                if ~isempty(tmp)
                    widthOri(idxVertex) = max(2,min(tmp));
                end
            end
        end
        
        
        % ===========
        % ADJUST THE SAMPLING OF THE MODEL
        % ===========
        % -----------
        % Compare a vertex with its successor in the CBL: if their distance is less than half of either their widths, the sucessor is marked as
        % redundant, and will be removed.
        % -----------
        flagKeepVertex = true(size(widthOri));
        for idxVertex = 1:length(widthOri)-1
            if flagKeepVertex(idxVertex)
                % ...........
                % Compare vertices idxVertex and idxVertex+1, to decide on the fate of idxVertex+1
                % ...........
                lengthToCompare = hypot(cblNew(1,idxVertex+1)-cblNew(1,idxVertex), cblNew(2,idxVertex+1)-cblNew(2,idxVertex));
                if (lengthToCompare <= widthOri(idxVertex)/2) || (lengthToCompare <= widthOri(idxVertex+1)/2)
                    flagKeepVertex(idxVertex+1) = false;
                end
            end
        end
        % ...........
        % Remove the redundant vertices
        % ...........
        cblNew = cblNew(:, flagKeepVertex);
        widthOri = widthOri(flagKeepVertex);
        
        % -----------
        % Compare a vertex with its 2nd-successor in the CBL: if their distance is less than a function of the CBL length, the vertex in-between is
        % marked as redundant, and will be removed.
        % -----------
        for iteration = 1:2
            flagKeepVertex = true(size(widthOri));
            idxVertex = 1;
            nextVertex = 2;
            while nextVertex <= length(widthOri)-1
                % ...........
                % Compare vertices idxVertex and idxVertex+2, to decide on the fate of idxVertex+1
                % ...........
                length0to1 = hypot(cblNew(1,nextVertex)-cblNew(1,idxVertex), cblNew(2,nextVertex)-cblNew(2,idxVertex));
                length0to2 = hypot(cblNew(1,nextVertex+1)-cblNew(1,idxVertex), cblNew(2,nextVertex+1)-cblNew(2,idxVertex));
                length1to2 = hypot(cblNew(1,nextVertex+1)-cblNew(1,nextVertex), cblNew(2,nextVertex+1)-cblNew(2,nextVertex));
                if length0to2 <= (length0to1 + (length1to2/2))
                    % ...........
                    % Too close, remove the next vertex
                    % ...........
                    flagKeepVertex(nextVertex) = false;
                else
                    % ...........
                    % Distance ok, move on to the next vertex
                    % ...........
                    idxVertex = idxVertex+1;
                end
                nextVertex = nextVertex+1;
            end
            if plotAllOn; plot(cblNew(1,flagKeepVertex), cblNew(2,flagKeepVertex), '*-r', 'parent', axesImage); end
            if plotAllOn; plot(cblNew(1,~flagKeepVertex), cblNew(2,~flagKeepVertex), '*c', 'parent', axesImage); end
            % ...........
            % Remove the redundant vertices
            % ...........
            cblNew = cblNew(:, flagKeepVertex);
            widthOri = widthOri(flagKeepVertex);
            cblNew = cblNew(:,end:-1:1);
        end
        
        % -----------
        % Check for gaps in the model, and add vertices where needed
        % -----------
        cblAdding = [];
        widthAdding = [];
        for idxVertex = 1:length(widthOri)-1
            longueur = hypot(cblNew(1,idxVertex+1)-cblNew(1,idxVertex) , cblNew(2,idxVertex+1)-cblNew(2,idxVertex));
            cblAdding(:,end+1) = cblNew(:,idxVertex);
            widthAdding(:,end+1) = widthOri(idxVertex);
            if longueur >= widthOri(idxVertex+1) + widthOri(idxVertex)
                cblAdding(:,end+1) = ( cblNew(:,idxVertex) + cblNew(:,idxVertex+1)) / 2;
                widthAdding(:,end+1) = ( widthOri(:,idxVertex) + widthOri(:,idxVertex+1)) / 2;
                if plotAllOn; plot(cblAdding(1,end), cblAdding(2,end), '*g', 'markersize', 20); end
            end
        end
        cblNew = cblAdding;
        widthOri = widthAdding;
        % -----------
        % Check for bad angles
        % -----------
        midPoint = floor(size(cblNew,2)/2);
        keep = true(1,size(cblNew,2));
        edges = cblNew(:,2:end) - cblNew(:,1:end-1);
        cosines = dot(edges(:,1:end-1), edges(:,2:end));
        badAngles = (cosines <= 0);
        [valTmp, idxFirst] = max(badAngles(1:midPoint));
        if valTmp >= 1
            keep(1:idxFirst) = false;
        end
        [valTmp, idxLast] = max((midPoint+1:length(badAngles)) .* badAngles(midPoint+1:end));
        if valTmp >= 1
            keep(idxLast:end) = false;
        end
        if any(~keep)
            cblNew = cblNew(:, keep);
            widthOri = widthOri(keep);
        end
        nbOfVertices = size(cblNew,2);
        valuesCBL = sum(currentImage(round(cblNew(1,:)-1)*imHeight + round(cblNew(2,:))) >= localThr);
        % ===========
        % STORE THE NEW WORM
        % ===========
        if (nbOfVertices <= 4) || (valuesCBL < nbOfVertices/2)
            listOfWorms.skel{worm}{currentFrame} = listOfWorms.skel{worm}{currentFrame-1};
            listOfWorms.width{worm}{currentFrame} = listOfWorms.width{worm}{currentFrame-1};
            listOfWorms.missed(worm, currentFrame) = true;
            listOfWorms.lengthWorms(worm, currentFrame) = listOfWorms.lengthWorms(worm, currentFrame-1);
            listOfWorms.lost(worm, currentFrame) = true;
        else
            listOfWorms.skel{worm}{currentFrame} = cblNew;
            listOfWorms.width{worm}{currentFrame} = widthOri;
            listOfWorms.missed(worm, currentFrame) = false;
            listOfWorms.lengthWorms(worm, currentFrame) = listOfWorms.lengthWorms(worm, currentFrame-1);
            listOfWorms.lost(worm, currentFrame) = false;
        end
        if plotAllOn
            listOfIndices = 1:length(cblNew);
            tmp = zeros(2, length(listOfIndices)*length(cosDraw));
            for vv = 1:length(listOfIndices)
                tmp(:,(vv-1)*length(cosDraw)+(1:length(cosDraw))) =...
                    [listOfWorms.skel{worm}{currentFrame}(1,listOfIndices(vv))+listOfWorms.width{worm}{currentFrame}(listOfIndices(vv))*cosDraw ; ...
                    listOfWorms.skel{worm}{currentFrame}(2,listOfIndices(vv))+listOfWorms.width{worm}{currentFrame}(listOfIndices(vv))*sinDraw];
            end
            plot(tmp(1,:), tmp(2,:), ':', 'parent', axesImage,'linewidth',1, 'color', rand(1,3));
        end
        
    catch em
        if flagRobustness
            fprintf(fileToLog, ['***   There was an error tracking worm: ',num2str(worm),' , skipping this worm. ***','\n']);
            fprintf(fileToLog, [getReport(em, 'basic'),'\n']);
            listOfWorms.skel{worm}{currentFrame} = listOfWorms.skel{worm}{currentFrame-1};
            listOfWorms.width{worm}{currentFrame} = listOfWorms.width{worm}{currentFrame-1};
            listOfWorms.missed(worm, currentFrame) = true;
        else
            rethrow(em)
        end
    end
    
end
for worm = 1:nbOfWorms
    if listOfWorms.lost(worm, currentFrame-1)
        listOfWorms.skel{worm}{currentFrame} = listOfWorms.skel{worm}{currentFrame-1};
        listOfWorms.width{worm}{currentFrame} = listOfWorms.width{worm}{currentFrame-1};
        listOfWorms.missed(worm, currentFrame) = true;
        listOfWorms.lengthWorms(worm, currentFrame) = listOfWorms.lengthWorms(worm, currentFrame-1);
        listOfWorms.lost(worm, currentFrame) = true;
    else
        nbOfVertices = size(listOfWorms.skel{worm}{currentFrame},2);
        
        valuesCBL = sum(currentImage(round(listOfWorms.skel{worm}{currentFrame}(1,:)-1)*imHeight + round(listOfWorms.skel{worm}{currentFrame}(2,:))) >= listOfWorms.localthreshold{worm});
        if (nbOfVertices <= 4) || (valuesCBL < nbOfVertices/2)
            listOfWorms.skel{worm}{currentFrame} = listOfWorms.skel{worm}{currentFrame-1};
            listOfWorms.width{worm}{currentFrame} = listOfWorms.width{worm}{currentFrame-1};
            listOfWorms.missed(worm, currentFrame) = true;
            listOfWorms.lengthWorms(worm, currentFrame) = listOfWorms.lengthWorms(worm, currentFrame-1);
            listOfWorms.lost(worm, currentFrame) = true;
        end
    end
end

if timingOn; timings(14) = timings(14) + toc ; timingsTime(14) = timingsTime(14) + 1 ; tic; end

end
