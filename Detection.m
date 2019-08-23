function [guiString, shape_color, conv_match_ctr] = Detection(conv_match_ctr, shape_color)
    % CAKE - Computer Vision (Decoration)
    global detector_updated_FINAL;
    global bdim;
    global useRobotCellCamera;
    global camParam_Conv R_Conv t_Conv;
    
    correctColor = false;
    
    %Xi,Yi,Xf,Yf,Angle_delta
    dataVector = zeros(1,5);
    
    % for each frame at a time
    while (true)

        %for conveyor camera (get one frame)
        if(useRobotCellCamera)
            cImage = MTRN4230_Image_Capture([],[]); 
        else
            cImage = imread('PnPTestC2.jpg');
        end
        cImage = imcrop(cImage,[515.0,4.50,676.00,720.00]);

        [cBboxes,~,cLabels] = detect(detector_updated_FINAL,cImage,'Threshold',0.20,...
                'NumStrongestRegions',10);

        posMatchNum = 0;
        for posMatch = 1 : size(cBboxes,1)
            matchCheck = uint8(cLabels);
            if (ismember(matchCheck(posMatch),shape_color(1,:)) ~= 0)
                posMatchNum = posMatchNum + 1;
            end
        end 
    
        % Look for a shape_color pair in current frame @ conveyor                            
        anyShape = false;
        while (anyShape == false)
            for j = 1 : size(shape_color,2)
                [check,id] = shapeCheck(uint8(cLabels),shape_color(1,j));
                if (check == true)
                    anyShape = true;
                    tempID = id;
                    tempJ = j;
                    break;
                end
            end          
            break;
        end    

         % no shape found in current frame
         % if anyShape is still false after all labels
         if (anyShape == false)
             moveConveyor(true,true);
             break; % activate conveyor to move to next set of blocks
         end 

        % Found one of the potential matching shapes
        posMatchNum = posMatchNum - 1;

        %disp('Shape Found!');                   
        % Annotate Shape detection result
        imshow(cImage);
        hold on
        rectangle('Position',[cBboxes(tempID,1),cBboxes(tempID,2),cBboxes(tempID,3),cBboxes(tempID,4)],'EdgeColor'...
            ,'g','LineWidth',2); 

        % 2. Check if the matched shape is in right color       
        % Create mask to find pixels with desired RGB ranges (binary mask) -
        % from customer image results
        csv_encoding = shape_color(2,tempJ);
        [color_rgb_hi,color_rgb_low] = RGB_IteratorC(csv_encoding);               

        mask_desiredC = (cImage(:,:,1) >= color_rgb_low(1)) & (cImage(:,:,1) <= color_rgb_hi(1)) & ...
                (cImage(:,:,2) >= color_rgb_low(2) ) & (cImage(:,:,2) <= color_rgb_hi(2)) & ...
                (cImage(:,:,3) >= color_rgb_low(3) ) & (cImage(:,:,3) <= color_rgb_hi(3));

        statsC = regionprops(mask_desiredC,'basic');
        Ccentroids = cat(1,statsC.Centroid);
        Careas = cat(1,statsC.Area); %(suitable area > 150)
        [sorted_area_C,sorted_area_rowC] = sort(Careas,'descend'); 
        checkMatch = false;
        if (size(sorted_area_rowC,1) > 0)
            for ctr = 1 : size(shape_color,2)
                checkMatch = isInROI(cBboxes(tempID,:),Ccentroids(sorted_area_rowC(ctr),1),...
                    Ccentroids(sorted_area_rowC(ctr),2));
                if (checkMatch == true && sorted_area_C(ctr) > 100)
                    %which color was in BBox of correct shape
                    tempCtr = checkMatch; 
                    tempX = Ccentroids(sorted_area_rowC(ctr),1);
                    tempY = Ccentroids(sorted_area_rowC(ctr),2);
                    correctColor = true;
                    disp('Correct Color AND Correct Shape!');
                    plot(tempX,tempY,'g*','LineWidth',2);
                    correctColor = true;
                    break;
                end
            end 
        else
            correctColor = false;
            disp('Incorrect Color BUT Correct Shape!');
        end               

        if (correctColor == true)
            colFound = false;
            tempROI_imageC = cImage;
            fprintf('%d: %s %s FOUND\n',conv_match_ctr,whatColor(shape_color(2,tempJ)),cLabels(tempID));                            

            % 3. Detected pose (match to customer's desired pose)

            %angle_roiC = [tempX-bdim/2,tempY-bdim/2,bdim,bdim];
            %aligned_blockC = imcrop(tempROI_imageC,angle_roiC); % CustomerImage remains as RGB for color detection
            block_angleC = 45.0; %checkBlockOrientation(aligned_blockC);

            % 4. Send Data to Robot Arm

            % i) PICK COORDINATES
            dataVector(1,1:2) = pointsToWorld(camParam_Conv,...
            R_Conv,t_Conv,[515.0+tempX,4.50+tempY]);                    
            % Swap X and Y (to match robot frame)
            dataVector(1,[1,2]) = dataVector(1,[2,1]); 

            % ---CHECK REACHABILITY (world coordinates)---
            robotReach = sqrt(dataVector(1,1)^2 + (dataVector(1,2)^2));
            if (robotReach > 23 && robotReach < 550)
                %  do nothing
            else
                disp('Not Reachable');
                % move conveyor back/forwards depending on number
                if (tempY < 100)
                    moveConveyor(false,true);
                else
                    moveConveyor(true,true);
                end
            end

            % ii) PLACE COORDINATES                            
            dataVector(1,3) = shape_color(3,tempJ);
            dataVector(1,4) = shape_color(4,tempJ);

            % iii) ANGLE                               
            dataVector(1,5) = block_angleC - shape_color(5,tempJ);

            guiString = sendPnP(dataVector); %array-string HERE                  
            fprintf('Sent %s to GUI!\n',guiString);

            % to scan for overall
            correctColor = false; % reset flag                        

            % If all required blocks are found
            if (conv_match_ctr == size(shape_color,2))
                fprintf('~~~ALL %d BLOCKS FOUND AND PLACED ON CAKE~~'...
                    ,conv_match_ctr);
                guiString = sendPnP([0,0,0,0,0]);             
                fprintf('Sent %s to GUI!\n',finishPnP);
                pause(2);
                break;
            end

            % If a block and color is successfully found, remove this
            % from the array so the conveyor does not look for it again
            shape_color(1,tempJ) = -1;                                
            check = false; % reset current T/F detection
            correctShape = false;
            conv_match_ctr = conv_match_ctr + 1; % increase no. successful
            % block matches
            anyShape = false;
            break;

        else
            % Correct shape but wrong color
            disp('KEEP FRAME')                    
            % if only one of a shape
            shape_color(1,tempJ) = -1;
        end

        if (posMatchNum == 0)
           disp('Requires more Blocks, Move Conveyor!');
           % Pulse conveyor along if no more potential blocks in 
           % current frame (direction,enable)
           moveConveyor(true,true);
           pause(1.0);
           break;
        end
    end        
