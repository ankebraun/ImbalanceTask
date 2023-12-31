%% Imbalance assr task
%
% Runs one session of the Imbalance assr task.
%
sca; close all; clearvars; clear all; clc; dbstop if error;
addpath ppWrite;
global IO_LIB;
%IO_LIB = 'C:\ERANET\ASSR\ppWrite\inpoutx64.dll';
IO_LIB = 'C:\Imbalance\ASSR\ppWrite\inpoutx64.dll';

% Close audio device, shutdown driver:
% PsychPortAudio('Close');
%% Global parameters.
rng('shuffle')
setup; % load various setup parameters
setup.do_trigger = true; %true;% set to true if scanning in the EEG lab to send triggers
setup.Eye = true; %true; % set to true if using Eyelink
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

setup.nblocks = 1;

%try
    options.datadir = 'assr_data/';
    options.datadir = fullfile(options.datadir, sprintf('%s_assr', num2str(setup.participant)));
    [~, ~, ~] = mkdir(options.datadir);
    session_struct = struct('results', [], 'date', datestr(clock));
    results_struct = session_struct;
    session_identifier =  datestr(now, 30);

    % load quest parameters
    append_data = false;

    setup_ptb;
    [tw, th] = Screen('WindowSize', window);

    opts = {'duration', .1,...
        'ppd', options.ppd,...%31.9,... % for MEG display at 65cm viewing distance
        'xpos', [-(tw/options.ppd)/4 (tw/options.ppd)/4],... %[-8, 8],...
        'ypos', [0, 0]}; 

    %-------------
    % Present instructions on the screen
    %-------------
    white = WhiteIndex(screenNumber);
	if setup.german,
	    line1 = 'Schauen Sie immer auf das Fixierungskreuz! \n  \n';
        line2 = 'Drücken Sie m, falls Sie den gesuchten Ton hören.  \n  \n';
        line3 = 'Antworten Sie während Sie den Ton hören.  \n  \n';       
        line4 = 'Versuchen Sie nicht zu blinzeln solange Sie den Ton hören. \n \n';
  %      line5 = 'Wenn das Kreuz blau ist dürfen Sie blinzeln. \n \n';       
	    line5 = 'Drücken Sie eine Taste, um zu beginnen.';
	    DrawFormattedText(window, [line1 line2 line3 line4 line5],...
	        'center', 'center', white);
	    Screen('Flip', window);
	    % Wait for key press
	    WaitSecs(.1); KbWait(); WaitSecs(.1);
	else
	    line1 = 'Always fixate the cross! \n  \n';
        line2 = 'Press m, if you hear the target tone. \n  \n';
        line3 = 'Respond while you hear the tone. \n \n';
        line4 = 'Try not to blink as long as you hear the tone. \n \n';
%        line5 = 'You are allowed to blink as long as the fixation cross is blue. \n \n';
 	    line5 = 'Press any button to start.';
	    DrawFormattedText(window, [line1 line2 line3 line4 line5],...
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
		    
    % A structure to save results.
    results = struct('response', [], 'choice_rt', [], 'correct', [], 'tone', [], 'date', [], 'session', [], 'run', []);

    % Sometimes we want to repeat the same contrast fluctuations, load them
    % here. You also need to set the repeat interval manually. The repeat
    % interval specifies the interval between repeated contrast levels.
    % If you want to show each of, e.g. 5 repeats twice and you have 100
    % trials, set it to 10.
    

    num_trials = ones(1,110);
    %set the flat tones first
    %first flat id
    id_first = randi([4 15], 1);
    num_trials(id_first)=2; %max id for first flat = 110-(6X9+9)=46
    flat_distances=randi([7 round((110-id_first)/9)],9,1); % set the distances for the next 9 flat stim (max distance depend on position of first flat)
    for i=1:9
        id_lastflat=find(num_trials==2);
        id_lastflat=id_lastflat(end);
        num_trials(id_lastflat+flat_distances(i))=2;
    end
    tones=num_trials;


%     rippletones = NaN(1,10);
%     for j = 1:10
%         rippletones(j) = randi([6,14],1);
%     end 
%     
%     num_trials = sum(rippletones) + 10;
%     tones = NaN(1, num_trials);    
%     tones(1:rippletones(1)) = 1; %rippletone = 1
% 
%     for j = 1:9
%         k = sum(rippletones(1:j))+j;
%         tones(k) = 2; %flat tone
%         tones(k+1: sum(rippletones(1:j+1))+j) = 1; %ripple tone
%     end
%     tones(sum(rippletones)+10) = 2; %flat tone
    
    
    %% Do Experiment
    for trial = 1:length(num_trials)
        try
            if setup.Eye,
                % This supplies the title at the bottom of the eyetracker display
                Eyelink('command', 'record_status_message "TRIAL %d/%d"', trial, options.num_trials);
                Eyelink('message', 'TRIALID %d', trial);
            end
            
            if trial == 1
                if setup.Eye
                    Eyelink ('Message', sprintf('block %i started at %d trigger None', setup.run, GetSecs));
                end
                %trigger(trigger_enc.block_start); 
                ppWrite(888,trigger_enc.block_start);
            end

            % Set options that are valid only for this trial.
            trial_options = [opts, {...
                'baseline_delay', 1.5 + rand*1,...
                'post_tone_delay', 0.75 + 0.75*rand,...   
                'rest_delay', 0.75 + rand*0.5,...
                'kbqdev', options.kbqdev}];
            
            % Encode trial number in triggers.
            bstr = dec2bin(trial, 8);
            pins = find(str2num(reshape(bstr',[],1))');
            WaitSecs(0.005);
            for pin = pins
                %trigger(pin);
                ppWrite(888,pin);
                WaitSecs(0.005);
            end
            [correct, response, rt_choice, timing] = one_trial(setup, window, options.window_rect,...
                screenNumber, tones(trial), audio, trigger_enc, options.beeps, options.ppd, trial_options);
            
            timings{trial} = timing;

            results(trial) = struct('response', response, 'choice_rt', rt_choice, 'correct', correct,...
                'tone', tones(setup.run,trial), 'date', session_identifier, 'session', setup.session, 'run', setup.run);
           
            if setup.Eye,
                Eyelink('message', 'TRIALEND %d', trial);
            end
        catch ME
            if (strcmp(ME.identifier,'EXP:Quit'))
                break
            else
                rethrow(ME);
            end
        end
    end
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
fprintf('Saving data to %s\n', options.datadir)
if setup.Eye
    eyefilename   = fullfile(options.datadir, sprintf('%s_%s.edf',num2str(setup.participant), num2str(session_identifier) ));
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

session_struct.results = struct2table(results);
%session_struct.results = results;

save( fullfile(options.datadir, sprintf('assr_task_P%s_s%s_r%s_%s_results.mat', num2str(setup.participant), num2str(setup.session), num2str(setup.run), session_identifier)), 'session_struct')
if ~append_data
    results_struct = session_struct;
else
    disp('Trying to append')
    results_struct(length(results_struct)+1) = session_struct;
end
save(fullfile(options.datadir, 'quest_results.mat'), 'results_struct')
writetable(session_struct.results, fullfile(options.datadir, sprintf('%s_%s_results.csv', num2str(setup.participant), session_identifier)));
