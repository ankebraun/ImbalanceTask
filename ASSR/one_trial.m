function [correct, response, rt_choice, timing] = one_trial(setup, window, windowRect, screen_number, tone, pahandle, trigger_enc, beeps, ppd, variable_arguments)
%% function [correct, response, confidence, rt_choice, rt_conf] = one_trial(window, windowRect, screen_number, correct_location, gabortex, gaborDimPix, pahandle, variable_arguments)
%
% Presents two circular contracting/expanding grating with changing contrast. Ask for which grating has stronger contrast.
%
% Parameters
% ----------
%
% window : window handle to draw into
% windowRect : dimension of the window
% screen_number : which screen to use
% correct_location : 1 if correct is right, -1 if left
% ringtex : the ring texture to draw
% pahandle : audio handle
%
% Variable Arguments
% ------------------
%
% ringwidth : spatial frequency of the grating
% contrast_left : array of contrast values for the left grating
% contrast_right : array of contrast values for the right grating
% driftspeed : how fast the gratings drift (units not clear yet)
% ppd : pixels per degree to convert to visual angles
% duration : how long each contrast level is shown in seconds
% baseline_delay : delay between trial start and stimulus onset.
% feedback_delay : delay between confidence response and feedback onset
% rest_delay : delay between feedback onset and trial end



%% Process variable input stuff            
baseline_delay = default_arguments(variable_arguments, 'baseline_delay', 0.75);
post_tone_delay = default_arguments(variable_arguments, 'post_tone_delay', 0.75);
rest_delay = default_arguments(variable_arguments, 'rest_delay', 1.5);
kbqdev = default_arguments(variable_arguments, 'kbqdev', []);

xpos = default_arguments(variable_arguments, 'xpos', [-15, 15]);
ypos = default_arguments(variable_arguments, 'ypos', [0, 0]);


%% Setting the stage
timing = struct();

% keys for response
flat_tone = 'm';
quit = 'ESCAPE';

black = BlackIndex(screen_number);

xpos = xpos*ppd;
ypos = ypos*ppd;
[xCenter, yCenter] = RectCenter(windowRect);
ifi = Screen('GetFlipInterval', window);

xpos = xpos + xCenter;
ypos = ypos + yCenter;

rgb2ntsc_matrix = [0.299 0.587 0.114; 0.596 -0.274 -0.322; 0.211 -0.523 0.312];

red = [1; 0; 0];
blue = [0; 0; 1];
green = [0; 1; 0];



%% Baseline Delay period

% Draw the fixation point
fix.color = red; % get ready
window      = drawFixation(window, windowRect, fix); % fixation
Screen('DrawingFinished', window); % helps with managing the flip performance
vbl = Screen('Flip', window);

% Screen('DrawDots', window, [xCenter; yCenter], 10, green, [], 1);
% vbl = Screen('Flip', window);
timing.TrialOnset = vbl;

%trigger(trigger_enc.trial_start);
ppWrite(888,trigger_enc.trial_start);
if setup.Eye
    Eyelink('message', 'trial start');
end
WaitSecs(0.005);
if tone == 1
   % trigger(trigger_enc.ripple_tone); 
    ppWrite(888,trigger_enc.ripple_tone);
    if setup.Eye
        Eyelink('message', 'ripple tone');
    end
elseif tone == 2
   % trigger(trigger_enc.flat_tone); 
    ppWrite(888,trigger_enc.flat_tone);
    if setup.Eye
        Eyelink('message', 'flat tone');
    end
end
WaitSecs(0.005);
%trigger(trigger_enc.noise_sigma);% + ns);
%WaitSecs(0.001);
waitframes = (baseline_delay-0.01)/ifi;

flush_kbqueues(kbqdev);

beep = beeps{tone};
stim_dur = 2;


PsychPortAudio('FillBuffer', pahandle.h, beep);
fix.color = red; 
window = drawFixation(window, windowRect, fix); % fixation
Screen('DrawingFinished', window); % helps with managing the flip performance
%startCue = vbl + post_response_delay;
vbl = Screen('Flip', window, vbl + (waitframes - 0.5) * ifi);

timing.response_cue = vbl;
start = GetSecs;
rt_choice = nan;
%key_pressed = false;
error = false;
response = nan;
RT = nan;

