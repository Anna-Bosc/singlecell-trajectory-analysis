% Author: Anna Bosc
% Affiliation: Istituto Italiano di Tecnologia
% Year: 2026
% Description: Part of the MATLAB pipeline for trajectory analysis of Chlamydomonas motility

clear all;
close all;
% Main directory
main_folder =''; %inserte main path
% Find sample folders
sample_folders = dir(fullfile(main_folder, '*')); %insert name
sample_folders = sample_folders([sample_folders.isdir]);


for i = 1:length(sample_folders)
    sample_path = fullfile(main_folder, sample_folders(i).name);

    % Find tracking subfolders
    video_folders = dir(fullfile(sample_path, '*')); %inserte name
    video_folders = video_folders([video_folders.isdir]);

    for j = 1:length(video_folders)

        video_path = fullfile(sample_path, video_folders(j).name);

        resultsFolder = fullfile(video_path, 'Collective_splittingCluster');
        if ~isfolder(resultsFolder)
            mkdir(resultsFolder);
            fprintf('Results folder generated: %s\n', resultsFolder);
        end
        
        matFileName = fullfile(video_path, 'converted_data.mat');
        if ~isfile(matFileName)
            error('The file %s does not exist in the specified path.', matFileName);
        end
        
        dataStruct = load(matFileName);
        if ~isfield(dataStruct, 'converted_data')
            error('The file %s does not contains the “converted_data” field.', matFileName);
        end
        disp('File uploaded successfully.');
        
        converted_data = dataStruct.converted_data;
        
        % analysis parameters
        lightDirection = [1 0];  % light direction
        minDisplacement = 20;    % µm, threshold for stationary
        minStraightness = 0.3;   % threshold for directional
        hasLight = true;         % true if light is present
        nClusters = 2;           % number of clusters (from prior analysis)
        
        analyzer = CollectiveMotionAnalyzer_udm_lightOnOff(converted_data, lightDirection, minDisplacement, minStraightness, hasLight);
        disp('Object analyzer created successfully.');
        
        [trackStats, summaryStats] = analyzer.classifyTracks();
        disp('Tracks classified.');
        
        % Filter tracks by type
        stationary_ids = trackStats.TRACK_ID(strcmp(trackStats.Label, "Stationary"));
        Circling_ids = trackStats.TRACK_ID(strcmp(trackStats.Label, "Circling"));
        motile_ids = trackStats.TRACK_ID(strcmp(trackStats.Label, "Circling") | strcmp(trackStats.Label, "Directional"));
        
        stationary_data = converted_data(ismember(converted_data.TRACK_ID, stationary_ids), :);
        round_data = converted_data(ismember(converted_data.TRACK_ID, Circling_ids), :);
        motile_data = converted_data(ismember(converted_data.TRACK_ID, motile_ids), :);
        
        stationary_file = fullfile(resultsFolder, 'stationary_data.mat');
        save(stationary_file, 'stationary_data');
        disp('Stationary data are saved in stationary_data.mat.');
        
        round_file = fullfile(resultsFolder, 'round_data.mat');
        save(round_file, 'round_data');
        disp('Circling data are saved in round_data.mat.');
        
        motile_file = fullfile(resultsFolder, 'motile_data.mat');
        save(motile_file, 'motile_data');
        disp('Motile data are saved in motile_data.mat.');
        
        disp('Filtered data:');
        fprintf('- Number of tracks Stationary: %d\n', numel(stationary_ids));
        fprintf('- Number of tracks Circling: %d\n', numel(Circling_ids));
        fprintf('- Number of tracks Motile: %d\n', numel(motile_ids));
        
        % === Directional track analysis and clustering ===
        directional_ids = trackStats.TRACK_ID(strcmp(trackStats.Label, "Directional"));
        directional_data = motile_data(ismember(motile_data.TRACK_ID, directional_ids), :);
        
        clusterStats = analyzer.analyzeDirectionalClusters(summaryStats, nClusters);
        
        cluster_struct = struct();
        
        for k = 1:nClusters
            cluster_ids = directional_ids(clusterStats.labels == k);
            cluster_k_data = directional_data(ismember(directional_data.TRACK_ID, cluster_ids), :);
        
            cluster_file = fullfile(resultsFolder, sprintf('cluster_%d_data.mat', k));
            save(cluster_file, 'cluster_k_data');
            fprintf('Data of cluster %d are saved in %s\n', k, cluster_file);
        
            cluster_struct.(sprintf('Cluster_%d', k)) = cluster_k_data;
        end
        
        struct_file = fullfile(resultsFolder, 'cluster_struct_data.mat');
        save(struct_file, 'cluster_struct');
        disp(['A struct containing all the cluster matrixes saved in: ' struct_file]);
        
        disp('Filtering and clustering completed.');

    end
end

