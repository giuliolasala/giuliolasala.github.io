function y = MYpolyval(p,x)
%% *****************************************************************************
% MYpolyval:
%   Returns the value of a polynomial p(x) evaluated at x, thus being a boiled 
%   down version of matlab's polyval. p is a vector of length n+1 whose elements 
%   are the coefficients of the polynomial in descending powers, i.e.
%     p(1)*x^n + p(2)*x^(n-1) + ... + p(n)*x + p(n+1)
%
% Syntax:
%   y = MYpolyval(p,x)
%
% Input    :
%   p      :  row vector of polynomial coefficients in descending powers
%   x      :  vector of grid points
%
% Output   :
%   y      :  vector of polynomial values, evaluated in points, ordered as in x
%
% Author  : HBB/TOBC
% Date    : August 31, 2011
% Version : 1.0
%*******************************************************************************

%% Initialize
n = length(p);               % order of polynomial 
y = zeros(size(x));          % initialize polynomial array

%% Compute polynomial values using Horner's method
y(:) = p(1);                 % initialize y with p(1) - highest order coeff.
for i=2:n                    % loop over remaining coeff. in p
    y = x .* y + p(i);       % multiply y with x and add next poly. coeff.
end