%trigger(trigger_enc.tone_start);
ppWrite(888,trigger_enc.tone_start);
if setup.Eye
    Eyelink('message', 'tone start');
end
start = GetSecs;
t1 = PsychPortAudio('Start', pahandle.h, 1, 0, 1);

beepLengthFrames = round(2 / ifi); 

%for i = 1:beepLengthFrames
while (GetSecs-start) < 2
    [keyIsDown, firstPress] = check_kbqueues(kbqdev);
    if keyIsDown
        RT = GetSecs();
        keys = KbName(firstPress);
        switch keys
            case quit
                throw(MException('EXP:Quit', 'User request quit'));
            case {flat_tone, 'm'}
                if setup.Eye
                    Eyelink('message', sprintf('decision %i', trigger_enc.flat_resp));
                end
                %trigger(trigger_enc.flat_resp);
                ppWrite(888,trigger_enc.flat_resp);
                response = 2; %flat tone

        end
        rt_choice = RT-start;
        key_pressed = true;
%     else
%         response = 1; %no button press = ripple tone
    end
end
if isnan(response)
    response = 1;
end
if tone == 2 % flat tone
    if response == 2
        correct = 1; %hit
        if setup.Eye
            Eyelink('message', sprintf('accuracy %i', trigger_enc.hit))
        end
       % trigger(trigger_enc.hit);
        ppWrite(888,trigger_enc.hit);
        fprintf('Hit\n')       
    elseif response == 1
        correct = 2; %miss
        if setup.Eye
            Eyelink('message', sprintf('accuracy %i', trigger_enc.miss))
        end
        %trigger(trigger_enc.miss);
        ppWrite(888,trigger_enc.miss);
        fprintf('Miss\n')  
    end
elseif tone == 1 % ripple tone
    if response == 1
        correct = -1; % correct reject
        if setup.Eye
            Eyelink('message', sprintf('accuracy %i', trigger_enc.correct_reject))
        end
       % trigger(trigger_enc.correct_reject);
        ppWrite(888,trigger_enc.correct_reject);
        fprintf('Correct reject\n')  
    elseif response == 2;
        correct = -2; %false alarm
        if setup.Eye
            Eyelink('message', sprintf('accuracy %i', trigger_enc.false_alarm))
        end
       % trigger(trigger_enc.false_alarm);
        ppWrite(888,trigger_enc.false_alarm);
        fprintf('False alarm\n')  
    end
end


timing.RT = RT;


% Wait for the beep to end. Here we use an improved timing method suggested
% by Mario.
% See: https://groups.yahoo.com/neo/groups/psychtoolbox/conversations/messages/20863
% For more details.
%%%%%
[actualStartTime, ~, ~, estStopTime] = PsychPortAudio('Stop', pahandle.h, 1, 1);
timing.feedback_delay_stop = estStopTime;

%trigger(trigger_enc.tone_stop);
ppWrite(888,trigger_enc.tone_stop);
if setup.Eye
    Eyelink('message', 'tone stop');
end



%fix.color = red; % get ready
%window      = drawFixation(window, windowRect, fix); % fixation
%Screen('DrawingFinished', window); % helps with managing the flip performance
%waitframes = 1;%(post_tone_delay/ifi) - 1;
%vbl = Screen('Flip', window, estStopTime + (waitframes - 0.5) * ifi);



% fix.color = blue; % get ready
% window      = drawFixation(window, windowRect, fix); % fixation
% Screen('DrawingFinished', window); % helps with managing the flip performance
% vbl = Screen('Flip', window, vbl + (waitframes - 0.5) * ifi);
% trigger(trigger_enc.blink_onset);
% if setup.Eye
%     Eyelink('message', 'blink_onset');
% end
% 
% waitframes = (rest_delay/ifi);
% fix.color = red; % get ready
% window      = drawFixation(window, windowRect, fix); % fixation
% Screen('DrawingFinished', window); % helps with managing the flip performance
% vbl = Screen('Flip', window, vbl + (waitframes - 0.5) * ifi);
% trigger(trigger_enc.blink_offset);
% if setup.Eye
%     Eyelink('message', 'blink_offset');
% end
timing.trial_end = vbl;
%trigger(trigger_enc.trial_end );
ppWrite(888,trigger_enc.trial_end);
if setup.Eye
    Eyelink('message', 'trial_end');
end
