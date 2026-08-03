%This program can be used to create the Radial Line Profile of a GUV and
%integrate the peak area after baseline substraction. Special feature: it
%is possible to remove artefacts and aggregates by manual selection. This
%program is for multiple image analysis. Please specify the file path in line 36 before starting.
%In this programm the baseline is formed by employing the fitting function
%csapi.It allows for spline interpolation and removal of peak values.

%Important thing in beginning 
%1)line 50: select which images should be analysed in this folder. '*.tif'.You can indicate here if e.g. only pictures with the ending '*XX.tif' should be analysed. 
%2)line 53: Here you might need to adjust if you have more than 50 images to be analysed.
%3)line 55: define the approximate radius range (for 1024x1024 image a radius of 500)


%Rough procedure:
%1)Load image and apply gaussian filter with kernel pixel size 2
%2)Remove artefacts and aggrefated by cropping (the removed pixels are
%ignored in the following steps)
%3)Set center point for radial Line Profile
%4)Define x range of the membrane peak to exclude it in the folowing
%baseline formation
%5)Create baseline by cubic spline interpolation of the datapoints (exluding the
%membrane peak) employing the Fitting Toolbox.PeakIntegrals
%6)Substract the formed baseline from the line profile
%7)Select x range of the peak of the baseline corrected line profile
%8)calculate the area under the peak using Trapezoidal numerical
%integration and save it in Int
%9)Results are: 
%9.1)Peak areas in an array
%9.2)figure of line profile and baseline corrected line profile saved as
%png
%9.3)figure of baseline corrected line profile and Peak area saved as
%png

clc;
clear;	% Delete all variables.
close all;	% Close all figure windows except those created by imtool.
imtool close all;	% Close all figure windows created by imtool.
workspace;	% Make sure the workspace panel is showing.
fontSize = 16;

% Specify the folder where the files are located.
myFolder = 'YourPath';
% Check to make sure that folder actually exists.  Warn user if it doesn't.
if ~isdir(myFolder)
  errorMessage = sprintf('Error: The following folder does not exist:\n%s', myFolder);
  uiwait(warndlg(errorMessage));
  return;
end
% Get a list of all files in the folder with the desired file name pattern.
filePattern = fullfile(myFolder, '*00.tif'); % Change to whatever pattern you need.
theFiles = dir(filePattern);
%create matrix in which the values will be added
PeakIntegrals= zeros(50,2); 
Name=string;
Vradius=500;

for k = 1 : length(theFiles)
close all;	% Close all figure windows except those created by imtool.
imtool close all;	% Close all figure windows created by imtool.
clearvars -except PeakIntegrals and Name and k and theFiles and filePattern and myFolder and fullFileName and fontSize and Vradius;	% Delete all variables.
%define which files should be read
  baseFileName = theFiles(k).name;
  fullFileName = fullfile(myFolder, baseFileName);
  fprintf(1, 'Now reading %s\n', fullFileName);
% Now do whatever you want with this file name,
% such as reading it in as an image array with imread()
    
rawImage = imread(fullFileName);

%apply gaussian filter with kernel pixel size 2
gfImage=imgaussfilt(rawImage,2);

% Locate the center: To do so the membrane contour is detected via edge algorithm.  
%If the algorithm is not providing a good center or multiple centers you
%can manually choose the center.

adImage=im2double(gfImage);
AdjImg=imadjust(adImage);

Edge= edge(AdjImg); %edge detection to identify the vesicle membrane
[centers,radii] = imfindcircles(Edge,[100 Vradius],'Sensitivity',0.98); % find the center of the circle
cx=centers(:,1);
cy=centers(:,2);
 % figure to check the detected center
figure()
imshow(AdjImg)
title('masked Image', 'FontSize', fontSize);
axis on
hold on;
grid on;
grid minor;
set(gca,'GridColor','y'); 
set(gca,'MinorGridColor','r'); 
hold on
plot(cx, cy,'bo', 'MarkerSize', 5);
% Do you agree with the found center point? Otherwise select manually
promptMessage = sprintf('Do you agree with the calculated centerpoint?');
button = questdlg(promptMessage, 'Continue', 'Continue', 'No', 'Continue');

