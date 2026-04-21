classdef CollectiveMotionAnalyzer_udm_lightOnOff < handle
    properties
        data            % table with tracking data
        lightDirection  % direction of light stimulus [x,y]
        minDisplacement   % threshold for "stationary"
        minStraightness   % threshold for "directional" vs "circling"
        hasLight          % true/false: light present
    populationMeanAngle = NaN;
    populationMeanRayleigh = NaN;
    end

    methods (Static)
        function out = conditional(cond, true_val, false_val)
            if cond
                out = true_val;
            else
                out = false_val;
            end
        end
    end

    methods
        %% CONSTRUCTOR
        function obj = CollectiveMotionAnalyzer_udm_lightOnOff(data, lightDirection, minDisplacement, minStraightness, hasLight)
            obj.data = data;
            obj.lightDirection = lightDirection / norm(lightDirection);
            if nargin < 3
                obj.minDisplacement = 10; % default
            else
                obj.minDisplacement = minDisplacement;
            end
            if nargin < 4
                obj.minStraightness = 0.5;
            else
                obj.minStraightness = minStraightness;
            end
            if nargin < 5
                obj.hasLight = true; % default: light assumed present
            else
                obj.hasLight = hasLight;
            end
            if obj.hasLight
                obj.computeLightAngles();
            else
                obj.data.angle_to_light = NaN(height(obj.data), 1); % field not applicable
            end
            
        end

        %% CLASSIFY TRACKS (stationary, circling, directional)
        function [trackStats, summaryStats] = classifyTracks(obj)
            allIDs = unique(obj.data.TRACK_ID);
            nTracks = numel(allIDs);

            labels = strings(nTracks,1); % stationary, circling, directional
            netDisp = zeros(nTracks,1);  % net displacement
            totDisp = zeros(nTracks,1);  % total displacement
            straightness = zeros(nTracks,1);
            meanSpeed = zeros(nTracks,1);
            deltaX = zeros(nTracks,1);
            deltaY = zeros(nTracks,1);

            % For directional cluster analysis
            directions = [];
            directions_trackIDs = [];
            deltaXs = [];
            deltaYs = [];
            speeds_dir = [];

            for i = 1:nTracks
                id = allIDs(i);
                mask = obj.data.TRACK_ID == id;
                track = obj.data(mask,:);
                track = sortrows(track, 'FRAME_SOURCE');
                if height(track) < 2
                    labels(i) = "Stationary";
                    continue;
                end

                dx = track.POSITION_X_TARGET(end) - track.POSITION_X_SOURCE(1);
                dy = track.POSITION_Y_TARGET(end) - track.POSITION_Y_SOURCE(1);
                deltaX(i) = dx;
                deltaY(i) = dy;
                netDisp(i) = sqrt(dx^2 + dy^2);

                x = [track.POSITION_X_SOURCE; track.POSITION_X_TARGET(end)];
                y = [track.POSITION_Y_SOURCE; track.POSITION_Y_TARGET(end)];
                dists = sqrt(diff(x).^2 + diff(y).^2);
                totDisp(i) = sum(dists);

                if totDisp(i) > 0
                    straightness(i) = netDisp(i) / totDisp(i);
                else
                    straightness(i) = 0;
                end

                meanSpeed(i) = mean(track.SPEED, 'omitnan');

                if netDisp(i) < obj.minDisplacement
                    labels(i) = "Stationary";
                elseif straightness(i) >= obj.minStraightness
                    labels(i) = "Directional";
                    theta = atan2(dy, dx);
                    directions = [directions; theta];
                    directions_trackIDs = [directions_trackIDs; id];
                    deltaXs = [deltaXs; dx];
                    deltaYs = [deltaYs; dy];
                    speeds_dir = [speeds_dir; meanSpeed(i)];
                else
                    labels(i) = "Circling";
                end
            end

            summaryStats.nTracks = nTracks;
            summaryStats.nStationary = sum(labels == "Stationary");
            summaryStats.nCircling = sum(labels == "Circling");
            summaryStats.nDirectional = sum(labels == "Directional");
            summaryStats.percStationary = 100 * summaryStats.nStationary / nTracks;
            summaryStats.percCircling = 100 * summaryStats.nCircling / nTracks;
            summaryStats.percDirectional = 100 * summaryStats.nDirectional / nTracks;

            trackStats = table(allIDs, labels, netDisp, totDisp, straightness, meanSpeed, deltaX, deltaY, ...
                'VariableNames', {'TRACK_ID','Label','NetDisplacement','TotalDisplacement','Straightness','MeanSpeed','DeltaX','DeltaY'});

            summaryStats.directions = directions;
            summaryStats.directions_trackIDs = directions_trackIDs;
            summaryStats.deltaXs = deltaXs;
            summaryStats.deltaYs = deltaYs;
            summaryStats.speeds_dir = speeds_dir;
       
        
        
        end

