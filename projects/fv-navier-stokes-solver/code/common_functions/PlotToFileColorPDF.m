function PlotToFileColorPDF(gcf,filename,x,y)
%
% Print the current plot at size (x,y) to an eps file
%
set(gcf,'PaperUnits','centimeters')
set(gcf,'PaperSize',[x,y])
set(gcf,'PaperPositionMode','manual')
set(gcf,'PaperPosition',[0,0,x,y]);
set(gcf, 'renderer', 'painters');
print('-dpdf',filename)

% function PlotToFileColorPDF(fig,filename,x,y)
% %
% % Export figure fig at size (x,y) to a pdf file
% %
% set(fig,'Units','centimeters')
% pos = get(fig,'Position');
% pos(3) = x;
% pos(4) = y;
% set(fig,'Position',pos)
% 
% set(fig,'Color','w')
% set(fig,'InvertHardcopy','off')
% 
% drawnow
% exportgraphics(fig,[filename '.pdf'],'ContentType','vector','Resolution',300)
