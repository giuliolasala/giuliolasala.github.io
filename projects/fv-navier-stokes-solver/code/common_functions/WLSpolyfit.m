function p = WLSpolyfit(x,y,n,w)
%% *****************************************************************************
% WLSpolyfit:
%   Finds coefficients p of a polynomial p(x) of degree n that fit the data y
%   best in a weighted-least-squares sense, thus being alternative to matlab's
%   polyfit. Improves the conditioning of the problem by centering x to zero 
%   mean and scaling x to max unit max. point spacing, which polyfit doesn't do.
%   p is a row vector of length n+1 containing the polynomial coefficients 
%   in descending powers, i.e. p(1)*x^n + p(2)*x^(n-1) + ... + p(n)*x + p(n+1).
%   The function takes a vector of weight factors as an optional argument.
%
% Syntax:
%   p = WLSpolyfit(x,y,n)
%
% Input    :
%   x      :  vector of grid points
%   y      :  vector of polynomial values, evaluated in points, ordered as in x
%   n      :  polynomial degree of fitting polynomial
%   w      :  vector with weight factors for the grid points in x (optional)
%
% Output   :
%   p      :  row vector of polynomial coefficients in descending powers
%
% Author  : HBB/TOBC
% Date    : August 31, 2011
% Version : 1.0
%*******************************************************************************

%% Initialize
% Default input, if not given
if nargin < 4                 % no weight factor vector given
    w = ones(1,length(x));    % weight factors all unity
else                          % weight factor vector given as input   
    w = abs(w)/norm(w,inf);   % ensure positive, scale to max(w)=1
end
% Input vectors
x     = x(:);                 % ensure column format
y     = y(:);                 % ensure column format
nx    = length(x);            % number of points in x
ny    = length(y);            % number of points in y
nw    = length(w);            % number of weight coeff.
dx    = diff(sort(x));        % differences between values in x, sorted ascend.
dxmin = min(dx);              % minimum difference
dxmax = max(dx);              % maximum difference
xmean = sum(x)/nx;            % compute mean of x
xmod  = (x-xmean)/dxmax;      % shift x to mean(x)=0 and scale to max(diff(x))=1
% Arrays
M     = xmod(:,ones(1,n+1)).^(ones(nx,1)*(0:n));  % coeff. matrix, M_ij = x_i^j
W     = diag(w);              % diagonal weight factor matrix

%% Check for input problems
if dxmin/max(x) < 1e1*eps && dxmin/dxmax < 1e1*eps % x-points coincide
    warning(0,'Two or more values of x appear to coincide')
end
if n >= nx  % requested polynomial order exceed number of points in x
    warning(0,'Order of polynomial exceed - or is equal to - number of points')
end
if nx ~= ny || nx ~= nw || nw ~= ny % vectors x, y, w have different lengths
    error('Vectors x, y, w must have identical number of elements');
end
if sum(w~=0) <= n  % not sufficients weighted points for n'th order poly.
    error('Too many weight coefficients equal to zero to fit degree n poly.');
end

%% Solve Least-Square-Residual Problem for poly. coeff.
p = (M'*(W*M))\M'*(W*y);      % solve full order least-square-problem (LSP)
p(n+1) = p(n+1)/dxmax^n;      % scale highest coeff. with dxman^-n - now correct
for i = n:-1:1                % loop backwards over lower order coeff.
    y = y - x.^i*p(i+1);      % subtract current highest order term from rhs.
    M = M(:,1:i);             % remove previously highest order column from M
    cond(M'*M)
    p(1:i) = (M'*(W*M))\M'*(W*y); % solve reduced LSP for new coeff.
    p(i) = p(i)/dxmax^(i-1);  % scale current highest order coeff. with dxmax^-i
end

%% Flip and row vector p
p = fliplr(p');               % flip p to have same format as polyfit