%% INTERACTIVE DIRECTIONAL CLUSTERING
function clusterStats = analyzeDirectionalClustersInteractive(obj, summaryStats)
    if isempty(summaryStats.directions)
        disp('No directional traces found.');
        clusterStats = [];
        return;
    end

    XY = [cos(summaryStats.directions), sin(summaryStats.directions)];
    nPoints = size(XY,1);

    if nPoints < 3
        warning('There are too few data points to perform clustering (n=%d).', nPoints);
        nClusters = 1;
    else
        maxK = min(5, nPoints-1);

        if maxK >= 2
            eva = evalclusters(XY, 'kmeans', 'silhouette', 'KList', 2:maxK);
            nClusters = eva.OptimalK;
        else
            warning('Using 1 cluster because the silhouette cannot be calculated (n=%d).', nPoints);
            nClusters = 1;
        end
    end

    finished = false;
    while ~finished
        if nClusters == 1
            idx = ones(nPoints,1);
            C = mean(XY,1);
        else
            [idx, C] = kmeans(XY, nClusters, 'Replicates',10, 'MaxIter',500);
        end

        % Cluster statistics
        N_total = numel(summaryStats.directions);
        clusterStats = struct();
        clusterStats.nClusters = nClusters;
        clusterStats.labels = idx;
        clusterStats.clusterCenters = C;
        clusterStats.summary = [];
        clusterStats.idx = idx;

        for k = 1:nClusters
            mask = idx == k;
            N = sum(mask);
            perc = 100 * N / N_total;
            mean_cos = mean(cos(summaryStats.directions(mask)));
            mean_sin = mean(sin(summaryStats.directions(mask)));
            mean_angle = atan2(mean_sin, mean_cos);
            mean_vec_len = sqrt(mean_cos^2 + mean_sin^2);
            circ_std = sqrt(-2 * log(mean_vec_len));
            compX = mean(summaryStats.deltaXs(mask));
            compY = mean(summaryStats.deltaYs(mask));

            % --- Velocity statistics
            velocities = summaryStats.speeds_dir(mask);
            meanSpeed = mean(velocities,'omitnan');
            vel_std = std(velocities, 'omitnan');
            vel_sem = vel_std / sqrt(sum(~isnan(velocities)));

            % --- Light alignment
            lightDir = obj.lightDirection;
            clusterAngleVec = [compX, compY];
            if obj.hasLight && norm(lightDir) > 0 && norm(clusterAngleVec) > 0
                clusterAngleVec = clusterAngleVec / norm(clusterAngleVec);
                lightAlignment = dot(clusterAngleVec, lightDir);
            else
                lightAlignment = NaN;
            end

            clusterStats.summary(k).n = N;
            clusterStats.summary(k).perc = perc;
            clusterStats.summary(k).mean_angle = mean_angle;
            clusterStats.summary(k).mean_vec_len = mean_vec_len;
            clusterStats.summary(k).circ_std = circ_std;
            clusterStats.summary(k).compX = compX;
            clusterStats.summary(k).compY = compY;
            clusterStats.summary(k).meanSpeed = meanSpeed;
            clusterStats.summary(k).vel_std = vel_std;
            clusterStats.summary(k).vel_sem = vel_sem;
            clusterStats.summary(k).lightAlignment = lightAlignment;
        end

        fprintf('\n--- Analysis of main directions (clusters) ---\n');
        fprintf('Number of clusters: %d\n', nClusters);
fprintf('\n========================================\n');
if nClusters == 1
    fprintf('  SINGLE GROUP OF DIRECTIONAL CELLS\n');
else
    fprintf('  DIRECTIONAL CLUSTER ANALYSIS (%d clusters)\n', nClusters);
end
fprintf('========================================\n');
fprintf('Total directional tracks: %d\n\n', N_total);

for k = 1:nClusters
    info = clusterStats.summary(k);
    if nClusters == 1
        fprintf('--- Single population ---\n');
    else
        fprintf('--- Cluster %d (%.1f%% of directional tracks) ---\n', k, info.perc);
    end
    fprintf('  Mean speed     : %.2f +/- %.2f um/s (SEM=%.2f)\n', ...
            info.meanSpeed, info.vel_std, info.vel_sem);
    fprintf('  X component    : %.2f um\n', info.compX);
    fprintf('  Y component    : %.2f um\n', info.compY);
    fprintf('\n');
end
fprintf('========================================\n\n');
        startFrame = min(obj.data.FRAME_SOURCE);
        endFrame   = max(obj.data.FRAME_SOURCE);
        obj.plotPhototaxisRose(startFrame, endFrame);

        prompt = sprintf('Do you want to change the number of clusters? (now: %d) [Y/N]: ', nClusters);
        answer = input(prompt, 's');
        if strcmpi(answer, 'y')
            nClusters = input('Enter the new number of clusters: ');
        else
            finished = true;
        end
    end
