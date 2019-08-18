% MTRN4230 Group Project

% ----------------ChangeLog---------------
% v1. 6/7/19 Initial creation with comments and brief summary. Image capture
% v2. 15/7/19 Improved image capture at robot cell
% v3. 18/7/19 Added in structure for YOLOv2 network
% v4. 21/7/19 Add in color detection code (initial)
% v5. 1/8/19 Added in camera calibration for robotcell and conveyor (TBD). 
% v6. 4/8/19 Finetuned YOLOv2 implementation
% v7. 7/8/19 Changed to Faster R-CNN. Training better + 2018b compatible
%            Added in conversion from image to world for PLACE coordinates
% v8. 9/8/19 Initial testing of fully trained ML network. Matched shape and
%            color logic.
% v9. 14/8/19 Tested getting live feed from both cameras. Finetuned ML
%             detection and conveyor processing per frame
% v10. 18/8/19 Fixed up orientation code. Conveyor code error handling
%               and detection over multiple frames
% ----------------ChangeLog---------------

% Computer Vision Engineer (Decoration)
% 1. Detect Quirkle blocks as they are supplied using the conveyor (ML)
% 2. Detect the customer's desired decorating pattern from robot cell camera (ML/CV)

% Shapes == (criss cross, clover, starburst, square, diamond, circle}
% Color == (red, blue, green, yellow)

%~~Decoration Computer Vision Pipeline~~

%% LOAD PRE_TRAINED DETECTOR

% When using pretrained FRCNN    
% Load detector into workspace (pretrained x 3)
%load('FINAL_FRCNN_V4.mat'); 
disp('ML Qwirkle Detector Loaded!');  

%% 1. Obtain Customer Image @ Robot CEll

warning('off','all');
clc;
close all

useRobotCellCamera = false;

if (~useRobotCellCamera)
    disp('---USING ROBOT CELL CAMERA---');      
    customerImage = imread('.\YOLO_TEST\Test1.jpg'); 
    figure
    imshow(customerImage);
else
    disp('---USING ROBOT CELL CAMERA---');      
    customerImage = MTRN4230_Image_Capture([]); %for robot cell
    figure
    imshow(customerImage);
end

% Intial image processing before the FRCNN Detector

%[a,b] = imcrop(customerImage);
rectROI = [506.00,240.00,578.00,582.00];

customerImage = imsharpen(customerImage,'Radius',5);
% gray_customerImage = rgb2gray(customerImage);
% se = strel('disk',5);
% gray_customerImage = imbinarize(gray_customerImage,0.6);
% dilated_g_customerImage = imdilate(gray_customerImage,se);
% highlighted_blocks = imreconstruct(imcomplement(dilated_g_customerImage),imcomplement(gray_customerImage));
% highlighted_blocks_c = imcomplement(highlighted_blocks);
highlighted_blocks_c = imcrop(customerImage,rectROI);

ROI_image = imcrop(customerImage,rectROI); % CustomerImage remains as RGB for color detection
%ROI_image = customerImage; %duplication? Though need ROI ideally to avoid unnecessary block detection
ROI_image = imsharpen(ROI_image,'Radius',2);

figure
imshow(ROI_image)
hold on

disp('[.1.] Customer Image Obtained')

%% 2. Detect Quirkle Blocks from Sample Image (Classification + Localisation)
%% ------------------------RUN ML MODEL ON CUSTOMER IMAGE--------------------

% Input image must be greater than [224 224]
% Run the Qwirkle detector on customer's image
ML_threshold = 0.35;
[bboxes,scores,labels] = detect(detector_updated_final,highlighted_blocks_c,'Threshold',ML_threshold,'NumStrongestRegions',10);
% Clean up ML results if double-detections/false positives
[sorted_m sorted_i] = sort(scores,'descend');
doubleDetect = false;
%(take higher score)

% -----------ERROR CHECKING-----------
% Checking whether bboxes are too close (double detected)