%Manual selection of the centerpoint
if strcmpi(button, 'No')
[cx,cy]=crosshair(1);
figure()
imshow(AdjImg)
title('masked Image', 'FontSize', fontSize);
axis on
hold on;
grid on;
grid minor;
set(gca,'GridColor','y'); 
set(gca,'MinorGridColor','r'); 
plot(cx, cy, 'ro', 'MarkerSize', 5); %Here you might adjust the radii if you have different image sizes.
plot(cx, cy, 'ro', 'MarkerSize', 25);
plot(cx, cy, 'ro', 'MarkerSize', 50);
plot(cx, cy, 'ro', 'MarkerSize', 100);
plot(cx, cy, 'ro', 'MarkerSize', 150);
plot(cx, cy, 'ro', 'MarkerSize', 225);
plot(cx, cy, 'ro', 'MarkerSize', 300);
plot(cx, cy, 'ro', 'MarkerSize', Vradius);
drawnow; % Force it to draw immediately.   

end

figure()
imshow(adImage)
title('masked Image', 'FontSize', fontSize);
axis on
hold on;
grid on;
grid minor;
set(gca,'GridColor','y'); 
set(gca,'MinorGridColor','r'); 
hold on
plot(cx, cy,'bo', 'MarkerSize', 5);

hFH = imfreehand(); % Actual line of code to do the drawing.
% Create a binary image ("mask") from the ROI object.
binaryImage = hFH.createMask();
xy = hFH.getPosition;

% Get coordinates of the boundary of the freehand drawn region.
structBoundaries = bwboundaries(binaryImage);
xy=structBoundaries{1}; % Get n by 2 array of x,y coordinates.
x = xy(:, 2); % Columns.
y = xy(:, 1); % Rows.

%Burn region as black into image by setting it to 0 wherever the mask is true.
adImage(binaryImage) = NaN;

%Creation of radial line profile
for w=1:Vradius %w is the radial distance from the central point if bigger images are used adjust w
profile=radialAverage(adImage,cx,cy,w);
LineProfile(w,1)=w;
LineProfile(w,2)=profile;
end

xValue=LineProfile(:,1);
yValue=LineProfile(:,2);

figure()
plot(xValue, yValue, 'b-', 'LineWidth', 3)
grid on;
title('Average Radial Profile');
xlabel('Distance from center', 'FontSize', fontSize);
ylabel('Average Pixel Intensity', 'FontSize', fontSize);

%To substract the background a baseline needs to be formed. For this first the
%values of the peak need to be excluded. The remaining points are fitted
%using a spline interpolation.

while ~exist('AnswerVariable','var')
 %Select range of x Values that should be excluded for the formation of the baseline
[x1, ~] = ginput(1);
[~,xI_1]=min(abs(xValue-x1));%find the closest xValue for selected point x1
x1_exc=xValue(xI_1);
hold on
plot(x1_exc,yValue(x1_exc),'k o');

[x2, ~] = ginput(1);
[~,xI_2]=min(abs(xValue-x2));%find the closest xValue for selected point x2
x2_exc=xValue(xI_2);
hold on
plot(x2_exc,yValue(x2_exc),'k o');
delx=x2_exc-x1_exc;
lengthM=Vradius-delx; %define Matrix that includes the data that will be fitted
M=[lengthM,1];
% fill the fitting matrix

for h=1:x1_exc %w signal before the peak
M(h,1)=xValue(h);
M(h,2)=yValue(h);
end
for j=x2_exc:Vradius %w signal after the peak
M(j-delx,1)=xValue(j);
M(j-delx,2)=yValue(j);
end

