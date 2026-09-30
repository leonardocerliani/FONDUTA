function view_registration(atlas, image)
%VIEW_REGISTRATION Interactive atlas registration viewer (coronal only).
%
%   fonduta.viz.view_registration(atlas, image)
%   fonduta.viz.view_registration(atlas) % Prompts uigetdir to load & transform anatomic image
%
%   Displays:
%       Left  : atlas
%       Right : registered image
%
%   Controls:
%       Mouse click  : move crosshairs
%       Mouse wheel  : change coronal slice
%       Radio buttons: select atlas, lines, colormap, or clarity boost

%% Load / Transform Image if Not Provided

if nargin < 2 || isempty(image)
    % Prompt user to select anatomic.mat directly so files are visible
    [fileName, anat_path] = uigetfile('anatomic.mat', ...
        'Select anatomic.mat (must be in folder with transformation.mat)');
    
    if isequal(fileName, 0) || isequal(anat_path, 0)
        disp('User canceled file selection.');
        return;
    end
    
    fileAnat = fullfile(anat_path, 'anatomic.mat');
    fileTrans = fullfile(anat_path, 'transformation.mat');
    
    if ~exist(fileTrans, 'file')
        error('Selected directory does not contain "transformation.mat".');
    end
    
    % Load anatomic data and transformation matrix
    anatomic = load(fileAnat).anatomic;
    transformation = load(fileTrans).Transf;
    
    % Transform individual image to atlas space
    image = fonduta.atlas.individual2atlas(anatomic, atlas, transformation);
end


%% Initial settings

atlasType = 'Histology';
atlasData = atlas.Histology;

showRegions = true;

crosshair = round(size(image)/2);

slice = crosshair(2);

% Right image default settings
rightColormap = 'gray';
clarityMode = 'Raw'; % Options: 'Raw', 'Gamma (0.45)'


%% Figure

fig = figure(...
    'Name','Registration Viewer',...
    'Position',[100 100 1600 950],...
    'Color','w',...
    'DefaultAxesFontSize',16,...
    'WindowScrollWheelFcn',@scrollCallback,...
    'WindowButtonDownFcn',@clickCallback);

axLeft = axes(fig,...
    'Position',[0.02 0.20 0.46 0.74]);

axRight = axes(fig,...
    'Position',[0.52 0.20 0.46 0.74]);


%% Controls - Left Side (Atlas & Lines)

bg = uibuttongroup(fig,...
    'Units','normalized',...
    'Position',[0.02 0.02 0.25 0.06],...
    'SelectionChangedFcn',@atlasSelection);

uicontrol(bg,...
    'Style','radiobutton',...
    'String','Histology',...
    'Units','normalized',...
    'Position',[0 0 1/3 1],...
    'FontSize',13);

uicontrol(bg,...
    'Style','radiobutton',...
    'String','Vascular',...
    'Units','normalized',...
    'Position',[1/3 0 1/3 1],...
    'FontSize',13);

uicontrol(bg,...
    'Style','radiobutton',...
    'String','Regions',...
    'Units','normalized',...
    'Position',[2/3 0 1/3 1],...
    'FontSize',13);

bgLines = uibuttongroup(fig,...
    'Units','normalized',...
    'Position',[0.28 0.02 0.15 0.06],...
    'SelectionChangedFcn',@lineSelection);

uicontrol(bgLines,...
    'Style','radiobutton',...
    'String','Lines ON',...
    'Units','normalized',...
    'Position',[0 0 0.5 1],...
    'Value',1,...
    'FontSize',13);

uicontrol(bgLines,...
    'Style','radiobutton',...
    'String','Lines OFF',...
    'Units','normalized',...
    'Position',[0.5 0 0.5 1],...
    'FontSize',13);


%% Controls - Right Side (Colormap & Clarity Boost)

bgCmap = uibuttongroup(fig,...
    'Units','normalized',...
    'Position',[0.52 0.02 0.18 0.06],...
    'SelectionChangedFcn',@cmapSelection);

uicontrol(bgCmap,...
    'Style','radiobutton',...
    'String','gray',...
    'Units','normalized',...
    'Position',[0 0 1/3 1],...
    'Value',1,...
    'FontSize',13);

uicontrol(bgCmap,...
    'Style','radiobutton',...
    'String','hot',...
    'Units','normalized',...
    'Position',[1/3 0 1/3 1],...
    'FontSize',13);

uicontrol(bgCmap,...
    'Style','radiobutton',...
    'String','jet',...
    'Units','normalized',...
    'Position',[2/3 0 1/3 1],...
    'FontSize',13);

bgClarity = uibuttongroup(fig,...
    'Units','normalized',...
    'Position',[0.71 0.02 0.27 0.06],...
    'SelectionChangedFcn',@claritySelection);

uicontrol(bgClarity,...
    'Style','radiobutton',...
    'String','Raw',...
    'Units','normalized',...
    'Position',[0 0 0.5 1],...
    'Value',1,...
    'FontSize',13);

uicontrol(bgClarity,...
    'Style','radiobutton',...
    'String','Gamma (0.45)',...
    'Units','normalized',...
    'Position',[0.5 0 0.5 1],...
    'FontSize',13);


%% Info Text

txt = uicontrol(fig,...
    'Style','text',...
    'Units','normalized',...
    'Position',[0.02 0.10 0.96 0.04],...
    'BackgroundColor','w',...
    'FontSize',16,...
    'HorizontalAlignment','left');


%% Images

leftImage = imagesc(axLeft, extractSlice(atlasData, false));
rightImage = imagesc(axRight, extractSlice(image, true));

