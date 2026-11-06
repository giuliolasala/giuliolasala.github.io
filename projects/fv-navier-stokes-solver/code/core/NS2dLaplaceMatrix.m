function A = NS2dLaplaceMatrix(n)
%% ************************************************************************
% NS2dLaplaceMatrix
%
% Assembles the discrete 2D Laplacian operator for the pressure Poisson
% equation using a finite volume (FV) discretization on a structured,
% Cartesian, cell-centered grid with uniform square cells.
%
% The continuous problem reads: ∇²p = s
%
% The returned matrix A represents the discrete Laplacian operator scaled
% by dx^2, such that the linear system is: A * p(:) = s(:)
%
% where the right-hand side s already includes the factor dx^2 arising from
% the finite volume integration.
%
% -------------------------------------------------------------------------
% DISCRETIZATION DETAILS
% -------------------------------------------------------------------------
% - Spatial discretization: Finite Volume Method (FVM)
% - Grid: uniform Cartesian mesh, n × n control volumes
% - Scheme: central differencing (second-order accurate)
%
% For an internal control volume:
%       aW = aE = aS = aN = +1
%       aP = -(aW + aE + aS + aN) = -4
%
% The resulting operator corresponds to the standard 5-point stencil.
%
% -------------------------------------------------------------------------
% BOUNDARY CONDITIONS
% -------------------------------------------------------------------------
% Homogeneous Neumann boundary conditions are imposed on all boundaries: 
% ∂p/∂n = 0
%
% These are enforced via ghost-cell elimination, leading to a modification
% of the central coefficient for boundary-adjacent control volumes.
%
% -------------------------------------------------------------------------
% MATRIX PROPERTIES
% -------------------------------------------------------------------------
% - Sparse, symmetric matrix
% - Size: (n^2) × (n^2)
% - Rank deficiency: rank(A) = n^2 - 1
%
% -------------------------------------------------------------------------
% INDEXING CONVENTION
% -------------------------------------------------------------------------
% Unknowns are ordered using column-major indexing:
%       k = j + (i-1)*n
% where:
%       i = x-index
%       j = y-index
%
% -------------------------------------------------------------------------
% INPUT
%   n : number of control volumes in each spatial direction (n ≥ 2)
%
% OUTPUT
%   A : sparse Laplacian matrix of size (n^2) × (n^2)
%
%   Author      : Giulio La Sala
%   Date        : Sunday 17/05/2025
%   Version     : Final
% ************************************************************************

%% Input validation
validateattributes(n, {'numeric'}, {'scalar','integer','>=',2}, ...
    mfilename, 'n');

%% Step 1: Define internal coefficients (5-point stencil)
aW =  ones(n,n);      % west neighbor
aE =  ones(n,n);      % east neighbor
aS =  ones(n,n);      % south neighbor
aN =  ones(n,n);      % north neighbor
aP = -4 * ones(n,n);  % central coefficient

%% Step 2: Apply homogeneous Neumann boundary conditions
% Ghost-cell elimination:
% remove boundary flux contributions and compensate in aP

% West boundary
aP(:,1) = aP(:,1) + aW(:,1);
aW(:,1) = 0.0;

% East boundary
aP(:,n) = aP(:,n) + aE(:,n);
aE(:,n) = 0.0;

% South boundary
aP(1,:) = aP(1,:) + aS(1,:);
aS(1,:) = 0.0;

% North boundary
aP(n,:) = aP(n,:) + aN(n,:);
aN(n,:) = 0.0;

%% Step 3: Assemble sparse matrix using spdiags
Nunk = n^2;

% Convert coefficient matrices to vectors (column-major ordering)
aWv = aW(:);
aEv = aE(:);
aSv = aS(:);
aNv = aN(:);
aPv = aP(:);

% Remove non-physical wrap-around couplings
firstOfColumn = 1:n:Nunk;   % no south neighbor
lastOfColumn  = n:n:Nunk;   % no north neighbor

aSv(firstOfColumn) = 0.0;
aNv(lastOfColumn)  = 0.0;

% Construct diagonals for sparse matrix
diagW = [aWv(n+1:end); zeros(n,1)];   % offset -n
diagS = [aSv(2:end); 0];              % offset -1
diagP = aPv;                          % offset  0
diagN = [0; aNv(1:end-1)];            % offset +1
diagE = [zeros(n,1); aEv(1:end-n)];   % offset +n

% Assemble matrix
A = spdiags([diagW, diagS, diagP, diagN, diagE], ...
            [-n, -1, 0, 1, n], Nunk, Nunk);

end