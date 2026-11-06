function s = NS2dBuildPoissonRHS(n,dx,H1,H2)
%% ************************************************************************
% NS2dBuildPoissonRHS
%
% Builds the discrete right-hand side of the 2D pressure Poisson equation
% for the incompressible Navier-Stokes solver on a staggered Cartesian grid.
%
% The continuous pressure equation is:
%
%       ∇²p = ∂H1/∂x + ∂H2/∂y
%
% where:
%   - H1 is defined at the u-grid control-volume centers
%   - H2 is defined at the v-grid control-volume centers
%
% The pressure Laplacian matrix assembled by NS2dLaplaceMatrix is scaled by
% dx^2. Therefore, the discrete linear system is written as:
%
%       A * p(:) = s(:)
%
% where the right-hand side s already includes the factor dx^2 resulting
% from the finite-volume integration of the source term.
%
% -------------------------------------------------------------------------
% DISCRETE FORM
% -------------------------------------------------------------------------
% Integrating the Poisson equation over a pressure control volume gives:
%
%   [ (∂p/∂x)_e - (∂p/∂x)_w ] * dx
% + [ (∂p/∂y)_n - (∂p/∂y)_s ] * dx
% = [ H1_e - H1_w ] * dx + [ H2_n - H2_s ] * dx
%
% Since the Laplacian matrix is scaled by dx^2, the discrete source term is:
%
%   s(i,j) = dx * [ H1(i,j+1) - H1(i,j) + H2(i+1,j) - H2(i,j) ]
%
% -------------------------------------------------------------------------
% GRID ARRANGEMENT
% -------------------------------------------------------------------------
% Pressure field:
%   p   -> size (n, n)
%
% Momentum source terms:
%   H1  -> size (n, n+1)
%   H2  -> size (n+1, n)
%
% Thus:
%   - H1(:,j)   and H1(:,j+1) represent west/east face values
%   - H2(i,:)   and H2(i+1,:) represent south/north face values
%
% -------------------------------------------------------------------------
% INPUT
%   n    : number of pressure control volumes in each spatial direction
%   dx   : uniform grid spacing
%   H1   : discrete H1 field on the u-grid, size (n, n+1)
%   H2   : discrete H2 field on the v-grid, size (n+1, n)
%
% OUTPUT
%   s    : discrete Poisson right-hand side on the pressure grid, size (n, n)
%
%   Author      : Giulio La Sala
%   Date        : Sunday 17/05/2025
%   Version     : Final
% *************************************************************************

%% Input validation
validateattributes(n,  {'numeric'}, {'scalar','integer','>=',2}, ...
    mfilename, 'n');
validateattributes(dx, {'numeric'}, {'scalar','real','positive'}, ...
    mfilename, 'dx');

if ~isequal(size(H1), [n, n+1])
    error('H1 must have size (n, n+1).');
end

if ~isequal(size(H2), [n+1, n])
    error('H2 must have size (n+1, n).');
end

%% Assemble discrete right-hand side
% Compute the finite-volume divergence of H = [H1, H2] on the pressure grid.
s = dx * ( ...
      H1(:,2:n+1) - H1(:,1:n) ...
    + H2(2:n+1,:) - H2(1:n,:) );

end