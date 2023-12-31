% Setup various options

options.num_trials = 100; %56; % How many trials?

window = false;

screenNumber = min(Screen('Screens'));
options.dist = 62; %65; %75; % viewing distance in cm 
[width, height] = Screen('DisplaySize', screenNumber);
options.width = width/10;
options.height = height/10;
% options.width = 52; %38; % physical width of the screen in cm, 38 for MEG projector -> but better check on a regular basis
% options.height = 29.5; %29; % physical height of the screen in cm, 29 for the MEG projector screen inside the scanner
% options.theight = 29.5; %29; % Size of the not-cropped image

% If I set the projector to zoom and use a 1920x1080 resolution on the
% stimulus PC I get a nice display -> The image is ten roughly 1450x1080
%options.resolution = [1450, 1080];
% options.wdiff = (1920-options.resolution(1)) /2; this variable is not
% used
Res = Screen('Resolution', screenNumber);
options.resolution = [Res.width, Res.height];

options.ppd = estimate_pixels_per_degree(options);
% Parameters for sampling the contrast + contrast noise
options.baseline_contrast = 0.5;
options.noise_sigmas = .15; %[.05 .1 .15];
%options.nsreverse = containers.Map(options.noise_sigmas, [1,2,3]);

scaling_factor = 37.1356/options.ppd;
options.ringwidth = options.ppd*3/4;%deg2pix(options, 0.75)*scaling_factor;%
options.inner_annulus = 0; 
options.sigma = 75;
options.cutoff = 3.8; %5.5; %4.2;
%options.radius = factor_radius*options.ppd*scaling_factor; %*(options.width/56.4)/(options.resolution(1)/1600); %4*options.ppd;
options.radius = 3*options.ppd; %deg2pix(options, 1.3)*scaling_factor; %deg2pix(options, 1.3)*scaling_factor;%4*options.ppd;
%eff_radius = (options.radius + options.cutoff * options.sigma) should be
%smaller than tw/4

% options.ringwidth = options.ppd*3/8;
% options.inner_annulus = 0;%1.5*options.ppd;
% options.radius = 2*options.ppd;
% options.sigma = 75;
% options.cutoff = 5.5;

% Should we repeat contrast levels? 1 = yes, 0 = no
options.repeat_contrast_levels = 0;


% QUEST Parameters
quest.pThreshold = .75; % Performance level and other QUEST parameters
quest.beta = 3.5;
quest.delta = 0.5/128;
quest.gamma = 0.15;
quest.threshold_guess = 0.025;
quest.threshold_guess_sigma = 0.25;

% Load marked feedback beeps
options.beeps = {repmat(audioread('toneFc1000_Fm40_Fs48kHz_dur2s.wav'), 1,1)', repmat(audioread('toneFc1000_Fm0_Fs48kHz_dur2s.wav'), 1,1)'};