% Annotate BB detections in the image.
% Draw BB and Labels   
for j = 1 : size(bboxes,1)
    
    if (scores(j) < ML_threshold)
        continue;
    end
    
    rectangle('Position',[bboxes(j,1),bboxes(j,2),bboxes(j,3),bboxes(j,4)],'EdgeColor'...
          ,'r','LineWidth',2); 
    ML_result = sprintf('%0.3f,%s',scores(j),labels(j));
    disp(ML_result);
    ML_1 = sprintf('%0.3f',scores(j));
    ML_2 = sprintf('%s',labels(j));
    text(bboxes(j,1)-10,bboxes(j,2)-25,{[ML_1];[ML_2]},'FontSize',10,'Color','r','FontWeight','bold')
end

disp('[.2.] DONE: Ran F-RCNN Qwirkle Block Detector on Image')

% Now have bounding boxes, scores and labels

%% 3. Color Filtering + Localisation

% After ML detector is run:
% 1) Labels of which Shape that was detected
% 2) Approx Bounding box/centroid of each shape
% 3) Number of blocks detected (length of BB)

%close all

% ---------------------Detect Colors----------------------

%HSV
%hsv_path = rgb2hsv(customerImage);
num_blocks = size(scores,1);

%imshow(ROI_image); % ROI on cropped region of 9x9 grid (RGB Colorscape still)
hsv_path = rgb2hsv(ROI_image);

% -Initiate Threshold Iterator-
color_array = zeros(1,4); % array to store which color (R,G,B,Y)
color_hsv_low = zeros(1,3);
color_hsv_hi = zeros(1,3);

curr_filter_on = 1;
max_hsv = 4;
filter_counter = num_blocks;
block_counter = 0;

% "struct" to store x,y,z and hsv filter
cv_block_struct = zeros(4,num_blocks);
block_struct_row = 1;

    % Making HSV filtering dynamic and automatically iterate through all
    % 4 HSV filter ranges
    
for h = curr_filter_on:max_hsv % encoding RGBY as 1234
        
    [color_hsv_hi,color_hsv_low] = HSV_Iterator(h);
    
    % Create mask to find pixels with desired HSV ranges (binary mask) -
    % Current iterated HSV filter    
    mask_desired = (hsv_path(:,:,1) >= color_hsv_low(1)) & (hsv_path(:,:,1) <= color_hsv_hi(1)) & ...
            (hsv_path(:,:,2) >= color_hsv_low(2) ) & (hsv_path(:,:,2) <= color_hsv_hi(2)) & ...
            (hsv_path(:,:,3) >= color_hsv_low(3) ) & (hsv_path(:,:,3) <= color_hsv_hi(3));
    
%     figure
%     imshow(mask_desired);
    SE = strel('disk',2);
    mask_desired = imdilate(mask_desired,SE);
    
    stats = regionprops(mask_desired,'basic');
    centroids = cat(1,stats.Centroid);

    % For each region area for a particular HSV filter,
    % check if suitable sized area.

    areas = cat(1,stats.Area); %(suitable area > 150)
    [sort_area_m,sorted_area_row] = sort(areas,'descend'); 
       
    % Checking max number of items WITH a particular HSV filter
    for p = 1:filter_counter
            
       % block_locations(1,k) = centroids(sorted_area_row(p),1);
       % block_locations(2,k) = centroids(sorted_area_row(p),1);   
       min_block_size = 400;
            
      [color_row,color_col] = size(sort_area_m); %number of centroids per color
      % Error handling if no suitably sized object with color is present
        if (p > color_row)
            continue;
        end
        
        if (block_counter > num_blocks)
            continue;
        end
        
        if (color_row < num_blocks && sort_area_m(p,1) < min_block_size)
            continue;
        end                
            
        if (sort_area_m(p,1) >= min_block_size)
            hold on

            % Only plot a + if there is a suitable sized binary area           
            plot(centroids(sorted_area_row(p),1),centroids(sorted_area_row(p),2),'g+','LineWidth',2)
            cv_block_struct(1,block_struct_row) = centroids(sorted_area_row(p),1);
            cv_block_struct(2,block_struct_row) = centroids(sorted_area_row(p),2);
            cv_block_struct(3,block_struct_row) = 147.00;
            cv_block_struct(4,block_struct_row) = h; % which HSV filter was used
            block_counter = block_counter + 1;
            block_struct_row = block_struct_row + 1;
        else
            % not even one suitable block was found in particular color
            continue;
        end
    end 
