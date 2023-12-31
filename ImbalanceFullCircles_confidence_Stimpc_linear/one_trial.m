function [correct, response, confidence, response_too_early, confidence_too_early, rt_choice, timing] = one_trial(setup, window, windowRect, screen_number, correct_location, ringtex, pahandle, trigger_enc, beeps, ppd, variable_arguments)
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
radius = default_arguments(variable_arguments, 'radius', 150);
inner_annulus = default_arguments(variable_arguments, 'inner_annulus', 5);
ringwidth = default_arguments(variable_arguments, 'ringwidth', 25);
sigma = default_arguments(variable_arguments, 'sigma', 2*ppd);
cutoff = default_arguments(variable_arguments, 'cutoff', 2*ppd);

contrast_left = default_arguments(variable_arguments, 'contrast_left', [10, 9, 8, 7, 6, 5, 4, 3, 2, 1]/10.);
contrast_right = default_arguments(variable_arguments, 'contrast_right', [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]/10.);
xpos = default_arguments(variable_arguments, 'xpos', [-15, 15]);
ypos = default_arguments(variable_arguments, 'ypos', [0, 0]);

driftspeed = default_arguments(variable_arguments, 'driftspeed', 1);
duration = default_arguments(variable_arguments, 'duration', .1);
baseline_delay = default_arguments(variable_arguments, 'baseline_delay', 0.75);
post_response_delay = default_arguments(variable_arguments, 'post_response_delay', 0.75);
feedback_delay = default_arguments(variable_arguments, 'feedback_delay', 0.5);
rest_delay = default_arguments(variable_arguments, 'rest_delay', 1.5);
expand = default_arguments(variable_arguments, 'expand', 1);
kbqdev = default_arguments(variable_arguments, 'kbqdev', []);


%% Setting the stage
timing = struct();

% keys for response
left_conf_high = 'z';
left_conf_low = 'x';
right_conf_high = 'm';
right_conf_low = 'n';
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
%timing.TrialOnset = vbl;
timing.TrialOnset = GetSecs;

%trigger(trigger_enc.trial_start);
ppWrite(888,trigger_enc.trial_start);
if setup.Eye
    Eyelink('message', 'trial start');
end
WaitSecs(0.005);
if correct_location == 1
    %trigger(trigger_enc.stim_strong_right); % Right correct
    ppWrite(888,trigger_enc.stim_strong_right);
    if setup.Eye
        Eyelink('message', 'right correct');
    end
elseif correct_location == -1
    %trigger(trigger_enc.stim_strong_left); % Left correct
    ppWrite(888,trigger_enc.stim_strong_left);
    if setup.Eye
        Eyelink('message', 'left correct');
    end
end
WaitSecs(0.005);
%trigger(trigger_enc.noise_sigma);% + ns);
%WaitSecs(0.001);
%waitframes = (baseline_delay-0.01)/ifi;
waitframes = (baseline_delay)/ifi;

flush_kbqueues(kbqdev);

%% Animation loop
start = nan;
cnt = 1;
framenum = 1;
stimulus_onset = nan;
[low_left, high_left] = contrast_colors(contrast_left(cnt), 0.5);
[low_right, high_right] = contrast_colors(contrast_right(cnt), 0.5);
%cnt = cnt+1;
shiftvalue = 0;

flipstim = []
eff_radius = radius + cutoff * sigma;
response_too_early = nan;
confidence_too_early = nan;
dynamic_ = zeros(1,length(contrast_left) +1);
dynamic = zeros(1,length(contrast_left) +1);

flips = 0;
while ~((GetSecs - stimulus_onset) >= (length(contrast_left))*duration-1.6*ifi)
%    disp(contrast_left(cnt));
    % Set the right blend function for drawing the gabors
    Screen('BlendFunction', window, 'GL_ONE', 'GL_ZERO');
%    Screen('BlendFunction', window, 'GL_SRC_ALPHA', 'GL_ONE_MINUS_SRC_ALPHA');

    Screen('DrawTexture', window, ringtex, [], [], [], [], [], low_left, [], [],...
       [high_left(1), high_left(2), high_left(3), high_left(4), shiftvalue, ringwidth, radius, inner_annulus, sigma, cutoff, xpos(1), yCenter]);

    Screen('DrawTexture', window, ringtex, [], [], [], [], [], low_right, [], [],...
       [high_right(1), high_right(2), high_right(3), high_right(4), shiftvalue, ringwidth, radius, inner_annulus, sigma, cutoff, xpos(2), yCenter]);    
    
    shiftvalue = shiftvalue+expand*driftspeed;
    % Change the blend function to draw an antialiased fixation point
    % in the centre of the array
    Screen('BlendFunction', window, 'GL_SRC_ALPHA', 'GL_ONE_MINUS_SRC_ALPHA');
    
    % Draw the fixation point
    fix.color = red; % get ready
    window      = drawFixation(window, windowRect, fix); % fixation
    Screen('DrawingFinished', window); % helps with managing the flip performance
    
