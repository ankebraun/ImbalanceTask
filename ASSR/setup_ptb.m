AssertOpenGL;
KbName('UnifyKeyNames');

%PsychDefaultSetup(2);
timings = {};
screenNumber = 1; %min(Screen('Screens'));
white = WhiteIndex(screenNumber);
black = BlackIndex(screenNumber);
grey = white / 2;
% Open the screen

% skip PTB checks

% Screen('Preference', 'Verbosity', 0);
% Screen('Preference', 'SkipSyncTests', 1);
% Screen('Preference', 'VisualDebugLevel', 0);
% % suppress warnings to the pput window
% Screen('Preference', 'SuppressAllWarnings', 1);

Screen('Preference', 'SkipSyncTests', 1);
PsychImaging('PrepareConfiguration');
PsychImaging('AddTask', 'General', 'UseRetinaResolution');
%Screen('Preference', 'SkipSyncTests', 0);

[window, windowRect] = Screen('OpenWindow', screenNumber, grey);


%[window, windowRect] = Screen('OpenWindow', screenNumber, grey, [0, 0, 1000, 800]);
options.window_rect = windowRect;
% Switch color specification to use the 0.0 - 1.0 range instead of the 0 -
% 255 range. This is more natural for these kind of stimuli:
Screen('ColorRange', window, 1);

% You definetly want to set a custom look up table.
% gamma is the look up table
% we have to collect a new table for the gamma correction of the screen in
% Berlin

%load projector_calib_20151111.mat
%load('inverseCLUT.mat')
% if exist('gammaTables1', 'var') == 0 && length(gammaTables1) == 256
%     throw(MException('EXP:Quit', 'variable gamma not in workspace; no gamma lut loaded'));
% end
%old_gamma_table = Screen('LoadNormalizedGammaTable', window, gammaTables1);
load inverseCLUT; %Load the results of GenerateInverseClutFromGamma.m
originalCLUT = Screen('LoadNormalizedGammaTable',window,inverseCLUT);


% Set the display parameters 'frameRate' and 'resolution'
options.frameDur     = Screen('GetFlipInterval',window); %duration of one frame
options.frameRate    = 1/options.frameDur; %Hz

HideCursor(screenNumber)
Screen('Flip', window);


%% Set up Eye Tracker
if setup.Eye
    options.et = 'yes';
    [el, options] = ELconfig(window, setup.participant, options, screenNumber);

    % Calibrate the eye tracker
    EyelinkDoTrackerSetup(el);
end

% Make ringtexture
ringtex = make_circular_grating(window, options.ringwidth);
% make Kb Queue: Need to specify the device to query button box
% Find the keyboard + EEG buttons.
%[idx, names, all] = GetKeyboardIndices();
%options.kbqdev = [idx(strcmpi(names, 'ATEN USB KVMP w. OSD')), idx(strcmpi(names, 'Current Designs, Inc. 932')),...
%    idx(strcmpi(names, 'Apple Internal Keyboard / Trackpad')), idx(strcmpi(names, 'Virtual core XTE...')), idx(strcmpi(names, 'DELL Dell USB En...'))];

[idx, names, all] = GetKeyboardIndices();
options.kbqdev =idx;
kbqdev=idx; 

keyList = zeros(1, 256);
keyList(KbName({'ESCAPE','SPACE', 'LeftArrow', 'RightArrow',...
    '1', '2', '3', '4', 'b', 'g', 'y', 'r', '1!', '2@', '3#', '4$', '0', 'm', 'z', 'y', 'x', 'n'})) = 1; % only listen to those keys!
% first four are the buttons in mode 001, escape and space are for
% the experimenter, rest is for testing
for kbqdev = options.kbqdev
    PsychHID('KbQueueCreate', kbqdev, keyList);
    PsychHID('KbQueueStart', kbqdev);
    WaitSecs(.1);
    PsychHID('KbQueueFlush', kbqdev);
end

% %% now the audio setup
% InitializePsychSound(1);
% devices = PsychPortAudio('GetDevices');
% PsychPortAudio('Verbosity', 10);
% % UA-25 is the sound that's played in the subject's earbuds
% for i = 1:length(devices)
%     if strcmp(devices(i).DeviceName,'Ausgang (integriert)') %UA-25: USB Audio (hw:1,0)')
% %    if strcmp(devices(i).DeviceName,'EDIROL UA-25: USB Audio (hw:1,0)') %UA-25: USB Audio (hw:1,0)')
%         break
%     end
% end
% devices(i)
% % check that we found the low-latency audio port
% %assert(numel(strfind(devices(i).DeviceName, 'UA-25')) > 0, 'could not detect the right audio port! aborting')
% audio = [];
% 
% %i = 10; % for the EEG lab
% audio.i = devices(i).DeviceIndex;
% audio.freq = devices(i).DefaultSampleRate;
% audio.device = devices(i);
% audio.h = PsychPortAudio('Open',audio.i,1,1,audio.freq,2);
% PsychPortAudio('RunMode',audio.h,1);


% Initialize audio structure
audio           = [];

% Initial setup
InitializePsychSound;%(1);  % request low latency mode

audio.freq      = 44100;
audio.h         = PsychPortAudio('Open', [], 1, [], [], 2, [], []);  % open default soundport, in stereo (to match the sound matrix we create)
%audio.h         = PsychPortAudio('Open', [], 1, [], audio.freq, 2, [], []);  % open default soundport, in stereo (to match the sound matrix we create)
PsychPortAudio('RunMode',audio.h,1);
% Maximum priority level
topPriorityLevel = MaxPriority(window);