end


        %% (ALTERNATIVE, NOT USED BY DEFAULT) NON-INTERACTIVE DIRECTIONAL CLUSTERING
        function clusterStats = analyzeDirectionalClusters(obj, summaryStats, nClusters)
            directions = summaryStats.directions;
            if isempty(directions)
                clusterStats = [];
                return;
            end
            XY = [cos(directions), sin(directions)];
            if nargin < 3 || isempty(nClusters)
                eva = evalclusters(XY, 'kmeans', 'silhouette', 'KList', 1:5);
                nClusters = eva.OptimalK;
            end
            [idx, C] = kmeans(XY, nClusters, 'Replicates',10, 'MaxIter',500);
            clusterStats = struct();
            clusterStats.nClusters = nClusters;
            clusterStats.labels = idx;
            clusterStats.clusterCenters = C;
            clusterStats.summary = [];
            N_total = numel(directions);
            for k = 1:nClusters
                mask = idx == k;
                N = sum(mask);
                perc = 100 * N / N_total;
                mean_cos = mean(cos(directions(mask)));
                mean_sin = mean(sin(directions(mask)));
                mean_angle = atan2(mean_sin, mean_cos);
                mean_vec_len = sqrt(mean_cos^2 + mean_sin^2);
                circ_std = sqrt(-2 * log(mean_vec_len));
                compX = mean(summaryStats.deltaXs(mask));
                compY = mean(summaryStats.deltaYs(mask));

                velocities = summaryStats.speeds_dir(mask);
                meanSpeed  = mean(velocities, 'omitnan');
                 vel_std    = std(velocities, 'omitnan');
                 vel_sem    = vel_std / sqrt(sum(~isnan(velocities)));

                lightDir = obj.lightDirection;
                clusterAngleVec = [compX, compY];
                if obj.hasLight && norm(lightDir) > 0 && norm(clusterAngleVec) > 0
                    clusterAngleVec = clusterAngleVec / norm(clusterAngleVec);
                    lightAlignment = dot(clusterAngleVec, lightDir);
                else
                    lightAlignment = NaN;
                end
                clusterStats.summary(k).n = N;
                clusterStats.summary(k).perc = perc;
                clusterStats.summary(k).mean_angle = mean_angle;
                clusterStats.summary(k).mean_vec_len = mean_vec_len;
                clusterStats.summary(k).circ_std = circ_std;
                clusterStats.summary(k).compX = compX;
                clusterStats.summary(k).compY = compY;
                clusterStats.summary(k).meanSpeed = meanSpeed;
                clusterStats.summary(k).vel_std        = vel_std;          
                clusterStats.summary(k).vel_sem        = vel_sem; 
                clusterStats.summary(k).lightAlignment = lightAlignment;
            end
        end

%% COMPUTE LIGHT ANGLES
function computeLightAngles(obj)
    if obj.hasLight
        dx = obj.data.POSITION_X_TARGET - obj.data.POSITION_X_SOURCE;
        dy = obj.data.POSITION_Y_TARGET - obj.data.POSITION_Y_SOURCE;

        magnitude = sqrt(dx.^2 + dy.^2);
        validMov = magnitude > 0;

        dx_norm = zeros(height(obj.data),1);
        dy_norm = zeros(height(obj.data),1);
        dx_norm(validMov) = dx(validMov) ./ magnitude(validMov);
        dy_norm(validMov) = dy(validMov) ./ magnitude(validMov);

        Lx = obj.lightDirection(1);
        Ly = obj.lightDirection(2);

        dotProd   = Lx .* dx_norm + Ly .* dy_norm;
        crossProd = Lx .* dy_norm - Ly .* dx_norm;

        obj.data.angle_to_light = atan2(crossProd, dotProd);
        obj.data.angle_to_light(~validMov) = NaN;
    else
        obj.data.angle_to_light = NaN(height(obj.data),1);
    end
end

      %% TIME WINDOW METRICS
function metrics = analyzeTimeWindow(obj, startFrame, endFrame, motileOnly, motileIDs)
    if nargin < 4
        motileOnly = false;
    end
    if nargin < 5
        motileIDs = [];
    end

    windowMask = obj.data.FRAME_SOURCE >= startFrame & obj.data.FRAME_SOURCE < endFrame;
    windowData = obj.data(windowMask, :);

    track_ids = unique(windowData.TRACK_ID);
    complete_tracks = [];
    for id = track_ids'
        track_frames = unique(windowData.FRAME_SOURCE(windowData.TRACK_ID == id));
        if length(track_frames) >= (endFrame - startFrame)
            complete_tracks = [complete_tracks; id];
        end
    end
    valid_mask = ismember(windowData.TRACK_ID, complete_tracks);
    windowData = windowData(valid_mask, :);

    if motileOnly && ~isempty(motileIDs)
        windowData = windowData(ismember(windowData.TRACK_ID, motileIDs), :);
    end

    if height(windowData) < 2
        metrics = obj.createDefaultMetrics();
        return
    end

    metrics.meanSpeed = mean(windowData.SPEED, 'omitnan');
    metrics.stdSpeed = std(windowData.SPEED, 'omitnan');
    metrics.displacement = mean(windowData.DISPLACEMENT, 'omitnan');
    metrics.stdDisplacement = std(windowData.DISPLACEMENT, 'omitnan');

    dcr_values = [];
    for id = unique(windowData.TRACK_ID)'
        track_data = windowData(windowData.TRACK_ID == id, :);
        track_data = sortrows(track_data, 'FRAME_SOURCE');
        dx = diff(track_data.POSITION_X_SOURCE);
        dy = diff(track_data.POSITION_Y_SOURCE);
        angles = atan2(dy, dx);
        angle_changes = abs(diff(angles));
        angle_changes = min(angle_changes, 2*pi - angle_changes);
        if ~isempty(angle_changes)
            dcr_values = [dcr_values; mean(angle_changes)];
        end
    end
    if ~isempty(dcr_values)
        metrics.directionalChange = mean(dcr_values);
        metrics.stdDirectionalChange = std(dcr_values);
    else
        metrics.directionalChange = 0;
        metrics.stdDirectionalChange = 0;
    end

   if obj.hasLight
    cos_per_track_win = [];
    for id = unique(windowData.TRACK_ID)'
        track_data = windowData(windowData.TRACK_ID == id, :);
        angles = track_data.angle_to_light;
        angles = angles(~isnan(angles) & ~isinf(angles));
        if ~isempty(angles)
            cos_per_track_win = [cos_per_track_win; mean(cos(angles))];
        end
    end
    if ~isempty(cos_per_track_win)
        metrics.lightAlignment = mean(cos_per_track_win);
        metrics.stdLightAlignment = std(cos_per_track_win);
    else
        metrics.lightAlignment = NaN;
        metrics.stdLightAlignment = NaN;
    end
