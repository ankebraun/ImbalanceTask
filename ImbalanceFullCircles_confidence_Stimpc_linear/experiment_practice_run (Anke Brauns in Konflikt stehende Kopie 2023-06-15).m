%% Imbalance 2afc task
%
% Runs one session of the Imbalance 2afc task.
%
close all; clearvars; clear all; clc; dbstop if error;
addpath ppWrite;
global IO_LIB;
IO_LIB = 'C:\Imbalance\ImbalanceFullCircles_confidence_Stimpc_linear\ppWrite\inpoutx64.dll';

% Close audio device, shutdown driver:
% PsychPortAudio('Close');
%% Global parameters.
rng('shuffle')
setup; % load various setup parameters
setup.do_trigger = false;%true;% set to true if scanning in the EEG lab to send triggers
setup.Eye = false;%true; % set to true if using Eyelink
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

setup.nblocks = 6;
% on half of the blocks the side with the stronger contrast will be chosen at random on the other half it will be repeated with 80% probability (i.e. alternated with 20% probability)
% if exist(sprintf('trans_prob_counter_P%d_s%d.mat', setup.participant, setup.session), 'file') == 2,
%     load(sprintf('trans_prob_counter_P%d_s%d.mat', setup.participant, setup.session));
%     setup.transition_probability = trans_probs_counter(setup.run); 
% else 
%     trans_probs_counter = [0.2 0.5 0.2 0.5 0.2 0.5];
%     trans_probs_counter = trans_probs_counter(:, randperm(size(trans_probs_counter,2)));
%     filename_prob_counter = sprintf('trans_prob_counter_P%d_s%d.mat', setup.participant, setup.session);
%     save(filename_prob_counter, '-mat', 'trans_probs_counter');
%     setup.transition_probability = trans_probs_counter(setup.run); 
% end    
% create matrix with repetition probabilities 
% diagonal elements: repetition of side with stronger contrast 
% off-diagonal elements: alternation of side with stronger contrast
setup.transition_probability = 0.5
% if setup.transition_probability == 0.2,
%     setup.transition_probabilities = [0.8 0.2; 0.2 0.8];
% elseif setup.transition_probability == 0.5,
setup.transition_probabilities = [0.5 0.5; 0.5 0.5];
% end

side = NaN(setup.nblocks, options.num_trials);
% for the first trial of each block, randomly choose side with the stronger contrast 
starting_value(setup.run) = randi(2,1);
side(setup.run,1) = starting_value(setup.run);
% for all other trials, choose the side with the stronger contrast depending on the transition probability of the current run via a Markov process
for trial = 2:options.num_trials
    setup.this_step_distribution = setup.transition_probabilities(side(setup.run,trial-1),:);
    setup.cumulative_distribution = cumsum(setup.this_step_distribution);
    r = rand();
    side(setup.run,trial) = find(setup.cumulative_distribution>r, 1);
end

for trial = 1:options.num_trials
    if side(setup.run,trial) == 1,
        side(setup.run,trial)=-1;
    elseif side(setup.run,trial) == 2,
        side(setup.run,trial) = 1;
    end
end
    


%try
    options.datadir = '2afc_data/';
    options.datadir = fullfile(options.datadir, num2str(setup.participant));
    [~, ~, ~] = mkdir(options.datadir);
    if setup.transition_probability == 0.2,
        quest_file = fullfile(options.datadir, 'quest_results_repetitive.mat');
    elseif setup.transition_probability == 0.5,
        quest_file = fullfile(options.datadir, 'quest_results_random.mat');
    end
    session_struct = struct('q', [], 'results', [], 'date', datestr(clock));
    results_struct = session_struct;
    session_identifier =  datestr(now, 30);
    q = QuestCreate(quest.threshold_guess, quest.threshold_guess_sigma, quest.pThreshold, quest.beta, quest.delta, quest.gamma);
    q.updatePdf = 1;
    % load quest parameters
    append_data = false;