axis(axLeft,'image')
axis(axRight,'image')

axis(axLeft,'off')
axis(axRight,'off')

colormap(axLeft,gray)
colormap(axRight,rightColormap)

hold(axLeft,'on')
hold(axRight,'on')


%% Handles

regionHandlesLeft=[];
regionHandlesRight=[];

crossLeft=[];
crossRight=[];

updateDisplay();


%% ============================================================
% CALLBACKS
% ============================================================

function scrollCallback(~,event)
    slice = slice + event.VerticalScrollCount;
    slice = max(1,min(slice,size(image,2)));
    crosshair(2) = slice;
    updateDisplay();
end

function clickCallback(~,~)
    ax = gca;
    cp = ax.CurrentPoint;

    z = round(cp(1,1));   % columns of imagesc = dimension 3
    x = round(cp(1,2));   % rows of imagesc    = dimension 1

    if x < 1 || z < 1
        return
    end

    crosshair = [x slice z];
    updateDisplay();
end

function atlasSelection(~,event)
    atlasType = event.NewValue.String;

    switch atlasType
        case 'Histology'
            atlasData = atlas.Histology;
        case 'Vascular'
            atlasData = atlas.Vascular;
        case 'Regions'
            atlasData = atlas.Regions;
    end

    updateDisplay();
end

function lineSelection(~,event)
    showRegions = strcmp(event.NewValue.String,'Lines ON');
    updateDisplay();
end

function cmapSelection(~,event)
    rightColormap = event.NewValue.String;
    updateDisplay();
end

function claritySelection(~,event)
    clarityMode = event.NewValue.String;
    updateDisplay();
end


%% ============================================================
% DISPLAY
% ============================================================

function updateDisplay()

    leftImage.CData = extractSlice(atlasData, false);
    rightImage.CData = extractSlice(image, true);

    switch atlasType
        case 'Regions'
            colormap(axLeft,atlas.infoRegions.rgb)
            caxis(axLeft,[1 509])
            leftImage.Interpolation = 'nearest';

        case 'Histology'
            colormap(axLeft,gray)
            caxis(axLeft,...
                [double(min(atlas.Histology(:))) ...
                double(max(atlas.Histology(:)))])

        case 'Vascular'
            colormap(axLeft,gray)
            clim = prctile(double(atlas.Vascular(:)),[1 99]);
            caxis(axLeft,clim)
    end

    % Apply selected colormap to right image
    colormap(axRight, rightColormap)

    % Dynamic axis limits depending on boost mode
    if strcmp(clarityMode, 'Raw')
        caxis(axRight, [double(min(image(:))) double(max(image(:)))])
    else
        caxis(axRight, [0 1])
    end

    updateRegionLines();
    updateCrosshair();
    updateRegionInfo();

    drawnow;
end


%% ============================================================
% REGION LINES
% ============================================================

function updateRegionLines()

    delete(regionHandlesLeft)
    delete(regionHandlesRight)

    regionHandlesLeft = [];
    regionHandlesRight = [];

    if ~showRegions
        return
    end

    L = atlas.Lines.Cor{slice};

    for i = 1:length(L)
        xy = L{i};

        regionHandlesLeft(end+1) = plot(axLeft,...
            xy(:,2),...
            xy(:,1),...
            'w',...
            'LineWidth',1);

        regionHandlesRight(end+1) = plot(axRight,...
            xy(:,2),...
            xy(:,1),...
            'w',...
            'LineWidth',1);
    end
end


%% ============================================================
% CROSSHAIR
% ============================================================

function updateCrosshair()

    delete(crossLeft)
    delete(crossRight)

    crossLeft = [];
    crossRight = [];

    x = crosshair(1);   
    z = crosshair(3);   

    crossLeft(1) = xline(axLeft,z,'r','LineWidth',1.5);
    crossLeft(2) = yline(axLeft,x,'r','LineWidth',1.5);

    crossRight(1) = xline(axRight,z,'r','LineWidth',1.5);
    crossRight(2) = yline(axRight,x,'r','LineWidth',1.5);
end


%% ============================================================
% REGION INFORMATION
% ============================================================

function updateRegionInfo()

    voxelText = sprintf('Voxel [%d %d %d]',crosshair);
    regionText = '';

    inside = ...
        crosshair(1)>=1 && crosshair(1)<=size(atlas.Regions,1) && ...
        crosshair(2)>=1 && crosshair(2)<=size(atlas.Regions,2) && ...
        crosshair(3)>=1 && crosshair(3)<=size(atlas.Regions,3);

    if inside
        label = double(atlas.Regions(...
            crosshair(1),...
            crosshair(2),...
            crosshair(3)));

        if label > 0 && label <= numel(atlas.infoRegions.acr)
            acr  = atlas.infoRegions.acr{label};
            name = atlas.infoRegions.name{label};

            regionText = sprintf(...
                '    ID: %d    %s: %s',...
                label,...
                acr,...
                name);
        else
            regionText = '    Background';
        end
    end
    txt.String = [voxelText regionText];
end


%% ============================================================
% SLICE EXTRACTION
% ============================================================

function sliceImg = extractSlice(vol, isRightImage)

    sliceImg = squeeze(vol(:, slice, :));

    if nargin > 1 && isRightImage
        switch clarityMode
            case 'Gamma (0.45)'
                dImg = double(sliceImg);
                dRange = max(dImg(:)) - min(dImg(:));
                if dRange == 0, dRange = 1e-6; end
                sliceImg = ((dImg - min(dImg(:))) / dRange) .^ 0.45;

            case 'Raw'
                % Keep raw voxel values
        end
    end

end

end