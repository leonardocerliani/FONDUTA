%% First steps with the FONDUTA package
LC 2026-10-01


%% Add FONDUTA path

% Whenever we want to use some of the fonduta utilities, we need to add the 
% full path at the top of the matlab script where we will be working. 
% If fonduta is in `/data00/FONDUTA`, we will have:

fonduta_path='/data00/FONDUTA';
addpath(genpath(fonduta_path));

%% Functional reconstruction

% The following opens a UI where you should select the run-XXXXXX directory
% where the files from the fUSI scan are located in the Data_collection
% folder
fonduta.reconstruction.functional_reconstruction()

% You can also pass the data collection path directly, e.g.
functional_COLLECTION_folder='/data03/fUSIHarmAversion/Data_collection/sub-mockexperiment/ses-999999/run-155150-func'
fonduta.reconstruction.functional_reconstruction(functional_COLLECTION_folder)

% Once reconstructed, an interactive plot with the mean time course over
% the entire image, together with markers for the events, will be
% displayed. Currently this is available only for the droplet paradigm.
% To review this plot from the generated PDI.mat in the Data_analysis
% folder
functional_ANALYSIS_folder=strrep(functional_COLLECTION_folder, ...
    'Data_collection', 'Data_analysis')

fonduta.reconstruction.verify_DROPLET(functional_ANALYSIS_folder);


%% Loading and viewing the allen atlas

% Since loading the atlas is a common operation, there is a specific 
% function for that:
atlas = fonduta.atlas.load_atlas();

% The atlas can be inspected with the following:
fonduta.viz.view_atlas()

% USE THE MOUSE WHEEL OR THE TRACK PAD TO SCROLL THROUGH SLICES

% It is possible to load an overlay, but for that we first need to
% transform the image into the allen space and save it as a .mat file
% (see below for transformation).
% Here we can try simply to save the vascular from the allen into a .mat
% file and then you can load it with the 'Load Overlay' button in the app
vascular = atlas.Vascular;
save('vascular.mat',"vascular");



%% Visualization of registered volume

% This assumes that the anatomic.mat file has already been reconstructed
% and registered to the allen atlas, producing a transformation.mat file.

% The following lauches a UI asking to select the anatomic.mat you want to
% inspect side by side with the allen atlas. Internally, it applies the
% transformation to the anatomic.mat (see also below how to apply the 
% transformation manually)
fonduta.viz.view_registration(atlas);


%% Transformation into allen space

% If we want to load a slice/volume onto the allen atlas, we must first
% transform it

anat_path = '/data06/fUSIMethodsPaper/Data_analysis/sub-methods01/ses-231218/run-160708';

anatomic = load(fullfile(anat_path, 'anatomic.mat')).anatomic;
transformation = load(fullfile(anat_path, 'transformation.mat')).Transf;

anatomic_in_atlas = fonduta.atlas.individual2atlas(anatomic, atlas, transformation);

fonduta.viz.view_registration(atlas, anatomic_in_atlas)

