% 1. Camera Calibration Process - Intrinsic (using checkerboard)

%Define images to process
imageFileNames = {'C:\Users\Jonathan\Documents\UNSW Engineering\2019\S2\MTRN4230\Group Project\A1_Images\Camera Calibration\Image2.png',...
    'C:\Users\Jonathan\Documents\UNSW Engineering\2019\S2\MTRN4230\Group Project\A1_Images\Camera Calibration\Image3.png',...
    'C:\Users\Jonathan\Documents\UNSW Engineering\2019\S2\MTRN4230\Group Project\A1_Images\Camera Calibration\Image4.png',...
    'C:\Users\Jonathan\Documents\UNSW Engineering\2019\S2\MTRN4230\Group Project\A1_Images\Camera Calibration\Image5.png',...
    'C:\Users\Jonathan\Documents\UNSW Engineering\2019\S2\MTRN4230\Group Project\A1_Images\Camera Calibration\Image6.png',...
    'C:\Users\Jonathan\Documents\UNSW Engineering\2019\S2\MTRN4230\Group Project\A1_Images\Camera Calibration\Image7.png',...
    'C:\Users\Jonathan\Documents\UNSW Engineering\2019\S2\MTRN4230\Group Project\A1_Images\Camera Calibration\Image8.png',...
    'C:\Users\Jonathan\Documents\UNSW Engineering\2019\S2\MTRN4230\Group Project\A1_Images\Camera Calibration\Image9.png',...
    'C:\Users\Jonathan\Documents\UNSW Engineering\2019\S2\MTRN4230\Group Project\A1_Images\Camera Calibration\Image10.png',...
    'C:\Users\Jonathan\Documents\UNSW Engineering\2019\S2\MTRN4230\Group Project\A1_Images\Camera Calibration\Image12.png',...
    'C:\Users\Jonathan\Documents\UNSW Engineering\2019\S2\MTRN4230\Group Project\A1_Images\Camera Calibration\Image13.png',...
    'C:\Users\Jonathan\Documents\UNSW Engineering\2019\S2\MTRN4230\Group Project\A1_Images\Camera Calibration\Image14.png',...
    'C:\Users\Jonathan\Documents\UNSW Engineering\2019\S2\MTRN4230\Group Project\A1_Images\Camera Calibration\Image15.png',...
    'C:\Users\Jonathan\Documents\UNSW Engineering\2019\S2\MTRN4230\Group Project\A1_Images\Camera Calibration\Image16.png',...
    'C:\Users\Jonathan\Documents\UNSW Engineering\2019\S2\MTRN4230\Group Project\A1_Images\Camera Calibration\Image17.png',...
    'C:\Users\Jonathan\Documents\UNSW Engineering\2019\S2\MTRN4230\Group Project\A1_Images\Camera Calibration\Image18.png',...
    'C:\Users\Jonathan\Documents\UNSW Engineering\2019\S2\MTRN4230\Group Project\A1_Images\Camera Calibration\Image19.png',...
    'C:\Users\Jonathan\Documents\UNSW Engineering\2019\S2\MTRN4230\Group Project\A1_Images\Camera Calibration\Image20.png',...
    'C:\Users\Jonathan\Documents\UNSW Engineering\2019\S2\MTRN4230\Group Project\A1_Images\Camera Calibration\Image21.png',...
    'C:\Users\Jonathan\Documents\UNSW Engineering\2019\S2\MTRN4230\Group Project\A1_Images\Camera Calibration\Image22.png',...
    'C:\Users\Jonathan\Documents\UNSW Engineering\2019\S2\MTRN4230\Group Project\A1_Images\Camera Calibration\Image23.png',...
    'C:\Users\Jonathan\Documents\UNSW Engineering\2019\S2\MTRN4230\Group Project\A1_Images\Camera Calibration\Image24.png',...
    'C:\Users\Jonathan\Documents\UNSW Engineering\2019\S2\MTRN4230\Group Project\A1_Images\Camera Calibration\Image25.png',...
    'C:\Users\Jonathan\Documents\UNSW Engineering\2019\S2\MTRN4230\Group Project\A1_Images\Camera Calibration\Image26.png',...
    'C:\Users\Jonathan\Documents\UNSW Engineering\2019\S2\MTRN4230\Group Project\A1_Images\Camera Calibration\Image27.png',...
    'C:\Users\Jonathan\Documents\UNSW Engineering\2019\S2\MTRN4230\Group Project\A1_Images\Camera Calibration\Image28.png',...
    'C:\Users\Jonathan\Documents\UNSW Engineering\2019\S2\MTRN4230\Group Project\A1_Images\Camera Calibration\Image29.png',...
    'C:\Users\Jonathan\Documents\UNSW Engineering\2019\S2\MTRN4230\Group Project\A1_Images\Camera Calibration\Image30.png',...
    };