%     if exist(quest_file, 'file') == 2
%         if strcmp(input('There is previous data for this subject. Load last QUEST parameters? [y/n] ', 's'), 'y')
%             [q, results_struct, quest.threshold_guess, quest.threshold_guess_sigma] = load_subject(quest_file);
%             append_data = true;
%         end
%     end

    fprintf('QUEST Parameters\n----------------\nThreshold Guess: %1.4f\nSigma Guess: %1.4f\n',...
        quest.threshold_guess, quest.threshold_guess_sigma)
    if ~strcmp(input('OK? [y/n] ', 's'), 'y')
        throw(MException('EXP:Quit', 'User request quit'));

    end    
    
    setup_ptb;
    [tw, th] = Screen('WindowSize', window);

    opts = {'duration', .1,...
        'ppd', options.ppd,...%31.9,... % for MEG display at 65cm viewing distance
        'xpos', [-(tw/options.ppd)/4 (tw/options.ppd)/4],... %[-8, 8],...
        'ypos', [0, 0]};%[-(tw/options.ppd)/16, -(tw/options.ppd)/16]}; %[0, 0]};%

    %-------------
    % Present instructions on the screen
    %-------------
    white = WhiteIndex(screenNumber);
	if setup.german,
	    line1 = 'Schauen Sie immer auf das Fixierungskreuz! \n  \n';
	    line2 = 'Drücken Sie y, falls der Kontrast des linken Gitters im Durchschnitt stärker ist \n  \n';
        line2b = 'und Sie sich relativ sicher sind, dass Ihre Antwort korrekt ist. \n  \n';
	    line3 ='Drücken Sie x, falls der Kontrast des linken Gitters im Durchschnitt stärker ist \n  \n';
        line3b = 'und Sie sich unsicher sind, dass Ihre Antwort korrekt ist. \n  \n';
        line4 = 'Drücken Sie m, falls der Kontrast des rechten Gitters im Durchschnitt stärker ist \n  \n';
        line4b = 'und Sie sich relativ sicher sind, dass Ihre Antwort korrekt ist.  \n  \n';
        line5 = 'Drücken Sie n, falls der Kontrast des rechten Gitters im Durchschnitt stärker ist \n  \n';
        line5b = 'und Sie sich unsicher sind, dass Ihre Antwort korrekt ist. \n  \n'
        line6 = 'Berücksichtigen Sie alle Kontraste vom Anfang bis zum Ende der Stimuluspräsentation gleichermaaßen \n  \n';
        line7 = 'und antworten Sie erst nachdem die beiden Gitter vom Bildschirm verschwunden sind. \n  \n';
        line8 = 'Falls Sie richtig geantwortet haben, hören Sie einen kurzen, hohen Ton. \n \n';
	    line9 = 'Falls Sie falsch geantwortet haben, hören Sie einen kurzen, tiefen Ton. \n \n';
	    line10 = 'Falls Sie zu früh oder zu spät geantwortet haben, hören Sie einen langen, tiefen Ton. \n \n';
        line11 = 'Versuchen Sie nicht zu blinzeln solange das Fixierungskreuz rot ist. \n \n';
        line12 = 'Wenn das Fixierungskreuz blau ist, dürfen Sie blinzeln. \n \n';       
	    line13 = 'Drücken Sie eine Taste, um zu beginnen.';
	    DrawFormattedText(window, [line1 line2 line2b line3 line3b line4 line4b line5 line5b line6 line7 line8 line9 line10 line11 line12 line13],...
	        'center', 'center', white);
	    Screen('Flip', window);
	    % Wait for key press
	    WaitSecs(.1); KbWait(); WaitSecs(.1);
	else
	    line1 = 'Always fixate the cross! \n  \n';
	    line2 = 'Press y, if the mean contrast of the left grating is stronger and your confidence about your accuracy is high. \n  \n';
	    line3 = 'Press x, if the mean contrast of the left grating is stronger and your confidence about your accuracy is low. \n  \n';
        line4 = 'Press m, if the mean contrast of the right grating is stronger and your confidence about your accuracy is high. \n  \n';
        line5 = 'Press n, if the mean contrast of the right grating is stronger and your confidence about your accuracy is low. \n  \n';
        line6 = 'Take all contrasts from the beginning to the end of the stimulus presentation into account equally. \n  \n';
        line7 = 'and respond only after the gratings disappeared from the screen. \n  \n';
        line8 = 'You will hear a short, high tone if your response was correct.\n \n';
	    line9 = 'You will hear a short, low tone if your response was incorrect.\n \n';
	    line10 = 'You will hear a long, low tone if you responded too early or too late.\n \n';
        line11 = 'Try not to blink as long as the fixation cross is red. \n \n';
        line12 = 'You are allowed to blink as long as the fixation cross is blue. \n \n';
	    line13 = 'Press any button to start.';
	    DrawFormattedText(window, [line1 line2 line3 line4 line5 line6 line7 line8 line9 line10 line11 line12 line13],...
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
		
    %% Set up QUEST
    %q = QuestCreate(quest.threshold_guess, quest.threshold_guess_sigma, quest.pThreshold, quest.beta, quest.delta, quest.gamma);
    %q.updatePdf = 1;
    
    % A structure to save results.
    results = struct('response', [], 'confidence', [], 'response_too_early', [], 'confidence_too_early', [], 'side', [], 'choice_rt', [], 'correct', [],...
        'contrast', [], 'contrast_2', [], 'contrast_left', [], 'contrast_right', [],...
        'repeat', [], 'repeated_stim', [], 'date', [], 'session', [], 'run', [], 'noise_sigma', [], 'expand', [], 'transition_probability', []);

    % Sometimes we want to repeat the same contrast fluctuations, load them
    % here. You also need to set the repeat interval manually. The repeat
    % interval specifies the interval between repeated contrast levels.
    % If you want to show each of, e.g. 5 repeats twice and you have 100
    % trials, set it to 10.
    options.repeat_contrast_levels = 0;
    if options.repeat_contrast_levels
        contrast_file_name = fullfile(options.datadir, 'repeat_contrast_levels.mat');
        repeat_levels = load(contrast_file_name, 'levels');
        repeat_levels = repeat_levels.levels;
        % I assume that repeat_contrast_levels contains a struct array with
        % fields contrast_a and contrast_b.
        assert(options.num_trials > length(repeat_levels));
        repeat_interval = 2; %'Replace with a sane value'; % <-- Set me!
        repeat_counter = 1;
    end
    %% Do Experiment
    high_coh_trials = randperm( options.num_trials, round(options.num_trials*0.15)); % 15% high coherence trials chosen at random	
	
    for trial = 1:options.num_trials
        try
            if setup.Eye,
                % This supplies the title at the bottom of the eyetracker display
                Eyelink('command', 'record_status_message "TRIAL %d/%d"', trial, options.num_trials);
                Eyelink('message', 'TRIALID %d', trial);
            end
            repeat_trial = false;
            repeated_stim = nan;
            
            if trial == 1
                if setup.Eye
                    Eyelink ('Message', sprintf('block %i started at %d trigger None', setup.run, GetSecs));
                end
                %trigger(trigger_enc.block_start);
                ppWrite(888,trigger_enc.block_start);
            end
            % Sample contrasts.
	        %            high_coh_trials = [randi([1 options.num_trials], [1,round(options.num_trials*0.15)])]; % 15% high coherence trials chosen at random
            if ismember(trial, high_coh_trials)
                contrast = 0.4;
            else    
                contrast = min(1, max(0, (QuestQuantile(q, 0.5))));%makes sure that the contrast is in the interval [0,1]
                %contrast = QuestQuantile(q, 0.5);%makes sure that the contrast is in the interval [0,1]
                %contrast = 10^contrast;
            end
            noise_sigma = options.noise_sigmas; % standard deviation of the normal distribution of contrast levels 
            [contrast_small, contrast_large] = sample_contrast(contrast, noise_sigma, options.baseline_contrast);  
            if side(setup.run,trial) == -1
                contrast_left = contrast_large;
                contrast_right = contrast_small;
            else
                contrast_left = contrast_small;
                contrast_right = contrast_large;
            end

            expand = randsample([-1, 1], 1); %randomly choose whether circular gratings are expanding or contracting
            fprintf('Correct is: %i, mean contrast is %f\n', side(setup.run, trial), mean(contrast))
            % Set options that are valid only for this trial.
            trial_options = [opts, {...
                'contrast_left', contrast_left,...
                'contrast_right', contrast_right,...
                'baseline_delay', 0.75 + rand*0.75,...
                'post_response_delay', 0.75 + 0.75*rand,...   
                'feedback_delay', 0.75 + rand*.75,...
                'rest_delay', 2.5,...% + rand,...
                'ringwidth', options.ringwidth,...
                'radius', options.radius,...
                'inner_annulus', options.inner_annulus,...
                'sigma', options.sigma,...
                'cutoff', options.cutoff,...
                'expand', expand,...
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
            [correct, response, confidence, response_too_early, confidence_too_early, rt_choice, timing] = one_trial(setup, window, options.window_rect,...
                screenNumber, side(setup.run,trial), ringtex, audio, trigger_enc, options.beeps, options.ppd, trial_options);
            
            timings{trial} = timing;
            if ~isnan(correct) && ~repeat_trial && ~ismember(trial, high_coh_trials)
              %   q = QuestUpdate(q, contrast + mean(noise_sigma), correct);
              %   q = QuestUpdate(q, contrast, correct);   
              q = QuestUpdate(q, abs(mean(contrast_left) - mean(contrast_right)), correct);                 			                
             % q = QuestUpdate(q, log10(abs(mean(contrast_left) - mean(contrast_right))), correct);                 			                
            end
	        contrast_2 = mean(contrast_right) - mean(contrast_left);            
             
            results(trial) = struct('response', response, 'confidence', confidence, 'response_too_early', response_too_early, 'confidence_too_early', confidence_too_early, 'side', side(setup.run,trial), 'choice_rt', rt_choice, 'correct', correct,...
                'contrast', contrast, 'contrast_2', contrast_2, 'contrast_left', contrast_left, 'contrast_right', contrast_right,...
                'repeat', repeat_trial, 'repeated_stim', repeated_stim,...
                'date', session_identifier, 'session', setup.session, 'run', setup.run, 'noise_sigma', noise_sigma, 'expand', expand, 'transition_probability', setup.transition_probability);
           
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
    eyefilename   = fullfile(options.datadir, sprintf('%s_%s_%s.edf', num2str(setup.participant), num2str(session_identifier), num2str(setup.run)));
    %eyefilename   = fullfile(sprintf('%s_%s_%s.edf', num2str(setup.participant), num2str(session_identifier), num2str(setup.run)));
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
session_struct.q = q;
session_struct.results = struct2table(results);
%session_struct.results = results;

save( fullfile(options.datadir, sprintf('2afc_task_P%s_s%s_r%s_%s_results.mat', num2str(setup.participant), num2str(setup.session), num2str(setup.run), session_identifier)), 'session_struct')
if ~append_data
    results_struct = session_struct;
else
    disp('Trying to append')
    results_struct(length(results_struct)+1) = session_struct;
end

% if setup.transition_probability == 0.2,
%     save(fullfile(options.datadir, 'quest_results_repetitive.mat'), 'results_struct')
% elseif setup.transition_probability == 0.5,
%     save(fullfile(options.datadir, 'quest_results_random.mat'), 'results_struct')
% end

writetable(session_struct.results, fullfile(options.datadir, sprintf('%s_%s_results.csv', num2str(setup.participant), session_identifier)));
save(fullfile(options.datadir, 'timings.mat'), 'timings')
