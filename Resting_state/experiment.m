%% Imbalance assr task
%
% Runs five minutes of resting state. 
%
sca; close all; clearvars; clear all; clc; dbstop if error;
addpath ppWrite;
global IO_LIB;
%IO_LIB = 'C:\ERANET\Resting_state\ppWrite\inpoutx64.dll';
IO_LIB = 'C:\Imbalance\Resting_state\ppWrite\inpoutx64.dll';

% Close audio device, shutdown driver:
% PsychPortAudio('Close');
%% Global parameters.
setup; % load various setup parameters
setup.do_trigger = true;% set to true if scanning in the EEG lab to send triggers
setup.Eye = true; % set to true if using Eyelink
if setup.do_trigger
    addpath matlabtrigger/
else
   addpath faketrigger/
end

%% Setup the ParPort
trigger_enc = setup_trigger;
%setup_parport;

%% Ask for some subject details
%-------------
% Ask for subject number, default = 100
%-------------
setup.participant       = input('Participant number? ');
if isempty(setup.participant)
    setup.participant   = 100; %test
end
%-------------
% Ask for session number, default = 1
%-------------
setup.session           = input('Session? ');
if isempty(setup.session)
    setup.session       = 1; %test
end
%-------------
% Ask for run number, default = 1
%-------------
setup.run               = input('Run? ');
if isempty(setup.run)
    setup.run           = 1; 
end    
	
if strcmp(input('Instructions in german? [y/n] ', 's'), 'y')
    setup.german   = true; 
else 
    setup.german   = false; 
end	

session_identifier =  datestr(now, 30);
%    setup.datetime_day = datestr(now, 'yyyy-mm-dd');


options.datadir = 'resting_state_data/';
options.datadir = fullfile(options.datadir, sprintf('%s_rs', num2str(setup.participant))); %fullfile(options.datadir, num2str(setup.participant));
[~, ~, ~] = mkdir(options.datadir);


setup_ptb;
[tw, th] = Screen('WindowSize', window);
%-------------
% Present instructions on the screen
%-------------
white = WhiteIndex(screenNumber);
if setup.german,
    line1 = 'Schauen Sie immer auf das Fixierungskreuz! \n  \n';      
    line2 = 'Drücken Sie eine Taste, um zu beginnen.';
    DrawFormattedText(window, [line1 line2],...
        'center', 'center', white);
    Screen('Flip', window);
    % Wait for key press
    WaitSecs(.1); KbWait(); WaitSecs(.1);
else
    line1 = 'Always fixate the cross! \n  \n';
    line2 = 'Press any button to start.';
    DrawFormattedText(window, [line1 line2],...
        'center', 'center', white);
    Screen('Flip', window);
    % Wait for key press
    WaitSecs(.1); KbWait(); WaitSecs(.1);
end	

% start recording eye position
if setup.Eye,
    Eyelink('StartRecording');
    % record a few samples before we actually start displaying
    WaitSecs(0.1);
    % mark zero-plot time in data file
    Eyelink('message', 'Start recording Eyelink');
end

if setup.Eye
    Eyelink ('Message', sprintf('block %i started at %d trigger None', setup.run, GetSecs));
end
ppWrite(888,trigger_enc.block_start);      
%trigger(trigger_enc.block_start);

red = [1; 0; 0];

%% Baseline Delay period

% Draw the fixation point
fix.color = red; % get ready
window = drawFixation(window, windowRect, fix); % fixation
Screen('DrawingFinished', window); % helps with managing the flip performance
vbl = Screen('Flip', window);
waitframes = 1;
stimulus_onset = nan;
ifi = Screen('GetFlipInterval', window);
framenum = 1;
start = nan;
while ~((GetSecs - stimulus_onset) >= (300))
    % Draw the fixation point
    fix.color = red; % get ready
    window = drawFixation(window, windowRect, fix); % fixation
    Screen('DrawingFinished', window); % helps with managing the flip performance
    % Flip our drawing to the screen
    vbl = Screen('Flip', window, vbl + (waitframes-.5) * ifi);
%    flush_kbqueues(kbqdev);
    if framenum == 1
        if setup.Eye
            % This supplies the title at the bottom of the eyetracker display
                % This supplies the title at the bottom of the eyetracker display
            Eyelink('command', 'record_status_message "TRIAL %d/%d"', 1, 1);
            Eyelink('message', 'TRIALID %d', 1);            
         %   Eyelink('command', 'record_status_message');
            Eyelink('message', 'SYNCTIME');
            Eyelink('message', 'stim_onset 1');           
        end
        %trigger(trigger_enc.stim_onset);
        ppWrite(888,trigger_enc.stim_onset);
        WaitSecs(0.001);
    end
    framenum = framenum +1;
    waitframes = 1;
    if isnan(start)
        stimulus_onset = GetSecs;
        %trigger(trigger_enc.con_change);
   %     ppWrite(888,trigger_enc.con_change)
        start = GetSecs;
    end
end
if setup.Eye,
    Eyelink('message', 'TRIALEND %d', 1);
end
if setup.Eye,
    Eyelink('message', 'Blockend');
end
ppWrite(888,trigger_enc.block_end);    
% catch ME
%     if (strcmp(ME.identifier,'EXP:Quit'))
%         return
%     else
%         disp(getReport(ME,'extended'));
%         if setup.Eye,
%             Eyelink('StopRecording');    
%         end
%         Screen('LoadNormalizedGammaTable', window, old_gamma_table);
% 
%         rethrow(ME);
%     end
% end
if setup.Eye,
    Eyelink('StopRecording');        
end
LoadIdentityClut(window);
Screen('LoadNormalizedGammaTable',window,repmat(linspace(0,1, 256)',1,3));
PsychPortAudio('Close');
sca
if setup.Eye
    eyefilename   = fullfile(options.datadir, sprintf('%s_%s.edf', num2str(setup.participant), num2str(session_identifier)));
    Eyelink('CloseFile');
    Eyelink('WaitForModeReady', 500);
    try
        status = Eyelink('ReceiveFile', options.edfFile, eyefilename);
        disp(['File ' eyefilename ' saved to disk']);
    catch
        warning(['File ' eyefilename ' not saved to disk']);
    end

    Eyelink('StopRecording');
end


