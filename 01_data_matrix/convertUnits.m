% Author: Anna Bosc
% Affiliation: Istituto Italiano di Tecnologia
% Year: 2026
% Description: Part of the MATLAB pipeline for trajectory analysis of Chlamydomonas motility

function converted_edges = convertUnits(all_edges, fps, roiPixels)
    % Converte le unità di misura della tabella all_edges con precisione fissa a 5 cifre
    % Input:
    %   all_edges: tabella originale
    %   fps: frame rate (frames per second)
    %   roiPixels: numero di pixel che corrisponde a 10 micrometri
    
    % Imposta la precisione globale a 5 cifre significative
    digits(6);
    
    % Copia la tabella originale
    converted_edges = all_edges;
    
    % Calcola il fattore di conversione spaziale (micrometri/pixel)
    pixelToMicron = 10 / roiPixels;
    
    % Converti i tempi da frame a secondi
    converted_edges.POSITION_T_SOURCE = converted_edges.FRAME_SOURCE / fps;
    converted_edges.POSITION_T_TARGET = converted_edges.FRAME_TARGET / fps;
    
    % Converti le posizioni da pixel a micrometri
    position_columns = {'POSITION_X_SOURCE', 'POSITION_Y_SOURCE', ...
                       'POSITION_X_TARGET', 'POSITION_Y_TARGET'};
    for i = 1:length(position_columns)
        converted_edges.(position_columns{i}) = converted_edges.(position_columns{i}) * pixelToMicron;
    end
    
    % Converti DISPLACEMENT da pixel a micrometri
    converted_edges.DISPLACEMENT = converted_edges.DISPLACEMENT * pixelToMicron;
    
    % Converti SPEED da pixel/frame a micrometri/secondo
    converted_edges.SPEED = converted_edges.SPEED * pixelToMicron * fps;
    
    % Converti DIRECTIONAL_CHANGE_RATE da radianti/frame a radianti/secondo
    converted_edges.DIRECTIONAL_CHANGE_RATE = converted_edges.DIRECTIONAL_CHANGE_RATE * fps;
    
    % Aggiungi metadati alla tabella per tracciare le unità
    converted_edges.Properties.VariableUnits = {...
        '', '', '',... % prime tre colonne invariate
        'frame', 'seconds',... % FRAME_SOURCE, POSITION_T_SOURCE
        'µm', 'µm',... % POSITION_X_SOURCE, POSITION_Y_SOURCE
        'frame', 'seconds',... % FRAME_TARGET, POSITION_T_TARGET
        'µm', 'µm',... % POSITION_X_TARGET, POSITION_Y_TARGET
        'rad/s',... % DIRECTIONAL_CHANGE_RATE
        'µm',... % DISPLACEMENT
        'µm/s'... % SPEED
    };
end