end

%% ~~~~~~~FUNCTIONS~~~~~~
% Move Conveyor Forwards
function moveConveyor(direction,enable)
    
    global socket_1;    

    if (enable)
        if (direction) %direction = true (forward towards robot)
            %fwrite command for direction
            fwrite(socket_1,'CON');
            pause(0.75);
            fwrite(socket_1,'COF');
        else %direction = false (backward away from robot)
            %fwrite command for direction
            fwrite(socket_1,'CON');
            pause(0.75);
            fwrite(socket_1,'COF');
        end
    end
end

% Array to String for GUI
function blockInfo = sendPnP(dataV)
    %Make into string '[Xi,Yi,Xf,Yf,A]'
    %32.9119  532.4741  376.4049  141.8782   43.0000
    startBracket = '[';
    endBracket = ']';
    dataV =  fix(dataV);
    stringBlock = string(dataV);    
    blockInfo = join(stringBlock,",");
    blockInfo = strcat(startBracket,blockInfo,endBracket);
end

% Check if any label from ML detector on live frame
% matches the designated customer shape/color     
function [shapeFound,shapeID] = shapeCheck(curr_Labels,curr_Shape)
%encoded shape ~ 1-6
    
    shapeFound = false;
    shapeID = 0;
    
    %eg: args are cLabels,shape_color(1,j)
    for k = 1 : size(curr_Labels,1)
        if (curr_Labels(k) == curr_Shape)
            shapeFound = true;
            shapeID = k;
        end
    end

end

% Encoding for color and shape
function shapeName = whatShape(match_shape)

    if (match_shape == 1)
        shapeName = 'Circle';
    elseif (match_shape == 2)
        shapeName = 'Clover';
    elseif (match_shape == 3)
        shapeName = 'CrissCross';
    elseif (match_shape == 4)
        shapeName = 'Diamond';
    elseif (match_shape == 5)
        shapeName = 'Square';
    elseif (match_shape == 6)
        shapeName = 'Starburst';
    else
        shapeName = '-';
    end
    
end

