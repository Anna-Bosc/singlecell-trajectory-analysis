function converted_edges = convertUnits(all_edges, fps, roiPixels)
    digits(6);
    
    converted_edges = all_edges;
    
    pixelToMicron = 10 / roiPixels;
    
    converted_edges.POSITION_T_SOURCE = converted_edges.FRAME_SOURCE / fps;
    converted_edges.POSITION_T_TARGET = converted_edges.FRAME_TARGET / fps;
    
    position_columns = {'POSITION_X_SOURCE', 'POSITION_Y_SOURCE', ...
                       'POSITION_X_TARGET', 'POSITION_Y_TARGET'};
    for i = 1:length(position_columns)
        converted_edges.(position_columns{i}) = converted_edges.(position_columns{i}) * pixelToMicron;
    end
    converted_edges.DISPLACEMENT = converted_edges.DISPLACEMENT * pixelToMicron;
    converted_edges.SPEED = converted_edges.SPEED * pixelToMicron * fps;
    converted_edges.DIRECTIONAL_CHANGE_RATE = converted_edges.DIRECTIONAL_CHANGE_RATE * fps;
    converted_edges.Properties.VariableUnits = {...
        '', '', '',... 
        'frame', 'seconds',... % FRAME_SOURCE, POSITION_T_SOURCE
        'µm', 'µm',... % POSITION_X_SOURCE, POSITION_Y_SOURCE
        'frame', 'seconds',... % FRAME_TARGET, POSITION_T_TARGET
        'µm', 'µm',... % POSITION_X_TARGET, POSITION_Y_TARGET
        'rad/s',... % DIRECTIONAL_CHANGE_RATE
        'µm',... % DISPLACEMENT
        'µm/s'... % SPEED
    };
end