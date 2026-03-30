% === SCRIPT DI ANALISI COLLECTIVE MOTION ===
% close all;
% clear all;
% Directory principale
main_folder =['']; %insert main folder

% 0. Specifica se la luce è presente
hasLight = true; % <<--- METTI true se la luce c'è, false se NON c'è

% 1. CARICA IL FILE .MAT (modifica il nome se serve)
matFileName = fullfile(main_folder, 'converted_data.mat');   % <-- Cambia qui il nome del tuo file se diverso
dataStruct = load(matFileName);       % Carica la struttura dal .mat
converted_data = dataStruct.converted_data; % Assicurati che il campo si chiami così! cluster_k_data

if ~isempty(matFileName)
    file_path = fullfile(main_folder, 'Collective_global');
if ~exist(file_path, 'dir')
    mkdir(file_path);   % crea la cartella se non esiste
end
end

% 2. Parametri di classificazione (modificabili)
minDisplacement = 20;      % micron, soglia per "ferma"
minStraightness = 0.3;     % soglia per "direzionale"
lightDirection = [1 0];    % direzione della luce (esempio: verso destra)

% 3. Crea l'oggetto analizzatore (ora con flag hasLight)
analyzer = CollectiveMotionAnalyzer_udm_lightOnOff(converted_data, lightDirection, minDisplacement, minStraightness, hasLight);

% 4. Analizza l'evoluzione temporale (puoi cambiare la dimensione della finestra)
windowSize = 10;
results = analyzer.analyzeTemporalEvolution(windowSize);

% 5. Classifica le tracce (ferma, tondo, direzionale)
[trackStats, summaryStats] = analyzer.classifyTracks();
% Ottieni gli ID delle tracce motili
motile_ids = trackStats.TRACK_ID(strcmp(trackStats.Label, "tondo") | strcmp(trackStats.Label, "direzionale"));

% Calcola entrambe le evoluzioni temporali
[results, results_motili] = analyzer.analyzeTemporalEvolutionBoth(windowSize, motile_ids);

% 6. Clustering sulle direzionali (interattivo: puoi accettare o cambiare il numero di cluster)
clusterStats = analyzer.analyzeDirectionalClustersInteractive(summaryStats);
if ~isstruct(clusterStats) || isempty(clusterStats)
    clusterStats.nClusters = 0;
    clusterStats.summary = [];
end

% 7. Plot delle direzioni principali (frecce cluster) + movimento netto
analyzer.plotNetMovement(clusterStats);

% 8. Nuovi plot statistici sintetici (con errori)
analyzer.plotSummaryStats(trackStats, summaryStats, converted_data);

% (Opzionale: stampa le percentuali per info)
fprintf('Percentuale ferme: %.1f%%\n', summaryStats.percFerma);
fprintf('Percentuale in tondo: %.1f%%\n', summaryStats.percTondo);
fprintf('Percentuale direzionali: %.1f%%\n', summaryStats.percDirezionale);

% 9. Visualizzazione dei risultati temporali (frame o secondi)
%analyzer.plotResults(results);         % Frame sull'asse x
analyzer.plotResults(results, true);  % Secondi sull'asse x

% 10. (Opzionale) Plot rosa dei venti/angoli
startFrame = min(converted_data.FRAME_SOURCE);
endFrame = max(converted_data.FRAME_SOURCE);
analyzer.plotPhototaxisRose(startFrame, endFrame);

% 11. (Opzionale) Stampa report riassuntivo in console
analyzer.printResults();

% === CALCOLI AGGIUNTIVI E TABELLE ===

% Calcolo durata media e std tracce (in frame)
durate = zeros(height(trackStats),1);
for i = 1:height(trackStats)
    id = trackStats.TRACK_ID(i);
    frames = converted_data.FRAME_SOURCE(converted_data.TRACK_ID == id);
    if ~isempty(frames)
        durata_traccia = max(frames) - min(frames) + 1;
        durate(i) = durata_traccia;
    end
end
durata_media = mean(durate, 'omitnan');
durata_std = std(durate, 'omitnan');

