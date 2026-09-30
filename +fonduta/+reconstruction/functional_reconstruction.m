function PDI = functional_reconstruction(datapath, savepath)
% FUNCTIONAL_RECONSTRUCTION Converts raw functional ultrasound imaging (fUSI) data to a MAT structure.
%
%   PDI = FUNCTIONAL_RECONSTRUCTION(datapath, savepath)
%
%   Inputs:
%       datapath - Path to the directory containing raw fUSI binary data,
%                  TTL CSV recordings, NIDAQ logfiles, and stimulation CSVs.
%       savepath - (Optional) Destination folder to save PDI.mat.
%                  Defaults to replacing 'Data_collection' in datapath with 'Data_analysis'.
%
%   Outputs:
%       PDI - Structure containing:
%               .PDI             : Cleaned [nz, nx, nt] functional volume array
%               .Dim             : Dimension metadata (nx, nz, nt, dx, dz, dt)
%               .time            : Frame completion timestamps in seconds, aligned to t = 0 at NIDAQ start
%               .stimInfo        : Extracted event timestamps (drop, touch, shock) relative to NIDAQ start
%               .TTLinfo_CROPPED : Post-experiment-start TTL channel matrix
%               .savepath        : Directory path where PDI.mat was saved
%
%   Description:
%       Loads raw fUSI binary data (`fUS_block_PDI_float.bin`), extracts scan parameters, 
%       and synchronizes fUSI frames with external NIDAQ/TTL trigger channels. 
%       Trims pre-experiment frames, re-zeros timestamps relative to NIDAQ start, and 
%       parses droplet stimulation paradigms.
%
%   Example:
%       PDI = functional_reconstruction('/path/to/Data_collection/session1');
%
%   Version History:
%        
%       V2 (this file) : specific parser functions for each paradigm + verification
%       plot for Droplet
%
%       V1 : Updated from Rawdata2MATnew_V0_Chaoyi_MOD.m. Added mandatory datapath check, 
%            standardized timing alignment to NIDAQ start (t = 0), and added droplet 
%            stimulation event extraction.


    %% Import helper functions - ONLY FOR PACKAGE VERSION
    import fonduta.reconstruction.*


    %% Input Handling and Path Setup

    % Enforce required datapath argument
    if nargin < 1 || isempty(datapath)
        error('datapath was not provided. Execution terminated.');
    end

    % Derive savepath if not provided or left empty
    if nargin < 2 || isempty(savepath)
        savepath = strrep(datapath, 'Data_collection', 'Data_analysis');
    end


    % FOR TESTING ONLY
    
    % % ------------ LOCAL DROPLET PARADIGM ----------------
    % datapath='/Users/leonardo/Dropbox/fUSI/data/fUSIHarmAversion/Data_collection/sub-mockexperiment/ses-999999/run-155150-func'
    % savepath = strrep(datapath, 'Data_collection', 'Data_analysis');
    % fprintf('CAREFUL!!! RUNNING TEST DATA %s.\n', datapath);

    % % ------------ LOCAL VISUAL PARADIGM ----------------
    % datapath='/Users/leonardo/Dropbox/fUSI/data/fUSIMethodsPaper_LC/Data_collection/sub-methods02/ses-231215/run-115047-func'
    % savepath = strrep(datapath, 'Data_collection', 'Data_analysis');
    % fprintf('CAREFUL!!! RUNNING TEST DATA %s.\n', datapath);


    %% Locate FUSI Data Directory

    D = dir(fullfile(datapath, 'FUSI_data*'));
    if isempty(D)
        error('No FUSI_data* directory found in the specified datapath.');
    end
    fusDatapath = fullfile(D(1).folder, D(1).name);

    %% Load Scan Parameters

    scanParamFiles = {'post_L22-14_PlaneWave_FUSI_data.mat', 'L22-14_PlaneWave_FUSI_data.mat'};
    BFConfig = [];
    for i = 1:length(scanParamFiles)
        scanParamPath = fullfile(fusDatapath, scanParamFiles{i});
        if exist(scanParamPath, 'file')
            fprintf('Loading scan parameters from %s.\n', scanParamFiles{i});
            S = load(scanParamPath, 'BFConfig');
            BFConfig = S.BFConfig;
            break;
        end
    end
    if isempty(BFConfig)
        error('No scan parameter file found. Please check the fusDatapath.');
    end

    %% Read Raw PDI Data

    pdiFile = fullfile(fusDatapath, 'fUS_block_PDI_float.bin');
    if exist(pdiFile, 'file')
        fprintf('Loading PDI data from %s.\n', 'fUS_block_PDI_float.bin');
        fid = fopen(pdiFile, 'r');
        rawPDI = fread(fid, inf, 'single');
        fclose(fid);
    else
        error('No PDI data found. Please convert IQ data to PDI first.');
    end

    %% Read TTL Timing Information

    ttlFiles = dir(fullfile(datapath, 'TTL*.csv'));
    if ~isempty(ttlFiles)
        fprintf('Loading TTL data from %s.\n', ttlFiles(1).name);
        TTLinfo = readmatrix(fullfile(ttlFiles(1).folder, ttlFiles(1).name));
    else
        error('No TTL recording found. Please check the datapath.');
    end

    %% Read NIDAQ Logfile

    nidaqFiles = {'NIDAQ.csv', 'DAQ.csv'};
    NIDAQInfo = [];
    for i = 1:length(nidaqFiles)
        nidaqPath = fullfile(datapath, nidaqFiles{i});
        if exist(nidaqPath, 'file')
            fprintf('Loading NIDAQ logfile from %s.\n', nidaqFiles{i});
            NIDAQInfo = readtable(nidaqPath);
            break;
        end
    end
    if isempty(NIDAQInfo)
        error('No NIDAQ logfile found. Please check the datapath.');
    end

    %% Initialize PDI Structure

    PDI = struct;
    PDI.Dim.nx = BFConfig.Nx;
    PDI.Dim.nz = BFConfig.Nz;
    PDI.Dim.dx = BFConfig.ScaleX;
    PDI.Dim.dz = BFConfig.ScaleZ;
    PDI.Dim.nt = numel(rawPDI) / (BFConfig.Nx * BFConfig.Nz);

    % Reshape raw PDI data into [nz, nx, nt]
    pdi = reshape(rawPDI, [PDI.Dim.nz, PDI.Dim.nx, PDI.Dim.nt]);
    clear rawPDI;

    %% Realign Events Using TTL Information
    %  Reconciles the count of detected TTL pulses and PDI frames by 
    %  truncating whichever array is longer (pdi frames or idx_PDITTL indices).

    idx_PDITTL = find(diff(TTLinfo(:,3)) < 0);
    numidx_PDITTL = numel(idx_PDITTL);
    numPDIframes = size(pdi, 3);

    if numidx_PDITTL < numPDIframes
        pdi(:, :, numidx_PDITTL+1:end) = [];
    elseif numidx_PDITTL > numPDIframes
        idx_PDITTL(numPDIframes+1:end) = [];
    end

    %% Correct for Lagged PDI and Interpolate
    %  Currently breaks, since there are not the original large .bin
    %  in the FUSI_data directory. Therefore timeTagsSec(acceptIndex) is
    %  just a vector of NaN's.
    %  However it should be run anyway since it sets the PDItime variable 
    %  which is used afterwards. 

    try
        [T_pdi_intended, timeTagsSec] = LagAnalysisFusi(fusDatapath);
        close all

        frameInterval = mode(diff(timeTagsSec));
        blockDuration = ceil(1 / frameInterval);
        acceptIndex = true(size(timeTagsSec));

        % Validate block intervals
        for it = 1:numel(timeTagsSec)-blockDuration
            rangeInterval = range(diff(timeTagsSec(it:it+blockDuration)));
            if rangeInterval > 0.01
                acceptIndex(it) = false;
            end
        end
        for it = numel(timeTagsSec)-blockDuration:numel(timeTagsSec)
            rangeInterval = range(diff(timeTagsSec(it-blockDuration:it)));
            if rangeInterval > 0.01
                acceptIndex(it) = false;
            end
        end
        
        % PDItime = TTL time when the fusi frames are acquired.
        % fusi acquisition starts at PDItime(1)
        PDItime = TTLinfo(idx_PDITTL(1), 1) + timeTagsSec(acceptIndex);
        pdi = pdi(:, :, acceptIndex);
    catch
        % If no IQ data exists
        PDItime = TTLinfo(idx_PDITTL, 1);
        blockDuration = mode(diff(PDItime));
    end


    %% Remove All Frames Before Experiment Start & Re-zero Time
    
    % Shift fUSI timestamps by +1 TR (blockDuration) so timestamps represent frame completion
    % (TTL pulse marks frame acquisition start)
    PDItime = PDItime + blockDuration;
    
    % Find NIDAQ start trigger (rising edge in column 6, fallback to col 5)
    idx_NIDAQ_start = find(diff(TTLinfo(:,6)) > 0, 1, 'first');
    if isempty(idx_NIDAQ_start)
        idx_NIDAQ_start = find(diff(TTLinfo(:,5)) > 0, 1, 'first');
    end
    
    if isempty(idx_NIDAQ_start)
        error('No NIDAQ start trigger found in TTLinfo (cols 5/6).');
    end
    
    % Extract absolute start time before modifying TTLinfo
    duration_before_NIDAQ_start = TTLinfo(idx_NIDAQ_start, 1);
    
    % Remove TTL records prior to NIDAQ start
    TTLinfo(1:idx_NIDAQ_start-1, :) = [];
    
    % Shift time vectors so t = 0 corresponds to NIDAQ start
    PDItime = PDItime - duration_before_NIDAQ_start;
    TTLinfo(:,1) = TTLinfo(:,1) - duration_before_NIDAQ_start;
    
    % Discard any fUSI frames acquired prior to t = 0
    validFrames = (PDItime >= 0);
    pdi(:, :, ~validFrames) = [];
    PDItime(~validFrames)   = [];
    
    % Update PDI structure metadata
    PDI.time = PDItime;
    PDI.Dim.dt = blockDuration;
    PDI.Dim.nt = numel(PDItime); % Keep frame count consistent after trimming

    % Review the TTLinfo after removing the time before NIDAQ starts
    % (plot only columns with some information i.e. std ~= 0)
    varyingCols = find(std(TTLinfo) > 0);
    
    figure('Name', 'TTL Channels');
    for i = 1:numel(varyingCols)
        colIdx = varyingCols(i);
        subplot(numel(varyingCols), 1, i);
        plot(TTLinfo(:, 1), TTLinfo(:, colIdx)); 
        title(sprintf('TTL Column %d', colIdx));
        xlabel('Time (s)');
        grid on;
    end




    %% Read Experiment Event Information

    paradigm = '';

    % DropletStimulation
    if exist(fullfile(datapath, 'DropletStimulation.csv'), 'file')
        paradigm = 'DROPLET';
        fprintf('Droplet stimulation found.\n');
        PDI.stimInfo = parse_DROPLET(datapath, TTLinfo, NIDAQInfo);
    end


    % FUStimulation (focused ultrasound)
    if exist(fullfile(datapath, 'FUStimulation.csv'), 'file')
        paradigm = 'FUStimulation';
        fprintf('FUS stimulation found.\n');
        PDI.stimInfo = parse_FUStimulation(datapath, TTLinfo);
    end


    % ShockStimulation
    if exist(fullfile(datapath, 'ShockStimulation.csv'), 'file')
        paradigm = 'ShockStimulation';
        fprintf('Shock stimulation found.\n');
        PDI.stimInfo = parse_ShockStimulation(datapath, TTLinfo);
    end


    % VisualStimulation
    if exist(fullfile(datapath, 'VisualStimulation.csv'), 'file')
        paradigm = 'VisualStimulation';
        fprintf('Visual stimulation found.\n');
        PDI.stimInfo = parse_VisualStimulation(datapath, TTLinfo, NIDAQInfo);
    end


    % AudioStimulation
    if exist(fullfile(datapath, 'AudioStimulation.csv'), 'file')
        paradigm = 'AudioStimulation';
        fprintf('Auditory stimulation found.\n');
        PDI.stimInfo = parse_AudioStimulation(datapath, TTLinfo, NIDAQInfo);
    end


    %% BEHAVIOURAL MEASUREMENTS

    % Pupil Camera Data
    if exist(fullfile(datapath, 'pupil_camera.csv'), 'file')
        fprintf('Loading pupil camera timestamp from pupil_camera.csv.\n');
        pupilCamData = readmatrix(fullfile(datapath, 'pupil_camera.csv'));
        pupilCamTime = pupilCamData(:,1) - NIDAQInfo.time(1);
    else
        pupilCamTime = [];
        warning('No video timestamp of flir_camera found!');
    end


    % Running Wheel Data
    if exist(fullfile(datapath, 'RunningWheel.csv'), 'file')
        fprintf('Running wheel data found.\n');
        wheelInfo = readtable(fullfile(datapath, 'RunningWheel.csv'));
        wheelInfo.time = wheelInfo.time - NIDAQInfo.time(1);
        % Uncomment below to compute wheel speed aligned with PDI time
        % wheelSpeed = interp1(wheelInfo.time, abs(wheelInfo.wheelspeed), PDItime, 'nearest', 'extrap');
    else
        wheelInfo = [];
        warning('No running wheel data found!');
    end


    % GSensor Data
    if exist(fullfile(datapath, 'GSensor.csv'), 'file')
        fprintf('G sensor data found.\n');
        gsensorInfo = readtable(fullfile(datapath, 'GSensor.csv'));
        gsensorInfo.time = gsensorInfo.time - NIDAQInfo.time(1);
        % Uncomment below to compute motion aligned with PDI time
        % gmotion.x = interp1(gsensorInfo.time, abs(gsensorInfo.x), PDItime, 'nearest', 'extrap');
        % gmotion.y = interp1(gsensorInfo.time, abs(gsensorInfo.y), PDItime, 'nearest', 'extrap');
        % gmotion.z = interp1(gsensorInfo.time, abs(gsensorInfo.z), PDItime, 'nearest', 'extrap');
    else
        gsensorInfo = [];
        warning('No GSensor data found!');
    end

    


    %% Assign Data to PDI Structure

    PDI.PDI = pdi;
    % PDI.pupil.pupilTime = pupilCamTime;
    % PDI.wheelInfo = wheelInfo;
    % PDI.gsensorInfo = gsensorInfo;
    PDI.savepath = savepath;


    % Save also the CROPPED TTLinfo
    PDI.TTLinfo_CROPPED = TTLinfo;

    %% Save PDI Structure

    % Ensure the save directory exists
    if ~exist(savepath, 'dir')
        mkdir(savepath);
    end

    % Save the PDI structure
    matFilePath = fullfile(savepath, 'PDI.mat');
    save(matFilePath, 'PDI');
    fprintf('Data is saved to: %s\n', matFilePath);

    % Uncomment below to save in MATLAB v7 format for compatibility with scipy.io.loadmat
    % save(fullfile(savepath, 'pyPDI.mat'), '-struct', 'PDI', '-v7');

    %% Verification plot

    switch paradigm
        case 'DROPLET'
            verify_DROPLET(savepath);

        case 'VisualStimulation'
            fprintf('verification plot not available for %s\n', paradigm);
    
        case {'FUStimulation', 'ShockStimulation', 'AudioStimulation'}
            fprintf('verification plot not available for %s\n', paradigm);    
    end

end
