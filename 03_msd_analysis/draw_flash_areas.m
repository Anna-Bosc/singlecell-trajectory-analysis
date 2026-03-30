function draw_flash_areas(intervals, varargin)
    yl = ylim;
    for i = 1:size(intervals,1)
        % Banda verticale trasparente
        fill([intervals(i,1), intervals(i,2), intervals(i,2), intervals(i,1)], ...
             [yl(1), yl(1), yl(2), yl(2)], ...
              [1 0.3 0.3], 'EdgeColor','none', 'FaceAlpha',0.3, varargin{:});
        % Linee ai bordi
        xline(intervals(i,1), 'r--', 'LineWidth', 1.2);
        xline(intervals(i,2), 'r--', 'LineWidth', 1.2);
    end
    ylim(yl); % ripristina i limiti Y
end