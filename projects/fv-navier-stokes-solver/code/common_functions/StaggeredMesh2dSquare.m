function [dx,Xu,Yu,Xv,Yv,Xp,Yp,Xi,Yi] = StaggeredMesh2dSquare(n)
%% *****************************************************************************
% File: StaggeredMesh2dSquare.m
%   Function for assembling coordinate arrays for a staggered mesh on a 2D square
%   
% Syntax:
%   [dx,Xu,Yu,Xv,Yv,Xp,Yp,Xi,Yi] = StaggeredMesh2dSquare(n)
%
% Input        :
%   n          :  Number of cells along x,y-axis
%
% Output       :
%   dx         :  Cell size in x,y
%   Xu,Yu      :  Coord. arrays for u-grid,  Xu(1:n+2,1:n+1),  Yu(1:n+2,1:n+1)
%   Xv,Yv      :  Coord. arrays for v-grid,  Xv(1:n+1,1:n+2),  Yv(1:n+1,1:n+2)
%   Xp,Yp      :  Coord. arrays for p-grid,  Xp(1:n,1:n),      Yp(1:n,1:n)
%   Xi,Yi,     :  Coord. arrays for fd-grid, Xi(1:n+1,1:n+1),  Yi(1:n+1,1:n+1)
%   Plot of mesh arrangment for n < 12
%
% Author  : HBB/TOBC
% Date    : September 31, 2011
% Version : 1.0
%*******************************************************************************

%% Assemble mesh coordinate arrays
dx      = 1/n;                  % cell size in x,y
xf      = 0:dx:1;               % cell face coordinate vector, 1D
xc      = dx/2:dx:1-dx/2;       % cell center coordinate vector, 1D
xb      = [0 xc 1];             % cell center coordinate vector incl. boundaries
[Xu,Yu] = meshgrid(xf,xb);      % u-grid coordinate arrays
[Xv,Yv] = meshgrid(xb,xf);      % v-grid coordinate arrays
[Xp,Yp] = meshgrid(xc,xc);      % p-grid coordinate arrays
[Xi,Yi] = meshgrid(xf,xf);      % fd-grid coordinate arrays

%% Plot mesh arrangement
% if n < 12                       % plot mesh if fewer than 12 cells in x,y 
%     figure(117)
%     clf
%     plot(Xi,Yi,'k--',Yi,Xi,'k--',Xu,Yu,'b>',Xv,Yv,'r^',Xp,Yp,'go',Xi,Yi,'y*')
%     axis('equal','tight',[0 1 0 1])
%     xlabel('x'),ylabel('y'),title('Illustration of u-, v-, p- and fd-grid')   
%     %print('-f117','-depsc2',sprintf('StaggeredGrid_n%i.eps',n))
% end