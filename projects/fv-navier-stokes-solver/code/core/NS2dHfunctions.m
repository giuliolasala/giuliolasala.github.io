function [H1,H2] = NS2dHfunctions(n,dx,Re,u,v)
%% ************************************************************************
% NS2dHfunctions
%   Compute the discrete H1 and H2 terms appearing in the 2D incompressible
%   Navier-Stokes equations in nondimensional form.
%
%   Finite Volume Method on a uniform staggered Cartesian grid.
%   Central Differencing Scheme is used for both convective and diffusive
%   fluxes.
%
% Syntax:
%   [H1,H2] = NS2dHfunctions(n,dx,Re,u,v)
%
% Input:
%   n    : number of pressure control volumes in each spatial direction
%   dx   : uniform grid spacing
%   Re   : Reynolds number
%   u    : horizontal velocity array, size (n+2) x (n+1)
%   v    : vertical   velocity array, size (n+1) x (n+2)
%
% Output:
%   H1   : x-momentum H-function, size n x (n+1)
%   H2   : y-momentum H-function, size (n+1) x n
%
%   Author      : Giulio La Sala
%   Date        : Sunday 17/05/2025
%   Version     : Final
%**************************************************************************

%% Initialize output arrays
H1 = zeros(n,   n+1);
H2 = zeros(n+1, n);

%% H1 computation
% H1 is needed only for the internal u-control volumes, j = 2:n.
for i = 1:n

    iu = i + 1;

    for j = 2:n

        %% East and west faces
        ue    = 0.5 * (u(iu,j) + u(iu,j+1));
        dudxe = (u(iu,j+1) - u(iu,j)) / dx;

        uw    = 0.5 * (u(iu,j-1) + u(iu,j));
        dudxw = (u(iu,j) - u(iu,j-1)) / dx;

        %% North face
        if i < n
            un    = 0.5 * (u(iu,j) + u(iu+1,j));
            dudyn = (u(iu+1,j) - u(iu,j)) / dx;
            vn    = 0.5 * (v(i+1,j) + v(i+1,j+1));
        else
            un    = u(n+2,j);
            dudyn = 2.0 * (u(n+2,j) - u(iu,j)) / dx;
            vn    = 0.5 * (v(n+1,j) + v(n+1,j+1));
        end

        %% South face
        if i > 1
            us    = 0.5 * (u(iu-1,j) + u(iu,j));
            dudys = (u(iu,j) - u(iu-1,j)) / dx;
            vs    = 0.5 * (v(i,j) + v(i,j+1));
        else
            us    = u(1,j);
            dudys = 2.0 * (u(iu,j) - u(1,j)) / dx;
            vs    = 0.5 * (v(1,j) + v(1,j+1));
        end

        %% Assemble H1
        H1(i,j) = ...
            ( (1/Re)*dudxe - ue^2 - ((1/Re)*dudxw - uw^2) ) / dx + ...
            ( (1/Re)*dudyn - un*vn - ((1/Re)*dudys - us*vs) ) / dx;

    end
end

%% H2 computation
% H2 is needed only for the internal v-control volumes, i = 2:n.
for i = 2:n

    for j = 1:n

        jv = j + 1;

        %% East face
        if j < n
            ve    = 0.5 * (v(i,jv) + v(i,jv+1));
            dvdxe = (v(i,jv+1) - v(i,jv)) / dx;
            ue    = 0.5 * (u(i,j+1) + u(i+1,j+1));
        else
            ve    = v(i,n+2);
            dvdxe = 2.0 * (v(i,n+2) - v(i,jv)) / dx;
            ue    = 0.5 * (u(i,n+1) + u(i+1,n+1));
        end

        %% West face
        if j > 1
            vw    = 0.5 * (v(i,jv-1) + v(i,jv));
            dvdxw = (v(i,jv) - v(i,jv-1)) / dx;
            uw    = 0.5 * (u(i,j) + u(i+1,j));
        else
            vw    = v(i,1);
            dvdxw = 2.0 * (v(i,jv) - v(i,1)) / dx;
            uw    = 0.5 * (u(i,1) + u(i+1,1));
        end

        %% North and south faces
        vn    = 0.5 * (v(i,jv) + v(i+1,jv));
        dvdyn = (v(i+1,jv) - v(i,jv)) / dx;

        vs    = 0.5 * (v(i-1,jv) + v(i,jv));
        dvdys = (v(i,jv) - v(i-1,jv)) / dx;

        %% Assemble H2
        H2(i,j) = ...
            ( (1/Re)*dvdxe - ue*ve - ((1/Re)*dvdxw - uw*vw) ) / dx + ...
            ( (1/Re)*dvdyn - vn^2 - ((1/Re)*dvdys - vs^2) ) / dx;

    end
end

end