%     imageArray = Screen('GetImage', window);
%     % imwrite is a Matlab function, not a PTB-3 function
%     imwrite(imageArray, 'FullCircles.jpg')

    % Flip our drawing to the screen
    vbl = Screen('Flip', window, vbl + (waitframes-.5) * ifi);
   % timing.flipstim = vbl;
    flipstim = [flipstim vbl];
%    flush_kbqueues(kbqdev);
    
    if framenum == 1
        if setup.Eye
            Eyelink('message', 'SYNCTIME');
            Eyelink('message', 'stim_onset 1');           
        end
        %trigger(trigger_enc.stim_onset);
        ppWrite(888,trigger_enc.stim_onset);
        timing.stim_onset = GetSecs;
        WaitSecs(0.001);
    end
    framenum = framenum +1;
    waitframes = 1;
    %dynamic = [dynamic vbl];
    
    % Change contrast every 100ms
    if isnan(start)
        stimulus_onset = GetSecs;
        if setup.Eye
            Eyelink('message', sprintf('conrast left %f, contrast right %f',contrast_left(cnt), contrast_right(cnt)));
        end
       % trigger(trigger_enc.con_change);
        ppWrite(888,trigger_enc.con_change)
        start = GetSecs;
        dynamic(cnt) = vbl;
        %dynamic = [dynamic GetSecs];
        dynamic_(cnt) = GetSecs;
    end
    elapsed = GetSecs;
    flips = flips + 1
  %  disp(elapsed-start);
    %    if (vbl-dynamic(cnt)) >= (duration-1*ifi) && cnt+1 <= length(contrast_left)
 %   if ((flips >= 6)||(elapsed-start) >= (duration-1*ifi)) && cnt+1 <= length(contrast_left)
    if ((flips >= 6)||(vbl-dynamic(cnt)) >= (duration-1.4*ifi)) && cnt+1 <= length(contrast_left)


        cnt = cnt+1;
        [low_left, high_left] = contrast_colors(contrast_left(cnt), 0.5);
        [low_right, high_right] = contrast_colors(contrast_right(cnt), 0.5);
            Screen('BlendFunction', window, 'GL_ONE', 'GL_ZERO');
    %    Screen('BlendFunction', window, 'GL_SRC_ALPHA', 'GL_ONE_MINUS_SRC_ALPHA');

        Screen('DrawTexture', window, ringtex, [], [], [], [], [], low_left, [], [],...
           [high_left(1), high_left(2), high_left(3), high_left(4), shiftvalue, ringwidth, radius, inner_annulus, sigma, cutoff, xpos(1), yCenter]);

        Screen('DrawTexture', window, ringtex, [], [], [], [], [], low_right, [], [],...
           [high_right(1), high_right(2), high_right(3), high_right(4), shiftvalue, ringwidth, radius, inner_annulus, sigma, cutoff, xpos(2), yCenter]);    

        shiftvalue = shiftvalue+expand*driftspeed;
        % Change the blend function to draw an antialiased fixation point
        % in the centre of the array
        Screen('BlendFunction', window, 'GL_SRC_ALPHA', 'GL_ONE_MINUS_SRC_ALPHA');

        % Draw the fixation point
        fix.color = red; % get ready
        window      = drawFixation(window, windowRect, fix); % fixation
        Screen('DrawingFinished', window); % helps with managing the flip performance

    %     imageArray = Screen('GetImage', window);
    %     % imwrite is a Matlab function, not a PTB-3 function
    %     imwrite(imageArray, 'FullCircles.jpg')

        % Flip our drawing to the screen
        vbl = Screen('Flip', window, vbl + (waitframes-.5) * ifi);
      %  timing.flipstim = vbl;
        flipstim = [flipstim vbl];
        flips = 1
        %trigger(trigger_enc.con_change);
        ppWrite(888,trigger_enc.con_change);
        if setup.Eye
            Eyelink('message', sprintf('conrast left %f, contrast right %f',contrast_left(cnt), contrast_right(cnt)));
        end
        start = GetSecs;  
        dynamic(cnt) = vbl;
        dynamic_(cnt) = GetSecs;

    end  
 %   end
    [keyIsDown, firstPress] = check_kbqueues(kbqdev);
    if keyIsDown
        keys = KbName(firstPress);
        switch keys
            case quit
                throw(MException('EXP:Quit', 'User request quit'));
            case {left_conf_high, 'y'}
                if setup.Eye
                    Eyelink('message', sprintf('decision %i', trigger_enc.left_resp_conf_high_too_early))
                end
                %trigger(trigger_enc.left_resp_conf_high_too_early);
                ppWrite(888,trigger_enc.left_resp_conf_high_too_early);
                response_too_early = -1;
                confidence_too_early = 2;
            case {left_conf_low, 'x'}
                if setup.Eye
                    Eyelink('message', sprintf('decision %i', trigger_enc.left_resp_conf_low_too_early))
                end
                %trigger(trigger_enc.left_resp_conf_low_too_early);
                ppWrite(888,trigger_enc.left_resp_conf_low_too_early);
                response_too_early = -1;
                confidence_too_early = 1;
            case {right_conf_high, 'm'}
                if setup.Eye
                    Eyelink('message', sprintf('decision %i', trigger_enc.right_resp_conf_high_too_early));
                end
                %trigger(trigger_enc.right_resp_conf_high_too_early);
                ppWrite(888,trigger_enc.right_resp_conf_high_too_early);
                response_too_early = 1;       
                confidence_too_early = 2;   
            case {right_conf_low, 'n'}
                if setup.Eye
                    Eyelink('message', sprintf('decision %i', trigger_enc.right_resp_conf_low_too_early));
                end
                %trigger(trigger_enc.right_resp_conf_low_too_early);
                ppWrite(888,trigger_enc.right_resp_conf_low_too_early);
                response_too_early = 1;       
                confidence_too_early = 1; 
        end
    end
    flush_kbqueues(kbqdev);
