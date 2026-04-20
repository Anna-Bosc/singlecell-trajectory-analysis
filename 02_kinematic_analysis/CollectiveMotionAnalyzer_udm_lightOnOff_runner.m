% === COLLECTIVE MOTION ANALYSIS SCRIPT ===
% close all;
% clear all;
% Main directory
main_folder =['']; %insert main folder

% 0. Specify whether light is present
hasLight = true; % true if light is present, false otherwise

% 1. Load the .mat file
matFileName = fullfile(main_folder, 'converted_data.mat');
dataStruct = load(matFileName);
converted_data = dataStruct.converted_data;

if ~isempty(matFileName)
    file_path = fullfile(main_folder, 'Collective_global');
if ~exist(file_path, 'dir')
    mkdir(file_path);
end
end

% 2. Classification parameters
minDisplacement = 20;      % µm, threshold for stationary
minStraightness = 0.3;     % threshold for directional
lightDirection = [1 0];    % light direction (e.g. rightward)

% 3. Create analyzer object
analyzer = CollectiveMotionAnalyzer_udm_lightOnOff(converted_data, lightDirection, minDisplacement, minStraightness, hasLight);

% 4. Temporal evolution analysis
windowSize = 10;
results = analyzer.analyzeTemporalEvolution(windowSize);

% 5. Classify tracks
[trackStats, summaryStats] = analyzer.classifyTracks();
motile_ids = trackStats.TRACK_ID(strcmp(trackStats.Label, "Circling") | strcmp(trackStats.Label, "Directional"));

[results, results_motile] = analyzer.analyzeTemporalEvolutionBoth(windowSize, motile_ids);

% 6. Directional clustering (interactive)
clusterStats = analyzer.analyzeDirectionalClustersInteractive(summaryStats);
if ~isstruct(clusterStats) || isempty(clusterStats)
    clusterStats.nClusters = 0;
    clusterStats.summary = [];
end

% 7. Net movement and cluster directions plot
analyzer.plotNetMovement(clusterStats);

% 8. Summary statistics plot
analyzer.plotSummaryStats(trackStats, summaryStats, converted_data);

fprintf('Percentage Stationary: %.1f%%\n', summaryStats.percStationary);
fprintf('Percentage in Circling: %.1f%%\n', summaryStats.percCircling);
fprintf('Percentage Directional: %.1f%%\n', summaryStats.percDirectional);

% 9. Temporal results visualization
%analyzer.plotResults(results);         % frame axis
analyzer.plotResults(results, true);  % seconds axis

% 10. Phototaxis rose plot
startFrame = min(converted_data.FRAME_SOURCE);
endFrame = max(converted_data.FRAME_SOURCE);
analyzer.plotPhototaxisRose(startFrame, endFrame);

% 11. Print summary report
analyzer.printResults();

% === ADDITIONAL CALCULATIONS AND TABLES ===

% Mean and std track duration (in frames)
duration = zeros(height(trackStats),1);
for i = 1:height(trackStats)
    id = trackStats.TRACK_ID(i);
    frames = converted_data.FRAME_SOURCE(converted_data.TRACK_ID == id);
    if ~isempty(frames)
        duration_track = max(frames) - min(frames) + 1;
        duration(i) = duration_track;
    end
end
duration_mean= mean(duration, 'omitnan');
duration_std = std(duration, 'omitnan');

velocity = trackStats.MeanSpeed;
vel_mean= mean(velocity, 'omitnan');
vel_median = median(velocity, 'omitnan');
vel_std = std(velocity, 'omitnan');
vel_sem = vel_std / sqrt(sum(~isnan(velocity)));

net_disp = trackStats.NetDisplacement;
net_disp_mean= mean(net_disp, 'omitnan');
net_disp_median = median(net_disp, 'omitnan');
net_disp_std = std(net_disp, 'omitnan');
net_disp_sem = net_disp_std / sqrt(sum(~isnan(net_disp)));

% Mean speed autocorrelation (lag 1)
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
mean_autocorr = nanmean(autocorr_all,1);
std_autocorr = nanstd(autocorr_all,0,1);
n_auto = sum(~isnan(autocorr_all),1);
sem_autocorr = std_autocorr ./ sqrt(n_auto);
ac_lag1 = mean_autocorr(2); % lag 1
ac_lag1_std = std_autocorr(2);
ac_lag1_sem = sem_autocorr(2);