end

% -----------ERROR CHECKING-----------
% Cleaning up double color localistaion errors AND outside ML results
 %Comparing all the other blocks with the first block
for j = 1 : size(cv_block_struct,2) 
    for check_ctr = 1 : size(cv_block_struct,2)  
        D = sqrt((cv_block_struct(1,j) - cv_block_struct(1,check_ctr))^2 +...
            (cv_block_struct(2,j) - cv_block_struct(2,check_ctr))^2);
        if (D < 10 && D > 0)
            doubleDetect = true;            
            cv_block_struct(1,check_ctr) = 0;
            cv_block_struct(2,check_ctr) = 0;
        end    
    end
end            

 % debug show the results of computer vision color/pose detection
image_place_data = cv_block_struct; % Image coordinate frame

disp('[.3.] DONE: Qwirkle Localisation and Color')

%% ---------------------Match Shape with Color----------------------

% Check which detected shape is in which color (compare centroids)
% cv_block_struct = x,y of centroid and which hsv filter it had used.
% analyse rows 1 (x) and rows 2 (y)
% bboxes is array of bounding boxes of detected shapes

pick_counter = 1;
j = 1;

% shape_color array
% row 1 = shape
% row 2 = color
missingCentroid = false;
shape_color = zeros(2,size(bboxes,1));
image_place_data = fix(image_place_data);
while (pick_counter <= size(bboxes,1) && missingCentroid == false)
    % each bounding box vector from FRCNN in turn
    ROI = bboxes(pick_counter,:); 
    while (j <= size(bboxes,1))
        % check if any of the color/centroids are in this current ROI 
        tf = isInROI(ROI,image_place_data(1,j),image_place_data(2,j));
        
        if (tf == true)            
            % Store which shape
            shape_color(1,pick_counter) = labels(pick_counter);
            % Store which color (matching)
            shape_color(2,pick_counter) = image_place_data(4,j);
            pick_counter = pick_counter + 1; % fill in shape_color array
            % after each successful match
            % Break out of loop
            plot(image_place_data(1,j),image_place_data(2,j),'bo','LineWidth',1.5);
            break;
        end
        
        % Error handle in case of missing centroid
        % at end of search through all existing centroids
        % assuming that bboxes were all correct/detected
        if (j == size(bboxes,1))
            % Can't find centroid
            
            if (pick_counter < size(bboxes,1))
                pick_counter = pick_counter + 1;
                break;
            else
                missingCentroid = true; % raise flag
                break;
            end                         
        end
        
        % if tf is false (the current centroid is not in current ROI
        j = j+1; % increment to next centroid location from CV
    end
    
    j = 1; % reset counter for the next centroid check
end

% eg: Green Clover, Red Starburst
% Debug_ Interpret in shape_color array (for use at Conveyor)
for r = 1 : size(shape_color,2)
    matchIntepretation = sprintf('%s %s',whatShape(shape_color(1,r)),whatColor(shape_color(2,r)));
    disp(matchIntepretation);
end

disp('[.4.] DONE: Matched Shape and Color ')

%% ---------------------Orientation of Blocks----------------------
% Image processing to determine orientation of blocks
% Call function for each detected block in turn

bdim = 50;
tempROI_image = ROI_image;
for k = 1: size(image_place_data,2)

    hold on
    
    if (image_place_data(1,k) == 0 || image_place_data(2,k) == 0)
        continue;
    end
    
    % Make temp comparison image (for each block)    
    angle_roi = [image_place_data(1,k)-bdim/2,image_place_data(2,k)-bdim/2,bdim,bdim];
    aligned_block = imcrop(tempROI_image,angle_roi); % CustomerImage remains as RGB for color detection
            
    % Call function to detect orientation
    block_angle = checkBlockOrientation(aligned_block);

    image_place_data(5,k) = (round(block_angle));
    block_orientation = sprintf('%.2f',block_angle);
    text(image_place_data(1,k),image_place_data(2,k)-50,block_orientation,'FontSize',12,'Color','b')
    
    tempROI_image = ROI_image;
end

hold off

% Desired pose Here

disp('[.5.] DONE: Block Orientation');

%% ---------------------Place Coordinates----------------------
% Applied to whole image struct (after it has been filled)

load('calibrationSession.mat', 'calibrationSession');

% From Extrinsic function output
translationVector = [21.6771020996404,-377.712398323210,859.963449998696];

rotationMatrix = [-0.000532049447634045,0.999998919650671,-0.00137026306816968;...
                0.999994863561974,0.000527715353405883,-0.00316138674858810;...
                -0.00316066022432677,-0.00137193804397179,-0.999994063988857];

% Convert image points to world coordinates (from struct)
% original image = 1200 x 1600
% rectROI = [506.00,240.00,578.00,582.00];

for bCount = 1:num_blocks

    image_place_data(1:2,bCount) = pointsToWorld(calibrationSession.CameraParameters,...
        rotationMatrix,translationVector,...
        [506.00+image_place_data(1,bCount),240.00+image_place_data(2,bCount)]);
end

% Array after conversion from image to world
world_place_data = image_place_data; % World coordinate frame (x,y,z,color)

% MATLAB -> Ethernet. Send array (homogeneous transform matrix form - pose) 

robot_place = [world_place_data(1,:) ; world_place_data(2,:) ; world_place_data(5,:)];
% might want all place for each block in one row

disp('Sent PLACE Coordinates to Robot Arm')

disp('[.6.] DONE: PLACE Coordinates');

%% Detect on Conveyor Belt (Simulated Conveyor or Real Conveyor)
% For each Block:
% [X,Y] PICK COORDINATES (WORLD frame)

% Load simulated 'conveyor' feed from images in file
list = dir('.\YOLO_TEST\ConveyorImages\*.jpg');
correctShape = false;
conv_match_ctr = 1;
correctColor = false;
foundAllBlocks = false;
pick_array = zeros(4,size(world_place_data,2));
checkMatch = false;

%conveyorTransform
%conveyorRotation

% store world X, world Y, angle (at conveyor) for each block (in turn)
pick_robot = zeros(1,3);

usingConveyor = false;
runOnce = false;

disp('---USING CONVEYOR CAMERA---');      
figure
while (foundAllBlocks ~= true && runOnce == false)
    
    runOnce = true;
    
    for conveyorImage = 1:length(list) - 15
        
        if (~usingConveyor)
            imagePath = fullfile(list(conveyorImage).folder,list(conveyorImage).name);
            cImage = imread(imagePath);        
        else
            % Change to conveyor camera
            cImage = MTRN4230_Image_Capture([],[]); %for conveyor camera (get one frame)
            %Load camera calibration .mat file
            %cImage = imread('.\YOLO_TEST\ConveyorImages\C43.jpg');

        end
        
        cImage = imcrop(cImage,[515.0,4.50,676.00,720.00]);
        imshow(cImage);

        [cBboxes,cScores,cLabels] = detect(detector_updated_final,cImage,'Threshold',0.30,...
             'NumStrongestRegions',10);

         % analysing current frame
         % for each desired shape in order of detection from customer image

         %for j = 1 : size(shape_color,2) 
           
            % Looking through shape_col array for current frame
            % 1. Wait for detection of each Shape
            % 2. Check if right color

            while (correctShape == false)        

                % Look for current shape_color pair in current frame from Conveyor               
               
                % Skip if missing a shape from color/shape match
                % (sequential scanning of array)
                %if (shape_color(1,j) == 0)
                %    break;
                %end

                % Execute function on the current ML results
                %[[LABELS: Circle,Clover,CrissCross,Diamond,Square,Starburst]]
                
                % Search for any of the shapes from customer image in
                % current frame?? (more efficient)
                anyShape = false;
                while (anyShape == false)
                    for j = 1 : size(shape_color,2)
                        [check,id] = shapeCheck(uint8(cLabels),shape_color(1,j));
                        if (check == true)
                            anyShape = true;
                            break;
                        end
                    end
                    break;
                end                

                %[check,id] = shapeCheck(uint8(cLabels),shape_color(1,j));

                if (anyShape == true) %redundant check (keep if still using sequential)
                    anyShape = false;    
                    correctShape = true; % if current shape from shape_col match array is detected
                    hold on
                    % Annotate Shape detection result
                    rectangle('Position',[cBboxes(id,1),cBboxes(id,2),cBboxes(id,3),cBboxes(id,4)],'EdgeColor'...
                        ,'g','LineWidth',2); 
                    C_ML_result = sprintf('%f, %s',cScores(id),cLabels(id));
                    text(cBboxes(id,1)-10,cBboxes(id,2)-15,C_ML_result,'FontSize',10,'Color','r','FontWeight','bold')

                    % Stop conveyor
                    ML_result = sprintf('Possible %s detected',labels(j));
                    disp(ML_result);
                    disp('Stop the Conveyor');
                    pause(0.5);

                    % For the located shape:
                    % 2. Check if the matched shape is in right color
                    % Have BB for shape. Check if centroid is in bbox
                    tempCtr = 0; % for each detected block (flag)
                    
                    hsv_pathC = rgb2hsv(cImage);
                        
                    % Create mask to find pixels with desired HSV ranges (binary mask) -
                    % from customer image results
                    csv_encoding = shape_color(2,j);
                    [color_hsv_hi,color_hsv_low] = HSV_IteratorC(csv_encoding);               

                    mask_desiredC = (hsv_pathC(:,:,1) >= color_hsv_low(1)) & (hsv_pathC(:,:,1) <= color_hsv_hi(1)) & ...
                            (hsv_pathC(:,:,2) >= color_hsv_low(2) ) & (hsv_pathC(:,:,2) <= color_hsv_hi(2)) & ...
                            (hsv_pathC(:,:,3) >= color_hsv_low(3) ) & (hsv_pathC(:,:,3) <= color_hsv_hi(3));

                    statsC = regionprops(mask_desiredC,'basic');
                    Ccentroids = cat(1,statsC.Centroid);
                    Careas = cat(1,statsC.Area); %(suitable area > 150)
                    [sort_area_mC,sorted_area_rowC] = sort(Careas,'descend'); 
                        
                    if (size(sorted_area_rowC,1) < 2)
                        continue;
                    end

                    % check labels detected at conveyor    
                    % ROI. bbox of detected shape (known)
                    % x,y = centroids found from the HSV filter
                    colFound = false;
                    for ctr = 1 : size(shape_color,2)
                        checkMatch = isInROI(cBboxes(id,:),Ccentroids(sorted_area_rowC(ctr),1),...
                            Ccentroids(sorted_area_rowC(ctr),2));
                        if (checkMatch == true && colFound == false)
                            %which color was in BBox of correct shape
                            colFound = true; % one pass?
                            tempCtr = checkMatch; 
                            tempX = Ccentroids(sorted_area_rowC(ctr),1);
                            tempY = Ccentroids(sorted_area_rowC(ctr),2);
                        end
                    end
                    
                    % scan over largest centroids in matching color
                    if (tempCtr == true) 
                        % if yes -> correctColor = true;
                        correctColor = true;
                        plot(tempX,tempY,'g*','LineWidth',2);
                        disp('Correct Color AND Correct Shape!');
                        checkMatch = false; % reset
                        csv_encoding = 0; % reset csv encoding for next
                        % shape detection
                    else
                        correctColor = false;
                        disp('Incorrect Color BUT Correct Shape!');
                    end                                

                    pause(0.5);

                    % Further analysis (Angle + Send) 
                    if (correctColor == true)
                        tempROI_imageC = cImage;
                        Qwirkle_Con_Match = sprintf('%d: %s %s FOUND',conv_match_ctr,whatColor(shape_color(2,j)),cLabels(id));
                        disp(Qwirkle_Con_Match);
                                                                       
                        % 3. Detected pose (match to customer's desired pose)
                            angle_roiC = [tempX-bdim/2,tempY-bdim/2,bdim,bdim];
                            aligned_blockC = imcrop(tempROI_imageC,angle_roiC); % CustomerImage remains as RGB for color detection

                            % Call function to detect orientation at
                            % conveyor
                            block_angleC = checkBlockOrientation(aligned_blockC);
                            Cblock_orientation = sprintf('%.2f',block_angleC);
                            text(tempX,tempY-50,Cblock_orientation,'FontSize',10,'Color','b')
    
                            disp('Detected Orientation of a Desired Block');         
                            pause(0.5);

                        % 4. Send PICK Data to Robot Arm for the designated
                            % shape/color block
                            %[515.0,4.50,676.00,720.00]

                            %robot_pick(1,1:2) = pointsToWorld(conveyorCalib,...
                            %conveyorRotation,conveyorTransform,...
                            %[515.0+tempX,4.50+tempY]);

                            % send through ethernet
                            
                            % ---CHECK REACHABILITY---
                            
                            robot_pick(1,3) = block_angleC;                            
                            pick_command = sprintf('Sent PICK coordinates for block %d to Robot'...
                                ,conv_match_ctr);
                            disp(pick_command);                             
                            disp('Robot Arm Picking Block...');                             
                            pause(5.0);    
                            tempCtr = 0;
                        
                        % If all required blocks are found
                        % TODO: factor in the missing centroids
                        if (conv_match_ctr == size(shape_color,2))
                            foundAllBlocks = true;
                            completed_decoration = sprintf('~~~ALL %d BLOCKS FOUND AND PLACED ON CAKE~~'...
                                ,conv_match_ctr);
                            disp(completed_decoration);
                            pause(2);
                            break;
                        else
                            
                            disp('Robot Arm Finished Placing Block...');                             
                            pause(2.0);
                            conv_match_ctr = conv_match_ctr + 1; % max number of blocks
                            % to scan for overall
                            correctColor = false; % reset flag                        
                        end
                   
                        % If a block and color is successfully found, remove this
                        % from the array so the conveyor does not look for it again
                        shape_color(1,j) = -1;                                
                        check = false; % reset current T/F detection
                        correctShape = false;
                    else
                        
                        % If NOT, see if there were any other detected objects
                        % with the same shape and check their color                                
                        %(conv_match_ctr < size(shape_color,2) && correctShape == true)
                        disp('Checking Similar Shapes?');
                        % check duplicates over array
                        correctShape = false;
                    end                    
                
                end    
                % else continue to scan live feed
                % for next desired shape from customer                
                disp(' ');
                disp('~~LOOKING FOR NEXT BLOCK FROM CUSTOMER ORDER~~');         
                disp(' ');
                
                break;
            end
        %end
        % check next frame - HERE
    end    
end

disp('[.7.] TESTING: Detected the Customer Shapes on Conveyor');
%% FUNCTIONS

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
    
    % else checkMatch remains false

end

function block_angle = checkBlockOrientation(block_image)

    %convert to greyscale
    g = rgb2gray(block_image);              
    p = regionprops(g, 'Extrema'); 
    sides = p(1).Extrema(4,:) - p(1).Extrema(6,:); % Returns the sides of the square triangle that completes the two chosen extrema: Bottom-Right and Left-Bottom
    block_angle = rad2deg(atan(-sides(2)/sides(1)));  % Note the 'minus' sign compensates for the inverted y-values in image coordinates    
    
end

% HSV at Conveyor
function [color_hsv_hi,color_hsv_low] = HSV_IteratorC(counter)
    if (counter == 1)
        % Threshold for HSV - RED
        color_hsv_low = [0.90,0.405,0.100];
        color_hsv_hi = [0.980,1.00,0.900];
    end
    if (counter == 2)
        % Threshold for HSV - GREEN
        color_hsv_low = [0.180,0.300,0.010];
        color_hsv_hi = [0.430,0.700,0.620];
    end
    if (counter == 3)
        % Threshold for HSV - BLUE
        color_hsv_low = [0.542,0.290,0.00];
        color_hsv_hi = [0.701,1.00,0.807];        
    end
    if (counter == 4)
        % Threshold for HSV - YELLOW
        color_hsv_low = [0.10,0.500,0.152];
        color_hsv_hi = [0.230,0.800, 0.850];
    end
end

% HSV at Robot Cell
function [color_hsv_hi,color_hsv_low] = HSV_Iterator(counter)
    if (counter == 1)
        % Threshold for HSV - RED
        color_hsv_low = [0.850,0.275,0.20];
        color_hsv_hi = [1.00,0.800,0.800];
    end
    if (counter == 2)
        % Threshold for HSV - GREEN
        color_hsv_low = [0.180,0.200,0.084];
        color_hsv_hi = [0.330,0.700,0.600];
    end
    if (counter == 3)
        % Threshold for HSV - BLUE
        color_hsv_low = [0.542,0.290,0.20];
        color_hsv_hi = [0.801,1.00,0.807];        
    end
    if (counter == 4)
        % Threshold for HSV - YELLOW
        color_hsv_low = [0.10,0.165,0.152];
        color_hsv_hi = [0.200,0.600, 0.850];
    end
end

function robot_image = MTRN4230_Image_Capture (varargin)
%Table Camera (Robot Cell)
% {
   if nargin == 0 || nargin == 1
        fig1 =figure(1);
        axe1 = axes ();
        axe1.Parent = fig1;
        vid1 = videoinput('winvideo', 1, 'MJPG_1600x1200');
        video_resolution1 = vid1.VideoResolution;
        nbands1 = vid1.NumberOfBands;
        img1 = imshow(zeros([video_resolution1(2), video_resolution1(1), nbands1]), 'Parent', axe1);
        %prev1 = preview(vid1,img1);
        src1 = getselectedsource(vid1);
        src1.ExposureMode = 'manual';
        src1.Exposure = -4;
        src1.Contrast = 21;
        src1.Brightness = 128;
        robot_image = getsnapshot(vid1);
        
%         src1.Saturation = 78;
        %cam1_capture_func = @(~,~)capture_image(vid1,'table_');
        %prev1.ButtonDownFcn = cam1_capture_func;
        %fig1.KeyPressFcn = cam1_capture_func;
    end
%}
% Conveyor Camera
% {
    if nargin == 0 || nargin == 2
        fig2 =figure(2);
        axe2 = axes ();
        axe2.Parent = fig2;
        vid2 = videoinput('winvideo', 2, 'MJPG_1600x1200');
        video_resolution2 = vid2.VideoResolution;
        nbands2 = vid2.NumberOfBands;
        img2 = imshow(zeros([video_resolution2(2), video_resolution2(1), nbands2]), 'Parent', axe2);
        %prev2 = preview(vid2,img2);
        src2 = getselectedsource(vid2);
        src2.ExposureMode = 'manual';    
        src2.Exposure = -4;        
        src2.Brightness = 165;
        src2.Contrast = 32;
        robot_image = getsnapshot(vid2);
       
        %cam2_capture_func = @(~,~)capture_image(vid2,'conveyor_');
        %fig2.KeyPressFcn = cam2_capture_func;
        %prev2.ButtonDownFcn = cam2_capture_func;
    end

%}
end