else
    metrics.lightAlignment = NaN;
    metrics.stdLightAlignment = NaN;
end

    metrics.nTracks = numel(unique(windowData.TRACK_ID));
end

 %% TEMPORAL EVOLUTION (sliding window)
function results = analyzeTemporalEvolution(obj, windowSize, motileOnly, motileIDs)
    if nargin < 3
        motileOnly = false;
    end
    if nargin < 4
        motileIDs = [];
    end

    minFrame = min(obj.data.FRAME_SOURCE);
    maxFrame = max(obj.data.FRAME_SOURCE);
    nWindows = floor((maxFrame - minFrame - windowSize) / windowSize) + 1;
    arraySize = nWindows + 1;

    results = struct();
    metricFields = {'meanSpeed','stdSpeed','displacement','stdDisplacement', ...
                    'directionalChange','stdDirectionalChange','lightAlignment','stdLightAlignment', ...
                    'nTracks'};
    results.windowFrames = zeros(1,arraySize);
    results.windowTimes  = zeros(1,arraySize);
    for f = metricFields
        results.(f{1}) = zeros(1,arraySize);
    end

    idx = 1;
    for i = 1:nWindows
        startFrame = minFrame + (i-1)*windowSize;
        endFrame = startFrame + windowSize;
        windowMetrics = obj.analyzeTimeWindow(startFrame, endFrame, motileOnly, motileIDs);
        if ~isempty(windowMetrics)
            for f = metricFields
                results.(f{1})(idx) = windowMetrics.(f{1});
            end
            windowMask = obj.data.FRAME_SOURCE >= startFrame & obj.data.FRAME_SOURCE < endFrame;
            lastIdx = find(windowMask, 1, 'last');
            if ~isempty(lastIdx)
                results.windowFrames(idx) = obj.data.FRAME_SOURCE(lastIdx);
                results.windowTimes(idx)  = obj.data.POSITION_T_SOURCE(lastIdx);
            end
            idx = idx + 1;
        end
    end

    if endFrame < maxFrame
        startFrame = endFrame;
        endFrame = maxFrame;
        windowMetrics = obj.analyzeTimeWindow(startFrame, endFrame, motileOnly, motileIDs);
        if ~isempty(windowMetrics)
            for f = metricFields
                results.(f{1})(idx) = windowMetrics.(f{1});
            end
            windowMask = obj.data.FRAME_SOURCE >= startFrame & obj.data.FRAME_SOURCE <= endFrame;
            lastIdx = find(windowMask, 1, 'last');
            if ~isempty(lastIdx)
                results.windowFrames(idx) = obj.data.FRAME_SOURCE(lastIdx);
                results.windowTimes(idx)  = obj.data.POSITION_T_SOURCE(lastIdx);
            end
        end
    end

    % trim unused array entries
    for f = metricFields
        results.(f{1}) = results.(f{1})(1:idx-1);
    end
    results.windowFrames = results.windowFrames(1:idx-1);
    results.windowTimes  = results.windowTimes(1:idx-1);
end

function [results_all, results_motile] = analyzeTemporalEvolutionBoth(obj, windowSize, motileIDs)
    if nargin < 3
        motileIDs = [];
    end
    results_all = obj.analyzeTemporalEvolution(windowSize, false, []);
    results_motile = obj.analyzeTemporalEvolution(windowSize, true, motileIDs);
end

 %% PHOTOTAXIS ROSE PLOT
function plotPhototaxisRose(obj, startFrame, endFrame)
    windowMask = obj.data.FRAME_SOURCE >= startFrame & ...
                 obj.data.FRAME_SOURCE < endFrame;
    windowData = obj.data(windowMask, :);

    dx = windowData.POSITION_X_TARGET - windowData.POSITION_X_SOURCE;
    dy = windowData.POSITION_Y_TARGET - windowData.POSITION_Y_SOURCE;
    movement_angles = atan2(dy, dx);

    figure('Name', 'PhototaxisAnalysis', 'Position', [100 100 600 600]);
    ax = polaraxes;

    [counts, edges] = histcounts(movement_angles, 36, 'Normalization', 'probability');
    max_prob = max(counts);
    max_scale = ceil(max_prob * 20) / 20;

    polarhistogram(movement_angles, 36, 'Normalization', 'probability', ...
        'FaceColor', [0.8 0.2 0.2], 'EdgeColor', 'k', 'FaceAlpha', 0.6, ...
        'LineWidth', 1);
    hold(ax, 'on');

    if obj.hasLight && norm(obj.lightDirection) > 0
        light_angle = atan2(obj.lightDirection(2), obj.lightDirection(1));
        polarplot(ax, [light_angle light_angle], [0 max_scale], 'y-', 'LineWidth', 3);
    end

    mean_cos = mean(cos(movement_angles));
    mean_sin = mean(sin(movement_angles));
    mean_angle = atan2(mean_sin, mean_cos);
    mean_vector_length = sqrt(mean_cos^2 + mean_sin^2);
    circular_std = sqrt(-2 * log(mean_vector_length));

