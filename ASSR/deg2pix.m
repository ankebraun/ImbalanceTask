function pix = deg2pix(options, ang)

% Converts visual angles in degrees to pixels.
%
% Inputs:
% display.dist (distance from screen (cm))
% display.width (width of screen (cm))
% display.res (number of pixels of display in horizontal direction)
% ang (visual angle)
% Warning: assumes isotropic (square) pixels
%
% Written 11/1/07 gmb zre
% Adapted by Anne Urai, August 2013


pixSize = options.width/options.resolution(1);   %cm/pix

sz = 2*options.dist*tan(pi*ang/(2*180));  %cm

pix = round(sz/pixSize);   %pix 

return

