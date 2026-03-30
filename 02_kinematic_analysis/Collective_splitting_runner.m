% === SCRIPT FILTRAGGIO ALGHE CON SALVATAGGIO IN .MAT === 
% === Imposta il percorso di lavoro e crea una cartella per salvare i risultati ===
% Imposta la cartella di lavoro (modifica con il percorso desiderato)
clear all;
close all;
% Directory principale
main_folder ='';
% Trova le cartelle "cntrl_Dark"
sample_folders = dir(fullfile(main_folder, 'sample_3*'));
sample_folders = sample_folders([sample_folders.isdir]); % solo directory


for i = 1:length(sample_folders)
    sample_path = fullfile(main_folder, sample_folders(i).name);

    % Trova le sottocartelle "cmp*"
    video_folders = dir(fullfile(sample_path, 'tracking*'));
    video_folders = video_folders([video_folders.isdir]); % solo directory

    for j = 1:length(video_folders)

        video_path = fullfile(sample_path, video_folders(j).name);

        % Crea una nuova cartella per i risultati
        resultsFolder = fullfile(video_path, 'Collective_splittingCluster');
        if ~isfolder(resultsFolder)
            mkdir(resultsFolder);
            fprintf('Cartella per i risultati creata: %s\n', resultsFolder);
        end
        
        % Carica file e prepara dati
        matFileName = fullfile(video_path, 'converted_data.mat'); % Combina percorso e file
        if ~isfile(matFileName)
            error('Il file %s non esiste nel percorso specificato.', matFileName);
        end
        
        dataStruct = load(matFileName);
        if ~isfield(dataStruct, 'converted_data')
            error('Il file %s non contiene il campo "converted_data".', matFileName);
        end
        disp('File caricato correttamente.');
        
        converted_data = dataStruct.converted_data;
        
        % Parametri di analisi
        lightDirection = [1 0];  % Direzione della luce (modifica se necessario)
        minDisplacement = 20;    % Soglia per "ferma"
        minStraightness = 0.3;   % Soglia per "direzionale"
        hasLight = true;         % Se è presente la luce nello studio
        nClusters = 2;           % Numero di cluster definito dal codice precedente
        
        % Inizializza la classe
        analyzer = CollectiveMotionAnalyzer_udm_lightOnOff(converted_data, lightDirection, minDisplacement, minStraightness, hasLight);
        disp('Oggetto analyzer creato correttamente.');
        
        % Classifica tracce
        [trackStats, summaryStats] = analyzer.classifyTracks();
        disp('Tracce classificate.');
        
        % Filtra tracce ferme, tonde e moventi
        stationary_ids = trackStats.TRACK_ID(strcmp(trackStats.Label, "ferma"));
        tondo_ids = trackStats.TRACK_ID(strcmp(trackStats.Label, "tondo"));
        motile_ids = trackStats.TRACK_ID(strcmp(trackStats.Label, "tondo") | strcmp(trackStats.Label, "direzionale"));
        
        % Crea le matrici per tracce ferme, tonde e motili
        stationary_data = converted_data(ismember(converted_data.TRACK_ID, stationary_ids), :);
        round_data = converted_data(ismember(converted_data.TRACK_ID, tondo_ids), :);
        motile_data = converted_data(ismember(converted_data.TRACK_ID, motile_ids), :);
        
        % Salvataggio dei dati fermi
        stationary_file = fullfile(resultsFolder, 'stationary_data.mat');
        save(stationary_file, 'stationary_data');
        disp('Dati fermi salvati in stationary_data.mat.');
        
        % Salvataggio dei dati rotondi
        round_file = fullfile(resultsFolder, 'round_data.mat');
        save(round_file, 'round_data');
        disp('Dati rotondi salvati in round_data.mat.');
        
        % Salvataggio dei dati motili
        motile_file = fullfile(resultsFolder, 'motile_data.mat');
        save(motile_file, 'motile_data');
        disp('Dati motili salvati in motile_data.mat.');
        
        disp('Dati filtrati:');
        fprintf('- Numero di tracce ferme: %d\n', numel(stationary_ids));
        fprintf('- Numero di tracce tonde: %d\n', numel(tondo_ids));
        fprintf('- Numero di tracce motili: %d\n', numel(motile_ids));
        
        % === Analisi tracce "direzionali" e clustering ===
        % Filtra le tracce della categoria "direzionale"
        directional_ids = trackStats.TRACK_ID(strcmp(trackStats.Label, "direzionale"));
        directional_data = motile_data(ismember(motile_data.TRACK_ID, directional_ids), :);
        
        % Esegui clustering con il numero definito manualmente di cluster
        clusterStats = analyzer.analyzeDirectionalClusters(summaryStats, nClusters);
        
        % Struct per contenere tutte le matrici dei cluster
        cluster_struct = struct();
        
        % Salva i dati per ogni cluster come matrici tipo converted_data
        for k = 1:nClusters
            % Filtra i dati del cluster corrente
            cluster_ids = directional_ids(clusterStats.labels == k);
            cluster_k_data = directional_data(ismember(directional_data.TRACK_ID, cluster_ids), :);
        
            % Salva la matrice tipo converted_data con un nome unico per ogni cluster
            cluster_file = fullfile(resultsFolder, sprintf('cluster_%d_data.mat', k)); % Nome univoco per ogni cluster
            save(cluster_file, 'cluster_k_data');
            fprintf('Dati del cluster %d salvati in %s\n', k, cluster_file);
        
            % Salva i dati in una struct per riassumere
            cluster_struct.(sprintf('Cluster_%d', k)) = cluster_k_data;
        end
        
        % Salva la struct con tutte le matrici dei cluster
        struct_file = fullfile(resultsFolder, 'cluster_struct_data.mat');
        save(struct_file, 'cluster_struct');
        disp(['Struct contenente tutte le matrici dei cluster salvata in: ' struct_file]);
        
        % Salvataggio completo
        disp('Filtraggio e clustering completati.');

    end
end