% --- Nuovi calcoli statistici per tabella media ---
% -- Velocità
velocita = trackStats.MeanSpeed;
vel_media = mean(velocita, 'omitnan');
vel_mediana = median(velocita, 'omitnan');
vel_std = std(velocita, 'omitnan');
vel_sem = vel_std / sqrt(sum(~isnan(velocita)));

% -- Spostamento netto
spost_netto = trackStats.NetDisplacement;
spost_netto_media = mean(spost_netto, 'omitnan');
spost_netto_mediana = median(spost_netto, 'omitnan');
spost_netto_std = std(spost_netto, 'omitnan');
spost_netto_sem = spost_netto_std / sqrt(sum(~isnan(spost_netto)));

% -- Autocorrelazione media velocità (lag 1 come esempio riassuntivo)
maxLag = 10;
autocorr_all = nan(height(trackStats), maxLag+1);
for i = 1:height(trackStats)
    id = trackStats.TRACK_ID(i);
    speeds = converted_data.SPEED(converted_data.TRACK_ID==id);
    if numel(speeds) > maxLag
        ac = xcorr(speeds-mean(speeds,'omitnan'), maxLag, 'coeff');
        autocorr_all(i,:) = ac(maxLag+1:end); % solo lag positivi (incluso zero)
    end
end
mean_autocorr = nanmean(autocorr_all,1);
std_autocorr = nanstd(autocorr_all,0,1);
n_auto = sum(~isnan(autocorr_all),1);
sem_autocorr = std_autocorr ./ sqrt(n_auto);
ac_lag1 = mean_autocorr(2); % lag 1
ac_lag1_std = std_autocorr(2);
ac_lag1_sem = sem_autocorr(2);

% Parametri globali di movimento netto
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

% --------- Calcolo parametri rispetto alla luce solo se hasLight ---------
if hasLight
    ang_luce = rad2deg(abs(mean_angle - atan2(lightDirection(2), lightDirection(1))));
else
    ang_luce = NaN; % oppure 'NA' se preferisci testo
end
figure('Name','HistStraightness')
histogram(trackStats.Straightness, 20);
xlabel('Straightness');
ylabel('Number of Tracks');
title('Straightness distribution of the tracks');

% (opzionale) traccia una linea verticale sulla soglia attuale
hold on;
xline(minStraightness, 'r--', 'Straightness Treshold');
hold off;

% === TABELLE ===

% Tabella media
media_row = { ...
    matFileName, ...
    summaryStats.nTracks, summaryStats.nFerma, summaryStats.nTondo, summaryStats.nDirezionale, ...
    summaryStats.percFerma, summaryStats.percTondo, summaryStats.percDirezionale, ...
    durata_media, durata_std, ...
    vel_media, vel_mediana, vel_std, vel_sem, ...
    spost_netto_media, spost_netto_mediana, spost_netto_std, spost_netto_sem, ...
    ac_lag1, ac_lag1_std, ac_lag1_sem, ...
    norm(net_movement), rad2deg(mean_angle), err_mov_netto, ...
    mean_vector_length, rad2deg(circular_std), ...
    p_value, string(CollectiveMotionAnalyzer_udm_lightOnOff.conditional(is_significant, 'Significativa', 'Non significativa')), ...
    ang_luce, ... % <-- ora è NaN se la luce non c'è!
    clusterStats.nClusters ...
    };

media_varnames = { ...
    'FileName', ...
    'nTracks', 'nFerma', 'nTondo', 'nDirezionale', ...
    'percFerma [%]', 'percTondo [%]', 'percDirezionale [%]', ...
    'durata_media [frame]', 'durata_std [frame]', ...
    'vel_media [µm/s]', 'vel_mediana [µm/s]', 'vel_std [µm/s]', 'vel_sem [µm/s]', ...
    'spost_netto_media [µm]', 'spost_netto_mediana [µm]', 'spost_netto_std [µm]', 'spost_netto_sem [µm]', ...
    'autocorrLag1_media', 'autocorrLag1_std', 'autocorrLag1_sem', ...
    'mag_mov_netto [µm]', 'ang_mov_netto [°]', 'err_mov_netto [µm]', ...
    'forza_direzionale', 'dev_std_circolare [°]', ...
    'p_value', 'significativa', 'ang_luce [°]', 'nCluster'};

