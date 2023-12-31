def get_meta(raw, behav, mapping, trial_pins, trial_start, trial_end, other_pins=None):
    '''
    Parse block structure from events in MEG files.
    Aggresively tries to fix introduced by recording crashes and late recording
    starts.
    mapping =
    '''

    def pins2num(pins):
        if len(pins) == 0:
            trial = 1
        else:
            # Convert pins to numbers
            trial = sum([2**(8 - pin) for pin in pins])
        return trial

    # events, _ = get_events(raw)
    # events = events.astype(float)

    events, _ = mne.events_from_annotations(raw, verbose=False) 
    raw.info["events"] = events
    events = events.astype(float)
    
    if trial_start == trial_end:
        start = np.where(events[:, 2] == trial_start)[0]
        end = np.where(events[:, 2] == trial_end)[0]
        end = np.concatenate((end[1:] - 1, np.array([events.shape[0]])))

    else:
        start, end = get_trial_periods(events, trial_start, trial_end)

    trials = []
    for i, (ts, te) in enumerate(zip(start, end)):
        current_trial = {}
        trial_nums = events[ts:te + 1, 2]
        trial_times = events[ts:te + 1, 0]
        if trial_pins:
            # Find any pins that need special treatment, parse them and remove
            # triggers from trial_nums
            for key, value in trial_pins.items():
                if key in trial_nums:
                    pstart = np.where(trial_nums == key)[0][0] + 1
                    pend = pstart + np.where(trial_nums[pstart:] > 8)[0][0] + 1
                    pvals = trial_nums[pstart:pend]
                    current_trial[value] = pins2num(pvals)
                    trial_nums = np.concatenate(
                        (trial_nums[:pstart], trial_nums[pend:]))
                    trial_times = np.concatenate(
                        (trial_times[:pstart], trial_times[pend:]))

        for trigger, time in zip(trial_nums, trial_times):
            if trigger in mapping.keys():
                key = mapping[trigger][0]
                val = mapping[trigger][1]
            else:
                key = trigger
                val = time
            if key in current_trial.keys():
                try:
                    current_trial[key].append(current_trial[key][-1] + 1)
                    current_trial[key + '_time'].append(time)
                except AttributeError:
                    current_trial[str(key)] = [current_trial[
                        key], current_trial[key] + 1]
                    current_trial[
                        str(key) + '_time'] = [current_trial[str(key) + '_time'], time]
            else:
                current_trial[key] = val
                current_trial[str(key) + '_time'] = time
        trials.append(current_trial)

    meta = pd.DataFrame(trials)
    for i in range(0,len(meta.resp)): 
        if np.isnan(meta.resp[i]): 
            meta.resp[i] = behav.response[i]*behav.confidence[i] 
            meta.resp_time[i] = meta.decision_start_time[i] + behav.choice_rt[i]*1000
        if np.isnan(meta.blink_offset[i]):
            meta.blink_offset[i] = 1
            meta.blink_offset_time[i] = meta.trial_end_time[i]
            
    # Find other pins that are not trial related
    if other_pins:
        nums = events[:, 2]
        for key, value in other_pins.items():
            pstarts = np.where(nums == key)[0] + 1
            for pstart in pstarts:
                t = events[pstart, 0]
                pend = pstart + np.where(nums[pstart:] > 8)[0][0] + 1
                pvals = nums[pstart:pend]
                idx = meta.trial_start_time > t
                meta.loc[idx, value] = pins2num(pvals)

    time_fields = [c for c in meta if str(c).endswith('_time')]
    meta_fields = [c for c in meta if not str(c).endswith('_time')]
    return meta.loc[:, meta_fields], meta.loc[:, time_fields]