end

target = (waitframes - 0.5) * ifi;
Screen('BlendFunction', window, 'GL_SRC_ALPHA', 'GL_ONE_MINUS_SRC_ALPHA');


%%% Get choice
% Draw the fixation point
fix.color = red; % get ready
window      = drawFixation(window, windowRect, fix); % fixation
Screen('DrawingFinished', window); % helps with managing the flip performance
vbl = Screen('Flip', window, vbl + target );
%dynamic = [dynamic vbl];
dynamic(cnt + 1) = vbl;
flipstim = [flipstim vbl];
timing.flip = flipstim;
%dynamic = [dynamic GetSecs];
dynamic_(cnt+1) = GetSecs;
timing.animation = dynamic;
timing.animation2 = dynamic_;
%trigger(trigger_enc.decision_start);
ppWrite(888,trigger_enc.decision_start);
if setup.Eye
    Eyelink('message', 'decision_start 1');
end
timing.response_cue = vbl;
start = GetSecs;
rt_choice = nan;
key_pressed = false;
error = false;
response = nan;
RT = nan;
while (GetSecs-start) < 3
    [keyIsDown, firstPress] = check_kbqueues(kbqdev);
    if keyIsDown
        RT = GetSecs();
        keys = KbName(firstPress);
        if iscell(keys)
            error = true;
            break
        end
        switch keys
            case quit
                throw(MException('EXP:Quit', 'User request quit'));
            case {left_conf_high, 'y'}
                if setup.Eye
                    Eyelink('message', sprintf('decision %i', trigger_enc.left_resp_conf_high))
                end
               % trigger(trigger_enc.left_resp_conf_high);
                ppWrite(888,trigger_enc.left_resp_conf_high);
                response = -1;
                confidence = 2;
                fprintf('left conf high\n')
            case {left_conf_low, 'x'}
                if setup.Eye
                    Eyelink('message', sprintf('decision %i', trigger_enc.left_resp_conf_low))
                end
                %trigger(trigger_enc.left_resp_conf_low);
                ppWrite(888,trigger_enc.left_resp_conf_low);
                response = -1;
                confidence = 1;
                fprintf('left conf low\n')
            case {right_conf_high, 'm'}
                if setup.Eye
                    Eyelink('message', sprintf('decision %i', trigger_enc.right_resp_conf_high));
                end
                %trigger(trigger_enc.right_resp_conf_high);
                ppWrite(888,trigger_enc.right_resp_conf_high);
                response = 1;       
                confidence = 2;   
                fprintf('right conf high\n')
            case {right_conf_low, 'n'}
                if setup.Eye
                    Eyelink('message', sprintf('decision %i', trigger_enc.right_resp_conf_low));
                end
               % trigger(trigger_enc.right_resp_conf_low);
                ppWrite(888,trigger_enc.right_resp_conf_low);
                response = 1;       
                confidence = 1;     
                fprintf('right conf low\n')
        end
        if ~isnan(response)
            if correct_location == response
                correct = 1;
                if setup.Eye
                    Eyelink('message', sprintf('decision %i', trigger_enc.correct_resp))
                end
                %trigger(trigger_enc.correct_resp);
                ppWrite(888,trigger_enc.correct_resp);
                fprintf('Choice Correct\n')
            else
                correct = 0;
                if setup.Eye
                    Eyelink('message', sprintf('decision %i', trigger_enc.error_resp))
                end
                %trigger(trigger_enc.error_resp);
                ppWrite(888,trigger_enc.error_resp);
                fprintf('Choice Wrong\n')
            end
            rt_choice = RT-start;
            key_pressed = true;
            break;
        end
    end