obj.populationMeanAngle = mean_angle;
obj.populationMeanRayleigh = mean_vector_length;

    [p_value, is_significant] = obj.testPhototaxis();

    net_movement = obj.calculateNetMovement();

    stats_text = sprintf(['Average Angle: %.1f°\n' ...
                          'Directional Force: %.2f\n' ...
                          'Circular Std Dev: %.2f°\n' ...
                          'P-value: %.3f\n' ...
                          'Phototaxis: %s\n' ...
                          'Net Movement X: %.2f\n' ...
                          'Net Movement Y: %.2f'], ...
                          rad2deg(mean_angle), ...
                          mean_vector_length, ...
                          rad2deg(circular_std), ...
                          p_value, ...
                          CollectiveMotionAnalyzer_udm_lightOnOff.conditional(is_significant, 'Significant', 'Not significant'), ...
                          net_movement(1), ...
                          net_movement(2));

    ax.ThetaTick = 0:45:315;
    ax.ThetaTickLabel = {'0°','45°','90°','135°','180°','225°','270°','315°'};
    r_ticks = 0:max_scale/5:max_scale;
    ax.RTick = r_ticks;
    ax.RTickLabel = cellstr(num2str(r_ticks' * 100, '%.1f%%'));
    ax.GridAlpha = 0.3;
    ax.MinorGridAlpha = 0.2;
    ax.ThetaMinorGrid = 'on';
    ax.RMinorTick = 'on';

    if obj.hasLight
        title(ax, {'Distribution of Motion Angles', 'Yellow line = Direction of Light'}, ...
              'FontSize', 14, 'FontWeight', 'bold');
    else
        title(ax, {'Distribution of Motion Angles'}, ...
              'FontSize', 14, 'FontWeight', 'bold');
    end

    text(ax, -0.6, 0.6, stats_text, ...
         'Units', 'normalized', 'FontSize', 12, ...
         'BackgroundColor', [1 1 1 0.8], 'EdgeColor', 'k');

    hold(ax, 'off');
end


%% PHOTOTAXIS TEST (one-sample t-test on cos(θ) per track)
function [p_value, is_significant] = testPhototaxis(obj, alpha)
    if nargin < 2
        alpha = 0.05;
    end

    if ~obj.hasLight || height(obj.data) == 0
        p_value = NaN;
        is_significant = false;
        return;
    end

    % Mean cos(θ) per track for tracks with net displacement >= minDisplacement
    track_ids = unique(obj.data.TRACK_ID);
    cos_per_track = NaN(numel(track_ids), 1);

    for k = 1:numel(track_ids)
        idx = obj.data.TRACK_ID == track_ids(k);
        track = obj.data(idx, :);
        track = sortrows(track, 'FRAME_SOURCE');

        dx = track.POSITION_X_TARGET(end) - track.POSITION_X_SOURCE(1);
        dy = track.POSITION_Y_TARGET(end) - track.POSITION_Y_SOURCE(1);
        netDisp = sqrt(dx^2 + dy^2);

        if netDisp < obj.minDisplacement
            continue
        end

        angles = track.angle_to_light;
        angles = angles(~isnan(angles) & ~isinf(angles));

        if ~isempty(angles)
            cos_per_track(k) = mean(cos(angles));
        end
    end

    cos_per_track = cos_per_track(~isnan(cos_per_track));
    n = numel(cos_per_track);

    if n < 2
        p_value = 1;
        is_significant = false;
        return;
    end

    meanAlignment = mean(cos_per_track);
    sem = std(cos_per_track) / sqrt(n);

    % one-sample t-test against 0, bidirectional
% One-sample t-test on meanAlignment against 0.
% The test is one-tailed in the direction actually observed in the data:
% depending on the sign of meanAlignment, the corresponding tail of the
% t-distribution is selected as p-value. This reflects the fact that the
% phototactic direction (toward or away from the source) is determined
% by the sign of the measured alignment, not assumed a priori.
%
% Naming convention (consistent with the main manuscript):
%   - meanAlignment > 0 → motion parallel to lightDirection
%                         → NEGATIVE phototaxis (away from light source)
%   - meanAlignment < 0 → motion antiparallel to lightDirection
%                         → POSITIVE phototaxis (toward light source)
% The variable names p_positive and p_negative below refer to the two
% tails of the t-distribution (positive/negative t_stat), not to the
% biological phototactic direction.

    t_stat = meanAlignment / sem;
    p_positive = 1 - tcdf(t_stat, n-1);   % upper tail: meanAlignment > 0 negative phototaxis (away from light source)
    p_negative = tcdf(t_stat, n-1);        % lower tail:meanAlignment < 0  positive phototaxis (toward light source)

    if meanAlignment >= 0
        p_value = p_positive;
    else
        p_value = p_negative;
    end
    p_value = max(min(p_value, 1), 0);

    is_significant = (p_value < alpha) && (abs(meanAlignment) > 0.20);

    % --- DEBUG ---
    fprintf('\n[DEBUG testPhototaxis]\n');
    fprintf('  n tracks motile : %d\n',   n);
    fprintf('  meanAlignment   : %.4f\n', meanAlignment);
    fprintf('  t_stat          : %.4f\n', t_stat);
    fprintf('  p_value         : %.4e\n', p_value);
    fprintf('  |alignment|>0.20: %d\n',   abs(meanAlignment) > 0.20);
    if meanAlignment >= 0
    fprintf('  Direction       : negative (away from the light source)\n');
else
    fprintf('  Direction       : positive (toward the light source)\n');
end
end

        %% NET MOVEMENT
        function net_movement = calculateNetMovement(obj)
            dx = obj.data.POSITION_X_TARGET - obj.data.POSITION_X_SOURCE;
            dy = obj.data.POSITION_Y_TARGET - obj.data.POSITION_Y_SOURCE;
            net_movement = [mean(dx), mean(dy)];
        end
        %% SUMMARY STATS
        function plotSummaryStats(obj, trackStats, summaryStats, converted_data)
    % 1. Mean speed distribution across tracks
    % 2. Net displacement distribution across tracks
    % 3. Bar plot of stationary/circling/directional track percentages
    % 4. Mean speed autocorrelation across tracks

    figure('Name','TracksStat','Position',[100 100 1200 800]);

    % --- Subplot 1: Mean speed histogram
    subplot(2,2,1);
    speeds = trackStats.MeanSpeed;
    histogram(speeds, 30, 'FaceColor',[0.3 0.6 0.9]);
    xlabel('Average track velocity (µm/s)');
    ylabel('Track count');
    title('Average velocity distribution');
    grid on
    hold on
    m = mean(speeds,'omitnan');
    s = std(speeds,'omitnan');
    n = sum(~isnan(speeds));
    sem = s/sqrt(n);
    yl = ylim;
    plot([m m], yl, 'r--', 'LineWidth',2, 'DisplayName','Mean');
    legend({'Distribution','Average'},'Location','best');
    text(m, yl(2)*0.85, sprintf('Average = %.2f\nStd = %.2f\nSEM = %.2f', m, s, sem), ...
         'Color', 'r', 'FontSize', 10, 'FontWeight', 'bold','HorizontalAlignment','left');

    % --- Subplot 2: Net displacement histogram
    subplot(2,2,2);
    disps = trackStats.NetDisplacement;
    histogram(disps, 30, 'FaceColor',[0.7 0.3 0.8]);
    xlabel('Net track displacement (µm)');
    ylabel('Track count');
    title('Net displacement distribution');
    grid on
    hold on
    m2 = mean(disps,'omitnan');
    s2 = std(disps,'omitnan');
    n2 = sum(~isnan(disps));
    sem2 = s2/sqrt(n2);
    yl = ylim;
    plot([m2 m2], yl, 'r--', 'LineWidth',2, 'DisplayName','Mean');
    legend({'Distribution','Average'},'Location','best');
    text(m2, yl(2)*0.85, sprintf('Average = %.2f\nStd = %.2f\nSEM = %.2f', m2, s2, sem2), ...
         'Color', 'r', 'FontSize', 10, 'FontWeight', 'bold','HorizontalAlignment','left');

    % --- Subplot 3: Track behavior percentages
    subplot(2,2,3);
    perc = [summaryStats.percStationary, summaryStats.percCircling, summaryStats.percDirectional];
    bar(perc, 'FaceColor',[0.2 0.7 0.3]);
    set(gca, 'XTickLabel', {'Stationary','Circling','Directional'});
    ylabel('Percentage (%)');
    ylim([0 100]);
    title('Percentage of track types');
    grid on
    for k = 1:numel(perc)
        text(k, perc(k)+3, sprintf('%.1f%%', perc(k)), ...
            'HorizontalAlignment','center','FontWeight','bold','Color','k');
    end

    % --- Subplot 4: Mean speed autocorrelation (with error band)
    subplot(2,2,4);
    maxLag = 10;
    autocorr_all = nan(height(trackStats), maxLag+1);
    for i = 1:height(trackStats)
        id = trackStats.TRACK_ID(i);
        speeds = converted_data.SPEED(converted_data.TRACK_ID==id);
        if numel(speeds) > maxLag
            ac = xcorr(speeds-mean(speeds,'omitnan'), maxLag, 'coeff');
            autocorr_all(i,:) = ac(maxLag+1:end);
        end
    end
    mean_autocorr = mean(autocorr_all,1,'omitnan');
    std_autocorr = std(autocorr_all,0,1, 'omitnan');
    n_auto = sum(~isnan(autocorr_all),1);
    sem_autocorr = std_autocorr ./ sqrt(n_auto);
    lags = 0:maxLag;
    fill([lags fliplr(lags)], [mean_autocorr+sem_autocorr fliplr(mean_autocorr-sem_autocorr)], ...
        [0.9 0.7 0.4],'FaceAlpha',0.3,'EdgeColor','none');
    hold on
    plot(lags, mean_autocorr, '-o', 'Color', [0.9 0.4 0.1], 'LineWidth', 2);
    xlabel('Lag (frame)');
    ylabel('Average speed autocorrelation');
    title('Speed autocorrelation of tracks');
    grid on

    sgtitle('Summary statistics of tracks');
end
        %% PLOT NET MOVEMENT + CLUSTER
        function plotNetMovement(obj, clusterStats)
            figure('Name', 'NetMovementAnalysis(Clusters)', 'Position', [100 100 600 600]);
            ax = gca;
            hold(ax, 'on');
            axis equal
            grid on
            ax.GridAlpha = 0.15;
            ax.MinorGridLineStyle = ':';
            ax.MinorGridAlpha = 0.1;
            grid minor
            box on

            originColor = [0.2 0.2 0.2];
            movementColor = [0 0.6 0];
            lightColor = [0.95 0.8 0.2];

            net_movement = obj.calculateNetMovement();
            max_mod = norm(net_movement);

            if exist('clusterStats', 'var') && ~isempty(clusterStats)
                for k = 1:clusterStats.nClusters
                    comp = [clusterStats.summary(k).compX, clusterStats.summary(k).compY];
                    mod = norm(comp);
                    max_mod = max(max_mod, mod);
                end
            end

            limit = ceil(max_mod * 1.5);
            xlim([-limit limit]);
            ylim([-limit limit]);

            if norm(net_movement) > 0
                net_dir = net_movement / norm(net_movement);
            else
                net_dir = [0 0];
            end

            if obj.hasLight && norm(obj.lightDirection) > 0
                light_dir = obj.lightDirection / norm(obj.lightDirection);
            else
                light_dir = [0 0];
            end

            hOrigin = plot(0, 0, 'o', ...
                'MarkerSize', 8, ...
                'MarkerFaceColor', originColor, ...
                'MarkerEdgeColor', originColor, ...
                'LineWidth', 1.5);

            plotHandles = hOrigin;
            legendEntries = {'Origin'};

%             hNet = quiver(0, 0, net_movement(1), net_movement(2), 0, ...
%                 'LineWidth', 2.5, ...
%                 'MaxHeadSize', 0.5, ...
%                 'Color', movementColor);
%             plotHandles(end+1) = hNet;
%             legendEntries{end+1} = 'Net Movement';

            hNetLine = plot([0 net_dir(1)*limit], [0 net_dir(2)*limit], '--', ...
                'LineWidth', 2, 'Color', [0 0.6 0]);
            plotHandles(end+1) = hNetLine;
            legendEntries{end+1} = 'Net Movement Direction';

            if obj.hasLight && norm(obj.lightDirection) > 0
                hLight = plot([0 light_dir(1)*limit], [0 light_dir(2)*limit], '-', ...
                    'LineWidth', 3, 'Color', lightColor);
                plotHandles(end+1) = hLight;
                legendEntries{end+1} = 'Light Direction';
            end

            clusters_table = {};
            if exist('clusterStats', 'var') && ~isempty(clusterStats)
                clusterColors = lines(clusterStats.nClusters);
                for k = 1:clusterStats.nClusters
                    compX = clusterStats.summary(k).compX;
                    compY = clusterStats.summary(k).compY;
                    mod = norm([compX, compY]);
                    ang = atan2d(compY, compX);
                    h = quiver(0, 0, compX, compY, 0, ...
                        'LineWidth', 2.5, ...
                        'MaxHeadSize', 0.5, ...
                        'Color', clusterColors(k,:));
                    plotHandles(end+1) = h;
                    legendEntries{end+1} = sprintf('Cluster %d', k);
                    clusters_table{end+1,1} = sprintf('Cluster %d', k);
                    clusters_table{end,2} = mod;
                    clusters_table{end,3} = ang;
                end
            end

            title('Analysis of Net Movement and Main Directions', ...
                'FontName', 'Arial', 'FontSize', 14, 'FontWeight', 'bold');
            xlabel('displacement X (µm)', 'FontName', 'Arial', 'FontSize', 11);
            ylabel('displacement Y (µm)', 'FontName', 'Arial', 'FontSize', 11);
            set(gca, 'LineWidth', 1.2, 'TickLength', [0.02 0.02]);

            legend(plotHandles, legendEntries, ...
                'Location', 'best', ...
                'FontSize', 10, ...
                'FontName', 'Arial', ...
                'Box', 'off', ...
                'EdgeColor', 'none');

            [p_value, is_significant] = obj.testPhototaxis();
            magnitude = norm(net_movement);
            angle = atan2d(net_movement(2), net_movement(1));
            stats_text = sprintf([ ...
            'Net Movement:\n' ...
            '  Magnitude: %.2f µm\n' ...
            '  Angle: %.1f°\n' ...
            '\n'], ...
            magnitude, angle);

            stats_text = [stats_text sprintf( ...
            'P-value: %.3e\nPhototaxi: %s\n\n', ...
            p_value, ...
            CollectiveMotionAnalyzer_udm_lightOnOff.conditional(is_significant, 'Significant', 'Not significant'))];

            if ~isempty(clusters_table)
                for i = 1:size(clusters_table,1)
                    stats_text = [stats_text sprintf( ...
                        'Cluster %d:\n  Magnitude: %.2f µm\n  Angle: %.1f°\n', ...
                        i, clusters_table{i,2}, clusters_table{i,3})];
                end
            end

            annotation('textbox', ...
                [0.15 0.75 0.5 0.18], ...
                'String', stats_text, ...
                'FontSize', 10, ...
                'FontName', 'Consolas', ...
                'BackgroundColor', [1 1 1 0.9], ...
                'EdgeColor', [0.7 0.7 0.7], ...
                'LineWidth', 1, ...
                'FitBoxToText', 'on', ...
                'LineStyle', '-');

            hold off
        end

        %% PRINT RESULTS
        function printResults(obj)
            net_movement = obj.calculateNetMovement();
            [p_value, is_significant] = obj.testPhototaxis();
            dx = obj.data.POSITION_X_TARGET - obj.data.POSITION_X_SOURCE;
            dy = obj.data.POSITION_Y_TARGET - obj.data.POSITION_Y_SOURCE;
            movement_angles = atan2(dy, dx);

            mean_cos = mean(cos(movement_angles));
            mean_sin = mean(sin(movement_angles));
            mean_angle = atan2(mean_sin, mean_cos);
            mean_vector_length = sqrt(mean_cos^2 + mean_sin^2);
            circular_std = sqrt(-2 * log(mean_vector_length));

            speeds = sqrt(dx.^2 + dy.^2);
            mean_speed = mean(speeds, 'omitnan');
            speed_std = std(speeds, 'omitnan');
            speed_sem = speed_std / sqrt(sum(~isnan(speeds)));

            net_magnitude = norm(net_movement);
            dx_std = std(dx, 'omitnan') / sqrt(sum(~isnan(dx)));
            dy_std = std(dy, 'omitnan') / sqrt(sum(~isnan(dy)));
            net_error = sqrt(dx_std^2 + dy_std^2);

            fprintf('\n=== MOTION ANALYSIS REPORT ===\n');
            fprintf('Total number of frames: %d\n', height(obj.data));
            fprintf('Number of unique tracks: %d\n', length(unique(obj.data.TRACK_ID)));

            fprintf('\n--- NET MOVEMENT ---\n');
            fprintf('Magnitude: %.3f ± %.3f µm\n', net_magnitude, net_error);
            fprintf('X component: %.3f ± %.3f µm\n', net_movement(1), dx_std);
            fprintf('Y component: %.3f ± %.3f µm\n', net_movement(2), dy_std);
            fprintf('Angle: %.1f° ± %.1f°\n', rad2deg(mean_angle), rad2deg(circular_std));

            fprintf('\n--- MOVEMENT STATISTICS ---\n');
            fprintf('Mean speed: %.3f ± %.3f µm/s\n', mean_speed, speed_sem);
            fprintf('Directional strength: %.3f\n', mean_vector_length);
            fprintf('Circular standard deviation: %.1f°\n', rad2deg(circular_std));

            fprintf('\n--- PHOTOTAXIS ANALYSIS ---\n');
            fprintf('P-value: %.3e\n', p_value);
            fprintf('Statistical Significance: %s\n', ...
                CollectiveMotionAnalyzer_udm_lightOnOff.conditional(is_significant, 'Significant', 'Not significant'));
            if obj.hasLight
                fprintf('Angle to light direction: %.1f°\n', ...
                    rad2deg(abs(mean_angle - atan2(obj.lightDirection(2), obj.lightDirection(1)))));
            else
                fprintf('Angle to light direction: NA\n');
            end
            fprintf('\n================================\n\n');
        end

        %% TEMPORAL RESULTS PLOT
        function plotResults(obj, results, useSeconds)
            if nargin < 3
                useSeconds = false;
            end

            obj.printResults();

            fig = figure('Position', [100 100 1200 800],'Name','MovementAnalysis');
            set(fig, 'Color', 'white');

            if useSeconds
                timePoints = results.windowTimes;
                xLabelStr = 'Time (s)';
            else
                timePoints = results.windowFrames;
                xLabelStr = 'Frame';
            end

            subplot(2,2,1)
            obj.plotMetricWithStd(timePoints, results.meanSpeed, results.stdSpeed, 'b', ...
                'Average Speed ', 'Speed (µm/s)', xLabelStr);

            subplot(2,2,2)
            obj.plotMetricWithStd(timePoints, results.displacement, results.stdDisplacement, 'r', ...
                'Average Displacement', 'Displacement (µm)', xLabelStr);

            subplot(2,2,3)
            obj.plotMetricWithStd(timePoints, results.directionalChange, results.stdDirectionalChange, 'g', ...
                'Average Direction Change', 'Direction Change Rate - DCR (rad/s)', xLabelStr);

            subplot(2,2,4)
            if obj.hasLight
                obj.plotMetricWithStd(timePoints, results.lightAlignment, results.stdLightAlignment, 'm', ...
                    'Alignment with the Light', 'Alignment (cos(θ))', xLabelStr);
            else
                plot(timePoints, NaN(size(timePoints)), 'm-');
                title('Alignment with the Light (NA)');
                ylabel('Alignment (NA)');
                xlabel(xLabelStr);
            end

            sgtitle({['Movement Analysis Results'], ...
                     ['Date: ' datestr(now, 'dd-mm-yyyy HH:MM:SS')]}, ...
                     'FontSize', 16, 'FontWeight', 'bold');

        end

        %% HELPER FOR TEMPORAL PLOTS
        function plotMetricWithStd(obj, x, y, std_y, color, titleStr, ylabelStr, xlabelStr)
            hold on
            y_mean = mean(y);
            y_std = std(y);
            max_std = max(std_y);
            data_range = max(abs([y + std_y, y - std_y]));
            scale_factor = 10^floor(log10(data_range));
            max_scale = ceil(data_range / scale_factor) * scale_factor;

            fill([x fliplr(x)], [y + std_y fliplr(y - std_y)], color, ...
                'FaceAlpha', 0.2, 'EdgeColor', 'none');
            plot(x, y, [color '-'], 'LineWidth', 2.5);

            if contains(lower(titleStr), 'speed') || contains(lower(titleStr), 'displacement')
                ylim([0, max_scale]);
            else
                ylim([max(-max_scale, min(y - std_y)), min(max_scale, max(y + std_y))]);
            end

            grid on
            grid minor
            title(titleStr, 'FontSize', 14, 'FontWeight', 'bold')
            ylabel(ylabelStr, 'FontSize', 12)
            xlabel(xlabelStr, 'FontSize', 12)
            box on
            set(gca, 'FontSize', 11, 'LineWidth', 1)
            hold off
        end

                %% DEFAULT METRICS
        function metrics = createDefaultMetrics(obj)
            % Returns a NaN-filled metrics struct to avoid zero artefacts in plots.
            metrics = struct();
            metrics.meanSpeed = NaN;
            metrics.stdSpeed = NaN;
            metrics.displacement = NaN;
            metrics.stdDisplacement = NaN;
            metrics.directionalChange = NaN;
            metrics.stdDirectionalChange = NaN;
            if obj.hasLight
                metrics.lightAlignment = NaN;
                metrics.stdLightAlignment = NaN;
            else
                metrics.lightAlignment = NaN;
                metrics.stdLightAlignment = NaN;
            end
            metrics.nTracks = 0;
        end

    end
end