T_media = cell2table(media_row, 'VariableNames', media_varnames);

% Tabella per cluster
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
        cluster_rows{end,9} = cs.lightAlignment;
    else
        cluster_rows{end,9} = NaN; % oppure 'NA'
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

save(fullfile(file_path, 'risultati_video.mat'), 'T_media', 'T_cluster')
writetable(T_media, fullfile(file_path, 'risultati_media.xlsx'))
writetable(T_cluster, fullfile(file_path, 'risultati_cluster.xlsx'))
%% %% salvataggio figure
prompt = sprintf('Vuoi salvare le figure? [S/N]: ');
answer2 = input(prompt, 's');
if strcmpi(answer2, 's')
    names = { ...
        'PhototaxisAnalysis', ...
        'StatisticheTracce', ...
        'NetMovementAnalysis(Clusters)', ...
        'AnalisiMovimento', ...
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
% === FINE SCRIPT parte 1===

% --- Salva tabella delle tracce (trackStats) ---
writetable(trackStats,fullfile(file_path, 'tracce_stats.xlsx'));

% --- Salva tabella evoluzione temporale (results) ---
% Crea tabella da struttura results
% RISULTATI TUTTE LE TRACCE
T_temporali = table(results.windowFrames(:), results.windowTimes(:), ...
    results.meanSpeed(:), results.stdSpeed(:), ...
    results.displacement(:), results.stdDisplacement(:), ...
    results.directionalChange(:), results.stdDirectionalChange(:), ...
    results.lightAlignment(:), results.stdLightAlignment(:), ...
    results.nTracks(:), ...
    'VariableNames', {'Frame', 'Time_s', 'MeanSpeed', 'StdSpeed', ...
                      'MeanDisplacement', 'StdDisplacement', ...
                      'MeanDirectionalChange', 'StdDirectionalChange', ...
                      'MeanAlignment', 'StdAlignment', 'nTracks'});
writetable(T_temporali, fullfile(file_path,'risultati_temporali_tutte.xlsx'));
save(fullfile(file_path, 'risultati_temporali_tutte.mat'), 'T_temporali');

% RISULTATI SOLO MOTILI
T_temporali_motili = table(results_motili.windowFrames(:), results_motili.windowTimes(:), ...
    results_motili.meanSpeed(:), results_motili.stdSpeed(:), ...
    results_motili.displacement(:), results_motili.stdDisplacement(:), ...
    results_motili.directionalChange(:), results_motili.stdDirectionalChange(:), ...
    results_motili.lightAlignment(:), results_motili.stdLightAlignment(:), ...
    results_motili.nTracks(:), ...
    'VariableNames', {'Frame', 'Time_s', 'MeanSpeed', 'StdSpeed', ...
                      'MeanDisplacement', 'StdDisplacement', ...
                      'MeanDirectionalChange', 'StdDirectionalChange', ...
                      'MeanAlignment', 'StdAlignment', 'nTracks'});
writetable(T_temporali_motili, fullfile(file_path, 'risultati_temporali_motili.xlsx'));
save(fullfile(file_path, 'risultati_temporali_motili.mat'), 'T_temporali_motili');

% % --- Salva autocorrelazione delle tracce (se serve per grafico) ---
 fprintf('Al momento autocorrelazione non funziona');
% maxLag = size(autocorr_all,2)-1; % come nel tuo script
% T_auto = array2table(autocorr_all, 'VariableNames', ...
%     arrayfun(@(x) sprintf('Lag%d',x), 0:maxLag, 'UniformOutput', false));
% T_auto.TRACK_ID = trackStats.TRACK_ID; % aggiungi colonna identificativa
% writetable(T_auto, fullfile(file_path, 'autocorrelazione_tracce.xlsx'));
% === FINE SCRIPT parte 2===
close all;
clear all;