% Global net movement parameters
net_movement = analyzer.calculateNetMovement();
[p_value, is_significant] = analyzer.testPhototaxis();
dx = converted_data.POSITION_X_TARGET - converted_data.POSITION_X_SOURCE;
dy = converted_data.POSITION_Y_TARGET - converted_data.POSITION_Y_SOURCE;
movement_angles = atan2(dy, dx);
mean_cos = mean(cos(movement_angles));
mean_sin = mean(sin(movement_angles));
mean_angle = atan2(mean_sin, mean_cos);
mean_vector_length = sqrt(mean_cos^2 + mean_sin^2);
circular_std = sqrt(-2 * log(mean_vector_length));
err_mov_netto = sqrt( ...
    (std(dx,'omitnan')/sqrt(summaryStats.nTracks))^2 + ...
    (std(dy,'omitnan')/sqrt(summaryStats.nTracks))^2 );

if hasLight
    ang_light = rad2deg(abs(mean_angle - atan2(lightDirection(2), lightDirection(1))));
else
    ang_light = NaN;
end
figure('Name','HistStraightness')
histogram(trackStats.Straightness, 20);
xlabel('Straightness');
ylabel('Number of Tracks');
title('Straightness distribution of the tracks');

hold on;
xline(minStraightness, 'r--', 'Straightness Threshold');
hold off;

% === TABLES ===

% Summary table
mean_row = { ...
    matFileName, ...
    summaryStats.nTracks, summaryStats.nStationary, summaryStats.nCircling, summaryStats.nDirectional, ...
    summaryStats.percStationary, summaryStats.percCircling, summaryStats.percDirectional, ...
    duration_mean, duration_std, ...
    vel_mean, vel_median, vel_std, vel_sem, ...
    net_disp_mean, net_disp_median, net_disp_std, net_disp_sem, ...
    ac_lag1, ac_lag1_std, ac_lag1_sem, ...
    norm(net_movement), rad2deg(mean_angle), err_mov_netto, ...
    mean_vector_length, rad2deg(circular_std), ...
    p_value, string(CollectiveMotionAnalyzer_udm_lightOnOff.conditional(is_significant, 'Significant', 'Not Significant')), ...
    ang_light, ...
    clusterStats.nClusters ...
    };

mean_varnames = { ...
    'FileName', ...
    'nTracks', 'nStationary', 'nCircling', 'nDirectional', ...
    'percStationary [%]', 'percCircling [%]', 'percDirectional [%]', ...
    'duration_mean[frame]', 'duration_std [frame]', ...
    'vel_mean[µm/s]', 'vel_median [µm/s]', 'vel_std [µm/s]', 'vel_sem [µm/s]', ...
    'net_disp_mean[µm]', 'net_disp_median [µm]', 'net_disp_std [µm]', 'net_disp_sem [µm]', ...
    'autocorrLag1_mean', 'autocorrLag1_std', 'autocorrLag1_sem', ...
    'net_mov_mag [µm]', 'net_mov_angle [°]', 'err_net_mov [µm]', ...
    'Directional_strength', 'circular_std_dev [°]', ...
    'p_value', 'Significant', 'light_angle [°]', 'nCluster'};

T_mean= cell2table(mean_row, 'VariableNames', mean_varnames);

% Cluster table
cluster_rows = {};
for k=1:clusterStats.nClusters
    cs = clusterStats.summary(k);
    cluster_rows{end+1,1} = matFileName;
    cluster_rows{end,2} = clusterStats.nClusters;
    cluster_rows{end,3} = k;
    cluster_rows{end,4} = cs.perc;
    cluster_rows{end,5} = rad2deg(cs.mean_angle);
    cluster_rows{end,6} = norm([cs.compX, cs.compY]);
    cluster_rows{end,7} = rad2deg(cs.circ_std);
    cluster_rows{end,8} = cs.meanSpeed;
    cluster_rows{end,9} = cs.vel_std;
    cluster_rows{end,10} = cs.vel_sem;
    cluster_rows{end,11} = cs.lightAlignment;
    if hasLight
        cluster_rows{end,11} = cs.lightAlignment;
    else
        cluster_rows{end,11} = NaN;
    end