% Detect checkerboards in images
[imagePoints, boardSize, imagesUsed] = detectCheckerboardPoints(imageFileNames);
imageFileNames = imageFileNames(imagesUsed);

% Read the first image to obtain image size
originalImage = imread(imageFileNames{1});
[mrows, ncols, ~] = size(originalImage);

% Generate world coordinates of the corners of the squares
squareSize = 25;  % in units of 'millimeters'
worldPoints = generateCheckerboardPoints(boardSize, squareSize);

% Calibrate the camera
[cameraParams, imagesUsed, estimationErrors] = estimateCameraParameters(imagePoints, worldPoints, ...
    'EstimateSkew', false, 'EstimateTangentialDistortion', false, ...
    'NumRadialDistortionCoefficients', 2, 'WorldUnits', 'millimeters', ...
    'InitialIntrinsicMatrix', [], 'InitialRadialDistortion', [], ...
    'ImageSize', [mrows, ncols]);

% Visualize pattern locations
h2=figure; showExtrinsics(cameraParams, 'CameraCentric')

% FocalLength: [528.3829 527.3726]                  (f_x, f_y)
% PrincipalPoint: [307.4073 239.0460]               (c_x, c_y)
% Skew: 0                                           (s - assumed to be 0)                            
% RadialDistortion: [0.0475 -0.1439]
% TangentialDistortion: [0 0]
% ImageSize: [480 640]

% K = Calibration matrix” or “Matrix of Intrinsic Parameters

% K = 
% [f_x, s, c_x ;
% 0, f_y, c_y ;
% 0, 0, 1] 

K_intrinsic = [528.3829, 0, 307.4073;
                0, 527.3726, 239.0460;
                0, 0, 1];

% 2. Camera Calibration Process - Extrinsic

% Calibration points are (X Y Z)
% T2 (175, -520, 147) -> (14,280)
% T1 (175, 0, 147) -> (795,283)
% T3 (175, 520, 147) -> (1595,289)
% T4 (548.6, 0, 147) -> (804,856)  

% Ke = [R|t]= [r11,r12, t1; r21, r22, t2; r31,r32, t3]
% Since all points on the chessboard are on a plane (Wz components = 0)

% Image of grid to locate T1,T2,T3 and T4 in camera frame (u,v)
blank_grid = imread('blank_image.jpg');
imshow(blank_grid)

% MATLAB function to solve PnP problem of extrinsics given relation between
% world and image coordinate systems
imagePoints = [14,280;795,283;1595,289;804,856;9,865]; % 4 x 2 array of [x,y] coordinates. 
worldPoints = [175,-520;175, 0;175, 520;548, 0;548.6,-520]; % 4 x 3 array of [x,y,z] coordinates
[R,t] = extrinsics(...
     imagePoints,worldPoints,cameraParams)
 
% ---------------EXTRINSINC RESULTS---------------
% R =
% 
%    -0.0009    1.0000   -0.0092
%     1.0000    0.0008   -0.0027
%    -0.0027   -0.0092   -1.0000
% 
% 
% t =
% 
%   320.0898 -145.7084  345.5445

% ---------------EXTRINSINC RESULTS---------------