function colorName = whatColor(match_col)

    if (match_col == 1)
        colorName = 'Red';
    elseif (match_col == 2)
        colorName = 'Green';
    elseif (match_col == 3)
        colorName = 'Blue';
    elseif (match_col == 4)
        colorName = 'Yellow';
    else
        colorName = '-';
    end
    
end

function checkMatch = isInROI(ROI,x,y)
    checkMatch = false;
    %ROI is (x,y,x_length,y_length)
    if ((x > ROI(1) && x < ROI(1) + ROI(3)) && (y > ROI(2) && y < ROI(2) + ROI(4)))
        checkMatch = true;
    end

end

function block_angle = checkBlockOrientation(block_image)

    % find angle - Ben's code
    %     grey = im2double(rgb2gray(block_image));
    %     th = otsu(grey);
    %     grey_th = grey >= th;
    %     assumptions for blob detection:
    %     - area is between 1000-1500 pixels
    %     - the blob is black (class 0; white is class 1)
    %     blob detection. detect single square. Refine blob detection
    %     blobs = iblobs(grey_th, 'boundary', 'area', [500, 1500], 'class', 0, 'aspect', [0.8,1]);
    %     edges = blobs(1).edge; % assuming only one blob has been detected - needs fixing by tightening the blob detection criteria so this is true
    %     [leftmost_x_val, leftmost_pt_ind] = min(edges(1,:));
    %     [highest_sq_y_val, highest_pt_ind] = min(edges(2,:));
    %     del_y = edges(2, leftmost_pt_ind) - edges(2, highest_pt_ind);
    %     del_x = edges(1, highest_pt_ind) - edges(1, leftmost_pt_ind);
    %     block_angle = atand(del_y/del_x);
    
end

% RGB at Conveyor
function [color_rgb_hi,color_rgb_low] = RGB_IteratorC(counter)
    if (counter == 1)
        % Threshold for RGB - RED
        color_rgb_low = [96,0,0];
        color_rgb_hi = [255,70,70];
    end
    if (counter == 2)
        % Threshold for RGB - GREEN
        color_rgb_low = [0,0,0];
        color_rgb_hi = [45,255,131];
    end
    if (counter == 3)
        % Threshold for RGB - BLUE
        color_rgb_low = [0,0,150];
        color_rgb_hi = [130,171,255];        
    end
    if (counter == 4)
        % Threshold for RGB - YELLOW
        color_rgb_low = [0,147,0];
        color_rgb_hi = [255,255,86];
    end
end

% HSV at Robot Cell
function [color_rgb_hi,color_rgb_low] = HSV_Iterator(counter)
    if (counter == 1)
        % Threshold for RBG - RED
        color_rgb_low = [93,0,0];
        color_rgb_hi = [155,74,100];
    end
    if (counter == 2)
        % Threshold for RBG - GREEN
        color_rgb_low = [0,83,0];
        color_rgb_hi = [100,140,115];
    end
    if (counter == 3)
        % Threshold for RBG - BLUE
        color_rgb_low = [0,40,100];
        color_rgb_hi = [90,95,255];        
    end
    if (counter == 4)
        % Threshold for RBG - YELLOW
        color_rgb_low = [105,160,12];
        color_rgb_hi = [255,255, 150];
    end
end

function robot_image = MTRN4230_Image_Capture (varargin)
%Table Camera (Robot Cell)
   if nargin == 0 || nargin == 1
        fig1 =figure(1);
        axe1 = axes ();
        axe1.Parent = fig1;
        vid1 = videoinput('winvideo', 1, 'MJPG_1600x1200');
        video_resolution1 = vid1.VideoResolution;
        nbands1 = vid1.NumberOfBands;
        %img1 = imshow(zeros([video_resolution1(2), video_resolution1(1), nbands1]), 'Parent', axe1);
        src1 = getselectedsource(vid1);
        src1.ExposureMode = 'manual';
        src1.Exposure = -4;
        src1.Contrast = 21;
        src1.Brightness = 128;
        robot_image = getsnapshot(vid1);
   end
% Conveyor Camera
    if nargin == 0 || nargin == 2
        fig2 =figure(2);
        axe2 = axes ();
        axe2.Parent = fig2;
        vid2 = videoinput('winvideo', 2, 'MJPG_1600x1200');
        video_resolution2 = vid2.VideoResolution;
        nbands2 = vid2.NumberOfBands;
        src2 = getselectedsource(vid2);
        src2.ExposureMode = 'manual';    
        src2.Exposure = -4;        
        src2.Brightness = 165;
        src2.Contrast = 32;
        robot_image = getsnapshot(vid2);
    end
end