end

cluster_varnames = { ...
    'FileName', ...
    'nCluster', ...
    'ClusterNum', ...
    'C_perc [%]', ...
    'C_ang [°]', ...
    'C_mag [µm]', ...
    'C_std [°]', ...
    'C_vel [µm/s]', ...
    'C_vel_cluster_std [µm/s]', ...
    'C_vel_cluster_sem [µm/s]', ...
    'C_align'};

if clusterStats.nClusters == 0
    T_cluster = cell2table(cell(0, numel(cluster_varnames)), ...
                          'VariableNames', cluster_varnames);
else
    T_cluster = cell2table(cluster_rows, 'VariableNames', cluster_varnames);
end

save(fullfile(file_path, 'results_video.mat'), 'T_mean', 'T_cluster')
writetable(T_mean, fullfile(file_path, 'results_mean.xlsx'))
writetable(T_cluster, fullfile(file_path, 'results_cluster.xlsx'))
%% Save figures
prompt = sprintf('Do you want to save the figures? [Y/N]: ');
answer2 = input(prompt, 's');
if strcmpi(answer2, 'y')
    names = { ...
        'PhototaxisAnalysis', ...
        'TracksStat', ...
        'NetMovementAnalysis(Clusters)', ...
        'MovementAnalysis', ...
        'HistStraightness' ...
    };
    for i = 1:numel(names)
        fig = findobj('Type', 'figure', 'Name', names{i});
        if ~isempty(fig)
            savefig(fig, fullfile(file_path, [names{i} '.fig']));
            exportgraphics(fig, fullfile(file_path, [names{i} '.png']), 'Resolution', 300)

        end
    end
else
    finished = true;
end

% Save track stats table
writetable(trackStats,fullfile(file_path, 'tracks_stat.xlsx'));

% ALL TRACKS
T_temporal = table(results.windowFrames(:), results.windowTimes(:), ...
    results.meanSpeed(:), results.stdSpeed(:), ...
    results.displacement(:), results.stdDisplacement(:), ...
    results.directionalChange(:), results.stdDirectionalChange(:), ...
    results.lightAlignment(:), results.stdLightAlignment(:), ...
    results.nTracks(:), ...
    'VariableNames', {'Frame', 'Time_s', 'MeanSpeed', 'StdSpeed', ...
                      'MeanDisplacement', 'StdDisplacement', ...
                      'MeanDirectionalChange', 'StdDirectionalChange', ...
                      'MeanAlignment', 'StdAlignment', 'nTracks'});
writetable(T_temporal, fullfile(file_path,'all_temporal_results.xlsx'));
save(fullfile(file_path, 'all_temporal_results.mat'), 'T_temporal');

% MOTILE TRACKS ONLY
T_temporal_motile = table(results_motile.windowFrames(:), results_motile.windowTimes(:), ...
    results_motile.meanSpeed(:), results_motile.stdSpeed(:), ...
    results_motile.displacement(:), results_motile.stdDisplacement(:), ...
    results_motile.directionalChange(:), results_motile.stdDirectionalChange(:), ...
    results_motile.lightAlignment(:), results_motile.stdLightAlignment(:), ...
    results_motile.nTracks(:), ...
    'VariableNames', {'Frame', 'Time_s', 'MeanSpeed', 'StdSpeed', ...
                      'MeanDisplacement', 'StdDisplacement', ...
                      'MeanDirectionalChange', 'StdDirectionalChange', ...
                      'MeanAlignment', 'StdAlignment', 'nTracks'});
writetable(T_temporal_motile, fullfile(file_path, 'motile_temporal_results.xlsx'));
save(fullfile(file_path, 'motile_temporal_results.mat'), 'T_temporal_motile');

%fprintf('The autocorrelation calculation needs improvement');
% maxLag = size(autocorr_all,2)-1; 
% T_auto = array2table(autocorr_all, 'VariableNames', ...
%     arrayfun(@(x) sprintf('Lag%d',x), 0:maxLag, 'UniformOutput', false));
% T_auto.TRACK_ID = trackStats.TRACK_ID; 
% writetable(T_auto, fullfile(file_path, 'autocorrelazione_tracce.xlsx'));
close all;
% clear all;