end
timing.RT = RT;


if ~key_pressed || error
    %trigger(trigger_enc.no_decisions);
    ppWrite(888,trigger_enc.no_decisions);
    if setup.Eye
        Eyelink('message', 'decision 88');
    end
    fprintf('Error in answer\n')
%    wait_period = 1 + feedback_delay + rest_delay;
%    WaitSecs(wait_period);
    correct = nan;
    response = nan;
    confidence = nan;
    rt_choice = nan;
%    trigger(trigger_enc.trial_end);
%    return
end

%% Provide Feedback
if ~isnan(correct)
    beep = beeps{correct+1};
else
    beep = beeps{3};
end

PsychPortAudio('FillBuffer', pahandle.h, beep);
timing.post_response_delay_start = vbl;
fix.color = red; 
window = drawFixation(window, windowRect, fix); % fixation
Screen('DrawingFinished', window); % helps with managing the flip performance
%waitframes = (post_response_delay/ifi) - 1;
waitframes = (post_response_delay/ifi);
%startCue = vbl + post_response_delay;
vbl = Screen('Flip', window, vbl + (waitframes - 0.5) * ifi);
%trigger(trigger_enc.feedback_start);
ppWrite(888,trigger_enc.feedback_start);
if setup.Eye
    Eyelink('message', 'feedback start');
end
t1 = PsychPortAudio('Start', pahandle.h, 1, 0, 1);
if ~isnan(correct)
    if correct
        %trigger(trigger_enc.feedback_correct);
        ppWrite(888,trigger_enc.feedback_correct);
        if setup.Eye
            Eyelink('message', 'feedback 1');
        end
    else
        %trigger(trigger_enc.feedback_incorrect);
        ppWrite(888,trigger_enc.feedback_incorrect);
        if setup.Eye
            Eyelink('message', 'feedback -1');
        end
    end
else
   % trigger(trigger_enc.feedback_late);
    ppWrite(888,trigger_enc.feedback_late);
    if setup.Eye
        Eyelink('message', 'feedback 2');
    end
end
timing.feedback_start = t1;

% Wait for the beep to end. Here we use an improved timing method suggested
% by Mario.
% See: https://groups.yahoo.com/neo/groups/psychtoolbox/conversations/messages/20863
% For more details.
%%%%%
[actualStartTime, ~, ~, estStopTime] = PsychPortAudio('Stop', pahandle.h, 1, 1);
timing.feedback_delay_stop = estStopTime;
vbl = estStopTime;
%trigger(trigger_enc.feedback_stop);
ppWrite(888,trigger_enc.feedback_stop); 
if setup.Eye
    Eyelink('message', 'feedback stop');
end

%fix.color = red; % get ready
%window      = drawFixation(window, windowRect, fix); % fixation
%Screen('DrawingFinished', window); % helps with managing the flip performance
%waitframes = (feedback_delay/ifi) - 1;
waitframes = (feedback_delay/ifi);
%vbl = Screen('Flip', window, estStopTime + (waitframes - 0.5) * ifi);



fix.color = blue; % get ready
window      = drawFixation(window, windowRect, fix); % fixation
Screen('DrawingFinished', window); % helps with managing the flip performance
vbl = Screen('Flip', window, vbl + (waitframes - 0.5) * ifi);
%trigger(trigger_enc.blink_onset);
ppWrite(888,trigger_enc.blink_onset);
if setup.Eye
    Eyelink('message', 'blink_onset');
end

waitframes = (rest_delay/ifi);
fix.color = red; % get ready
window      = drawFixation(window, windowRect, fix); % fixation
Screen('DrawingFinished', window); % helps with managing the flip performance
vbl = Screen('Flip', window, vbl + (waitframes - 0.5) * ifi);
%trigger(trigger_enc.blink_offset);
ppWrite(888,trigger_enc.blink_offset);
if setup.Eye
    Eyelink('message', 'blink_offset');
end
timing.trial_end = vbl;
%trigger(trigger_enc.trial_end );
ppWrite(888,trigger_enc.trial_end);
if setup.Eye
    Eyelink('message', 'trial_end');
end
