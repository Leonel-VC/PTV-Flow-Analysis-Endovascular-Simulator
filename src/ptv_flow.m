%% PTV Flow Analysis for Endovascular Simulator
% This script processes video frames, tracks particles, calculates velocities,
% and computes flow characteristics within a specified region of interest.

clear all; close all; clc;

%% ========== CONFIGURATION PARAMETERS ==========
% Video settings
videoFile = '10V_slow.mp4';
tubeWidth = 10;  % [mm] Width of the tube for flow calculation

% Color filtering parameters (HSV ranges for particle detection)
% [H_min H_max S_min S_max V_min V_max]
colorRange = [0.1 0.45 0.0 0.1 0.25 0.4];

% Particle detection parameters
minParticleArea = 8;    % Minimum area for particle filtering
minCircularity = 0.7;   % Minimum circularity for particle identification
maxDisplacement = 50;   % Maximum displacement for particle matching (pixels)

% Output settings
saveVideos = true;      % Set to false to skip video generation
videoFrameRate = 30;    % Output video frame rate

%% ========== STEP 1: LOAD AND PROCESS VIDEO ==========
fprintf('Loading video: %s\n', videoFile);
vidObj = VideoReader(videoFile);
dt = 1 / 120;   % Slo-mo frame rate

% Initialize storage
frames = {};
binaryMasks = {};
frameIndex = 1;

fprintf('Processing frames...\n');
while hasFrame(vidObj)
    frame = readFrame(vidObj);
    
    % Convert to HSV and apply color filtering
    imgHSV = rgb2hsv(frame);
    binaryFrame = (imgHSV(:,:,1) >= colorRange(1)) & (imgHSV(:,:,1) <= colorRange(2)) & ...
                  (imgHSV(:,:,2) >= colorRange(3)) & (imgHSV(:,:,2) <= colorRange(4)) & ...
                  (imgHSV(:,:,3) >= colorRange(5)) & (imgHSV(:,:,3) <= colorRange(6));
    
    % Clean binary mask
    binaryFrame = imfill(binaryFrame, 'holes');
    filtered = bwareaopen(binaryFrame, minParticleArea);
    
    % Filter by circularity to remove non-particle objects
    if any(filtered(:))
        props = regionprops(filtered, "Circularity", "Area");
        Circularity = [props.Circularity];
        idx = Circularity >= minCircularity;
        cleanMask = ismember(labelmatrix(bwconncomp(filtered)), find(idx));
    else
        cleanMask = false(size(filtered));
    end
    
    % Store frames
    frames{frameIndex} = frame;
    binaryMasks{frameIndex} = cleanMask;
    
    frameIndex = frameIndex + 1;
    
    % Progress indicator
    if mod(frameIndex, 50) == 0
        fprintf('Processed %d frames\n', frameIndex);
    end
end
fprintf('Total frames processed: %d\n', length(frames));

%% ========== STEP 2: PARTICLE TRACKING (Hungarian Assignment) ==========
fprintf('Performing particle tracking...\n');
allVectors = {};  % Cell array to hold vectors per frame

for k = 1:(length(binaryMasks) - 1)
    mask1 = binaryMasks{k};
    mask2 = binaryMasks{k+1};
    
    % Extract centroids
    stats1 = regionprops(mask1, 'Centroid');
    stats2 = regionprops(mask2, 'Centroid');
    centroids1 = cat(1, stats1.Centroid);
    centroids2 = cat(1, stats2.Centroid);
    
    if isempty(centroids1) || isempty(centroids2)
        allVectors{k} = [];
        continue;
    end
    
    % Create cost matrix (Euclidean distances)
    N1 = size(centroids1, 1);
    N2 = size(centroids2, 1);
    costMatrix = zeros(N1, N2);
    for i = 1:N1
        for j = 1:N2
            costMatrix(i, j) = norm(centroids1(i, :) - centroids2(j, :));
        end
    end
    
    % Hungarian assignment with displacement threshold
    [pairs, ~] = matchpairs(costMatrix, maxDisplacement);
    
    % Compute velocities
    vectors = [];
    for p = 1:size(pairs, 1)
        i = pairs(p, 1);
        j = pairs(p, 2);
        p1 = centroids1(i, :);
        p2 = centroids2(j, :);
        displacement = p2 - p1;
        velocity = displacement;  % [pixels/frame]
        vectors(end+1, :) = [p1, velocity];  % [x, y, vx, vy]
    end
    
    allVectors{k} = vectors;
end
fprintf('Tracking complete.\n');

%% ========== STEP 3: FLOW CALCULATION IN ZONE ==========

% Let the user help with the selection of the width of the tube to convert
% the values of speed to real units
figure;
imshow(frames{1});
title("Select Width of the tube")
lineCoords = getline();
tubeWidthPixel = sqrt((lineCoords(2,1) - lineCoords(1,1))^2 + (lineCoords(2,2) - lineCoords(1,2))^2);
dxy = tubeWidth / tubeWidthPixel;

% Let the user select the region of interest for flow calculation
title("Select Area for Flow Calculation")
roi = getrect(); % Region of interest (ROI) for flow calculation

fprintf('Calculating flow characteristics...\n');

% Calculate flow
flowData = struct('avgVelocity', [], 'avgSpeed', [], ...
                  'flowRate', [], 'particleCount', []);

allParticle = [];