%For baseline formation do spline interpolation:
%First define x range which is used for calculation of baseline y Values.
%For this x range the baseline y Values are calculated by interpolating 
% the "peak-excluding" x and y values (x_corr and y_corr).
%Finally the original yValues are substracted by the baseline y Values (y_baseline_cor).

xb=[1:1:w]; 
x_corr=M(:,1);
y_corr=M(:,2);
%for cubic spline interpolation use csapi
yb = transpose(csapi(x_corr,y_corr,xb)); 
%for smoothing spline interpolation use csaps yb=(x,y,p,xx) 
%p is smoothing parameter. For p = 0, f is the least-squares straight-line fit to the data. 
%For p = 1, f is the variational, or natural, cubic spline interpolant. As p moves from 0 to 1, 
%the smoothing spline changes from one extreme to the other.
%yb = transpose(csaps(x_corr,y_corr,0,xb));  

y_baseline_cor=yValue-yb; %baseline substraction

figure()
plot(xValue, yValue, '-b', 'LineWidth', 1.5)
hold on
plot(xb,yb,'-.c', 'LineWidth', 1.5);
title('Baseline formation');
xlabel('Distance from center');
ylabel('Intensity');
legend('Line Profile','Baseline')      
      

promptMessage = sprintf('Do you want to continue fitting the data?');
button = questdlg(promptMessage, 'Continue', 'Continue', 'No', 'Continue');

if strcmpi(button, 'No')
  AnswerVariable=zeros(2,2) ; 
end
end


%Identify the peak and calculate the peak integral
[pks, locs] = findpeaks(y_baseline_cor);% Peak Values & Locations
idxmax = locs(pks == max(pks));% Highest Peak

xIntmin = find(y_baseline_cor(1:idxmax) < 0.0001*y_baseline_cor(idxmax), 1, 'last');
xIntmax = idxmax + find(y_baseline_cor(idxmax:end) < 0.0001*y_baseline_cor(idxmax), 1, 'first');

peakpoints = ~excludedata(xValue,y_baseline_cor,'domain',[xIntmin xIntmax]);
yPeak=y_baseline_cor.*peakpoints;

figure()
plot(xValue, yValue, '-b', 'LineWidth', 1.5)
hold on
plot(xValue,yb,'-.c', 'LineWidth', 1.5)
grid on;
title('Baseline formation');
xlabel('Distance from center');
ylabel('Intensity');
legend('Line Profile','Baseline')

%save the current figure as image: https://de.mathworks.com/help/matlab/ref/print.html
%fig_name = strcat('Baseline_formation_',num2str(k));
%print(h,fig_name,'-dpng'); 
%ask user to continue or stop processing

figure
plot(xValue, y_baseline_cor)
hold on
plot(xValue(locs), pks, '^r')% Plot Peaks
plot(xValue(xIntmin), y_baseline_cor(xIntmin), 'og');% Plot Approximate Zeros
plot(xValue(xIntmax), y_baseline_cor(xIntmax), 'og');% Plot Approximate Zeros
hold on
%Color peak area
hold on
area(yPeak)
%Integrate using trpz
Int=trapz(yPeak);

%save the current figure as image: https://de.mathworks.com/help/matlab/ref/print.html
%save the current figure as image: https://de.mathworks.com/help/matlab/ref/print.html
%fig_name = strcat('Peak_integration_',num2str(k));
%print(g,fig_name,'-dpng'); 

%Save the peak integrals in a matrix
PeakIntegrals(k,1)=k;
PeakIntegrals(k,2)=Int;
Name(k,1)=k;
Name(k,2)=baseFileName;

%ask user to continue or stop processing
promptMessage = sprintf('Do you want to continue processing,\nor Cancel to abort processing?');
button = questdlg(promptMessage, 'Continue', 'Continue', 'Cancel', 'Continue');
if strcmpi(button, 'Cancel')
  break; 
end

end
close all;	% Close all figure windows except those created by imtool.
imtool close all;	% Close all figure windows created by imtool.
clearvars -except PeakIntegrals and Name
fprintf(1, 'Nice work ;)');