% Creating variable with all the particles info
for k = 1:length(allVectors)
    vectors = allVectors{k};
    
    allParticle(end+1:end+size(vectors,1),1:4) = vectors;
end

% Selecting only particles found in range of interest
maskRoi = all([allParticle(:, 1) > roi(1), allParticle(:, 1) < (roi(1) + roi(3)), ...
               allParticle(:, 2) > roi(2), allParticle(:, 2) < (roi(2) + roi(4))],2);

% Extract velocity component [pixels/frame] to [mm/second]
vx = allParticle(:, 3) * dxy / dt;
vy = allParticle(:, 4) * dxy / dt;

avgVx = mean(vx(maskRoi));
avgVy = mean(vy(maskRoi));

% Calculate average speed
avgSpeed = sqrt(avgVx.^2 + avgVy.^2);

% Calculate flow rate
crossSectionalArea = tubeWidth^2 * pi / 4; % Tube is considered a cylinder
flowRate = crossSectionalArea * avgSpeed * 60 / 1000; % [mm^3/second] to [mL/min]

% Store results
flowData.avgVelocity = [avgVx, avgVy];
flowData.avgSpeed = avgSpeed;
flowData.flowRate = flowRate;
flowData.particleCount = sum(maskRoi);

% Display flow statistics summary
fprintf('\n========== FLOW STATISTICS SUMMARY ==========\n');
fprintf('Average Flow Rate: %.2f mL/min\n', flowData.flowRate);
fprintf('Average Particle Speed: %.2f mm/second\n', flowData.avgSpeed);
fprintf('=============================================\n\n');

%% ========== STEP 4: GENERATE OUTPUT VIDEOS ==========
if saveVideos
    fprintf('Generating output videos...\n');
    
    % Video 1: Masked particles (bright on dark background)
    outputVideo1 = VideoWriter('Particle_Masks.mp4', 'MPEG-4');
    outputVideo1.FrameRate = videoFrameRate;
    open(outputVideo1);
    
    % Video 2: Velocity vectors overlay
    outputVideo2 = VideoWriter('Velocity_Field.mp4', 'MPEG-4');
    outputVideo2.FrameRate = videoFrameRate;
    open(outputVideo2);
    
    % Create figure for video rendering
    fig = figure('Position', [100, 100, 1200, 800]);

    % Max speed for vector plotting
    maxSpeed = max(sqrt(vx.^2 + vy.^2));
    
    for k = 1:(length(frames)-1)
        % Get current frame and vectors
        frame = frames{k};
        vectors = allVectors{k};
        
        % ----- Video 1: Particle Masks -----
        mask = binaryMasks{k};
        maskRGB = imoverlay(frame,mask,[1 0 0]);

        writeVideo(outputVideo1, maskRGB);
        
        % ----- Video 2: Velocity Vectors -----
        imshow(frame, 'Parent', subplot(1, 1, 1));
        hold on;
        
        if ~isempty(vectors)
            % Plot velocity vectors
            quiver(vectors(:,1), vectors(:,2), vectors(:,3), vectors(:,4), ...
                0, 'r', 'LineWidth', 1.5, 'MaxHeadSize', 1);
            
            % Add color coding for speed
            speeds = sqrt(vectors(:,3).^2 + vectors(:,4).^2) * dxy / dt;
            scatter(vectors(:,1), vectors(:,2), 20, speeds, 'filled');
            colormap('jet');
            colorbar('Position', [0.93 0.11 0.02 0.78]);
            clim([0 maxSpeed]);
        end
        
        title(sprintf('Frame %d: Particle Velocities', k));
        xlabel('X (pixels)');
        ylabel('Y (pixels)');
        grid on;
        hold off;
        
        % Capture frame
        F = getframe(gca);
        writeVideo(outputVideo2, F.cdata);
        
        % Progress indicator
        if mod(k, 50) == 0
            fprintf('Generated video frames: %d/%d\n', k, length(frames));
        end
    end
    
    close(outputVideo1);
    close(outputVideo2);
    close(fig);
    fprintf('Videos saved successfully.\n');
end

%% ========== STEP 5: VISUALIZATION AND ANALYSIS ==========
fprintf('Generating analysis plots...\n');

% Figure 1: Complete velocity vector field
figure('Position', [100, 100, 1200, 800]);
imshow(frames{1});
hold on;

% Plot all vectors across all frames
for k = 1:length(allVectors)
    vectors = allVectors{k};
    if ~isempty(vectors)
        quiver(vectors(:,1), vectors(:,2), vectors(:,3), vectors(:,4), ...
            0, 'r', 'LineWidth', 0.5, 'MaxHeadSize', 1);
    end
end

title('Complete Particle Velocity Vector Field');
xlabel('X (pixels)');
ylabel('Y (pixels)');
grid on;
hold off;

% Save the figure
saveas(gcf, 'Vector_Field.png');

% Figure 2: Speed Histogram
figure('Position', [100, 100, 1200, 800]);

allSpeeds = sqrt(vx(maskRoi).^2 + vy(maskRoi).^2);

histogram(allSpeeds, 30, 'FaceColor', [0.2 0.5 0.8]);
title('Particle Speed Distribution');
xlabel('Speed (mm/second)');
ylabel('Frequency');
grid on;

% Save the figure
saveas(gcf, 'Speed_Histogram.png');

fprintf('Analysis complete!\n');