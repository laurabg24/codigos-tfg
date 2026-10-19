%% OCT phantom analysis - ROI-only transformation, no background correction
% Metrics:
% MPI, CR, Skewness, Rayleigh sigma,
% Gamma shape/scale, Nakagami mu/omega, Burr k/scale,
% KS distance from Rayleigh, MSE distance from Rayleigh
%
% Update (17/06/2026) v4:
% The full image I1 is kept in the original 0-255 scale for display and ROI selection.
% The nonlinear/RMS transformation is applied to the extracted ROI (aim: eliminate dependance on intensity and focus solely on distribution shape)
% No background subtraction or SNR correction is applied.

% Update (24/06/2026) v5:
% burr equation updated
% add rayleigh parameter
% Update (29/06/2026) v6:
% stores ROIs used for speckle metrics

%NOTE: before running it again make it store number of b-scans!!!!!!!


clear; clc; close all;

%% USER SETTINGS
inputFolder = 'C:\Users\Laura\Desktop\Cosas de Laura\documentos escolares Laura UHUH\tfg\imagenes tfg estas son las buenas\phantom 12\phantom 12 fotos exportadas';
outputExcel = fullfile(inputFolder, 'test.xlsx'); % change here excel file name

fileExt = '*.bmp';

%halfWidth = 125; %if 1536 A-scans 
halfWidth = 1500; %if 12288 A-scans
roiHeight = 50;

% 0 = no nonlinear transform; 1 = inverse log-like transform + RMS normalization
nl_transform_type = 1;

%% Get file list
files = dir(fullfile(inputFolder, fileExt));

if isempty(files)
    error('No files found in folder: %s', inputFolder);
end

%% Define output columns
baseNames = { ...
    'filename', ...
    'phantom_id', ...
    'acq_time', ...
    'roi_x', 'roi_y_top', 'roi_y_bottom', 'roi_x_fin', 'roi_y_fin', ...
    'depth_top_layer', 'depth_bottom_layer'};

speckleNames = { ...
    'MPI', ...
    'CR', ...
    'Skew', ...
    'Kurt', ...
    'Rayleigh_sigma_BD', ...
    'Rayleigh_sigma_Fit', ...
    'gam_shape', ...
    'gam_scale', ...
    'Nakagami_mu', ...
    'Nakagami_omega', ...
    'Burr_b', ...
    'Burr_scale', ...
    'KS_Rayleigh_BD', ...
    'KS_Rayleigh_Fit', ...
    'MSE_Rayleigh_BD', ...
    'MSE_Rayleigh_BD_shapeNorm', ...
    'MSE_Rayleigh_Fit', ...
    'MSE_Rayleigh_Fit_shapeNorm'};

varNames = [baseNames speckleNames];
results = cell(600, numel(varNames)); %600 it's an arbitrary number of rows

stepSize = 1;
row_excel = 2; %row_excel starts in 2 bc array2table duplicates the variable names
counter_up = 1; %counter marks what range of data should we graphic
counter_down = 1;

y_inter_zona = [0,0]; 
%y_inter_zona(1,1) indicates when the ROI first touches the interphase
%y_inter_zona(1,2) indicates when the ROI fully surpasses the interphase


%% Loop through images
%si quiero analizar solo 3 imágenes por ejemplo, poner k = 1:3
for k = 1:numel(files)

    fname = files(k).name;
    fpath = fullfile(files(k).folder, fname);

    fprintf('\nProcessing image %d / %d: %s\n', k, numel(files), fname);

    %% Read image
    I = imread(fpath);

    if ndims(I) == 3
        I1 = I(:,:,1);
    else
        I1 = I;
    end

    I1 = double(I1);
    [nRows, nCols] = size(I1);

    %% Extract phantom number and acquisition time
    phantomToken = regexp(fname, 'Ph(\d+)_', 'tokens', 'once');
    timeToken    = regexp(fname, '_(\d{6})_', 'tokens', 'once');

    if isempty(phantomToken)
        phantom_id = NaN;
    else
        phantom_id = str2double(phantomToken{1});
    end

    if isempty(timeToken)
        acq_time = "";
    else
        acq_time = string(timeToken{1});
    end

    %% Show original image and ask user to click ROI
    hFig = figure('Name', fname, 'NumberTitle', 'off');
    imagesc(I1);
    colormap gray;
    hold on;
    title({'Click ROI'; fname}, 'Interpreter', 'none');

    [x1, y1] = ginput(1);
    plot(x1, y1, 'ro', 'MarkerSize', 10, 'LineWidth', 1.5);

    x1 = round(x1);
    y1 = round(y1);

    y_displacement = y1;

    %[x_inter, y_inter] is the interphase point 
    [~, y_inter] = ginput(1);
    x_inter = x1;
    plot(x_inter, y_inter, 'ro', 'MarkerSize', 10, 'LineWidth', 1.5);

    x_inter = round(x_inter);
    y_inter = round(y_inter);

    %[x2, y2] is the last point analyzed
    [x2, y2] = ginput(1);
    plot(x2, y2, 'ro', 'MarkerSize', 10, 'LineWidth', 1.5);

    x2 = round(x2);
    y2 = round(y2);
    
    %% Define ROI on the original image
    x1_left   = max(1, x1 - halfWidth);
    x1_right  = min(nCols, x1 + halfWidth);
    y1_top    = max(1, y1);
    y1_bottom = min(nRows, y1 + roiHeight - 1);

    
    while y2 > y1_bottom

        c = 1;

        ROI_raw = I1(y1_top:y1_bottom, x1_left:x1_right);
    
        %% Draw ROI
        rectangle('Position', ...
            [x1_left, y1_top, x1_right - x1_left + 1, y1_bottom - y1_top + 1], ...
            'EdgeColor', 'r', 'LineWidth', 1.5);
    
        drawnow;
    
        %% Transform only the ROI
        ROI = ROI_transform(ROI_raw, nl_transform_type);
    
    
        %% Save transformed ROI matrix used for speckle metrics
        roiMatrixFolder = fullfile(inputFolder, 'ROI_matrices');
        
        if ~exist(roiMatrixFolder, 'dir')
            mkdir(roiMatrixFolder);
        end
        
        [~, baseName, ~] = fileparts(fname);
        
        ROI_filename = fullfile(roiMatrixFolder, [baseName '_ROI.mat']);
        
        save(ROI_filename, 'ROI', 'ROI_raw', ...
            'fname', 'x1', 'y1', ...
            'x1_left', 'x1_right', 'y1_top', 'y1_bottom', ...
            'nl_transform_type');
    
    
    
        %% Calculate speckle metrics from the transformed ROI only
        metrics = calculate_speckle_metrics(ROI(:));
    
        %% Store results 
        results{row_excel,c} = fname; c = c + 1;
        results{row_excel,c} = phantom_id; c = c + 1;
        results{row_excel,c} = char(acq_time); c = c + 1;
        results{row_excel,c} = x1; c = c + 1;
        results{row_excel,c} = y1_top - y_displacement; c = c + 1;
        results{row_excel,c} = y1_bottom - y_displacement; c = c + 1;
        results{row_excel,c} = x2; c = c + 1;
        results{row_excel,c} = y2 - y_displacement; c = c + 1;
        results{row_excel,c} = y_inter - y1; c = c + 1; %depth_top_layer (pix)
        results{row_excel,c} = y2 - y_inter; c = c + 1; %depth_bottom_layer (pix)

        
        for jj = 1:numel(metrics)
            results{row_excel,c} = metrics(jj);
            c = c + 1;
        end

        row_excel = row_excel + 1;

        %% Optionally save ROI image with selected rectangle
        roiFolder = fullfile(inputFolder, 'ROI_images');
        if ~exist(roiFolder, 'dir')
            mkdir(roiFolder);
        end
    
        % [~, baseName, ~] = fileparts(fname);
        % outImageName = fullfile(roiFolder, [baseName '_ROI.jpg']);
        % exportgraphics(hFig, outImageName, 'Resolution', 300);

        if y1_bottom > y_inter && y_inter_zona(1,1) == 0
            y_inter_zona(1,1) = y1_top - y_displacement;
        end

        if y1_top > y_inter && y_inter_zona(1,2) == 0
            y_inter_zona(1,2) = y1_bottom - y_displacement;
        end

        y1_bottom = y1_bottom + stepSize;
        y1_top = y1_top + stepSize;

        counter_down = counter_down + 1;

    end

    close(hFig);

    %% Graphics
    results_to_numbers = cell2mat(results(counter_up:counter_down,4:end));
    
    mark_interphase = y_inter - y_displacement;
    
    figure;
    hold on;
    subplot(3,2,1); plot(results_to_numbers(:,2), results_to_numbers(:,8), '*'); xline(mark_interphase, 'r'); xline(y_inter_zona(1,1), 'g'); xline(y_inter_zona(1,2), 'g'); title("MPI"); xlabel("y_ top");
    subplot(3,2,2); plot(results_to_numbers(:,2), results_to_numbers(:,9), '*'); xline(mark_interphase, 'r'); xline(y_inter_zona(1,1), 'g'); xline(y_inter_zona(1,2), 'g'); title("CR"); xlabel("y_ top");
    subplot(3,2,3); plot(results_to_numbers(:,2), results_to_numbers(:,14), '*'); xline(mark_interphase, 'r'); xline(y_inter_zona(1,1), 'g'); xline(y_inter_zona(1,2), 'g'); title("gam_ shape"); xlabel("y_ top");
    subplot(3,2,4); plot(results_to_numbers(:,2), results_to_numbers(:,15), '*'); xline(mark_interphase, 'r'); xline(y_inter_zona(1,1), 'g'); xline(y_inter_zona(1,2), 'g'); title("gam_ scale"); xlabel("y_ top");
    subplot(3,2,5); plot(results_to_numbers(:,2), results_to_numbers(:,20), '*'); xline(mark_interphase, 'r'); xline(y_inter_zona(1,1), 'g'); xline(y_inter_zona(1,2), 'g'); title("KS_ Rayleigh_ BD"); xlabel("y_ top");
    sgtitle(["Métricas", strrep(fname, '_', '\_')]);

    
    counter_up = counter_down + 1;
    counter_down = counter_down + 1;
    
end

%% Convert to table and save
T = array2table(results);
writetable(T, outputExcel);

T_header = array2table(varNames, VariableNames = [baseNames speckleNames]);
writetable(T_header, outputExcel);

fprintf('\nAnalysis completed.\nResults saved to:\n%s\n', outputExcel);


%% ============================================================
% LOCAL FUNCTIONS
% ============================================================

function ROI = ROI_transform(ROI, nl_transform_type)

    % 0-1 normalization
    %ROI = ROI / max(ROI(:));
    ROI = ROI/255;
    
    % normalization by RMS after non-linear transform
    if nl_transform_type == 1 %log transformation            
        ROI = 10.^ROI;
        ROI = (ROI-1)/(10-1); % scaling log normalization 0-1
    
    else
        % we leave ROI as it is
    end   

    ROI = ROI / sqrt(mean(ROI.^2, "all")); %RMS normalization to remove overall signal intensity while preserving the distribution shape, allowing direct comparison with a standardized Rayleigh model (sigma = sqrt(2)/2).

end


function metrics = calculate_speckle_metrics(pix)

    pix = double(pix(:));
    pix = pix(~isnan(pix) & isfinite(pix));

    % Speckle intensity/amplitude distribution fits require positive values.
    pix_fit = pix(pix > eps);

    if numel(pix_fit) < 10
        metrics = NaN(1, 12);
        return
    end

    %% Basic statistics
    MPI = mean(pix_fit);

    if MPI > 0
        CR = std(pix_fit) / MPI;
    else
        CR = NaN;
    end

    Skew = skewness(pix_fit);
    Kurt = kurtosis(pix_fit);

    %% Rayleigh parameter and KS distance from Rayleigh CDF
    try
        sigma_ray_BD  = sqrt(2)/2;
        sigma_ray_Fit = sqrt(mean(pix_fit.^2) / 2);
    catch
        sigma_ray_BD = NaN;
        sigma_ray_Fit = NaN;
    end

    try
        [F_emp, x_emp] = ecdf(pix_fit);

        %KS to fixed benchmark Rayleigh
        
        if sigma_ray_BD > 0 && isfinite(sigma_ray_BD)
            cdfR = 1 - exp(-x_emp.^2 ./ (2 * sigma_ray_BD^2));
            KS_Rayleigh_BD = max(abs(F_emp - cdfR));
        else
            KS_Rayleigh_BD = NaN;
        end

        %KS to FITTED benchmark Rayleigh

        if sigma_ray_Fit > 0 && isfinite(sigma_ray_Fit)
            cdfR = 1 - exp(-x_emp.^2 ./ (2 * sigma_ray_Fit^2));
            KS_Rayleigh_Fit = max(abs(F_emp - cdfR));
        else
            KS_Rayleigh_Fit = NaN;
        end        


    catch
        KS_Rayleigh_BD = NaN;
        KS_Rayleigh_Fit = NaN;

    end

    %% MSE distance between normalized KDE and normalized Rayleigh PDF
    try
        % KDE on positive support
        [f_kde, x_kde] = ksdensity(pix_fit, 'Support', 'positive');
    
        % Optional boundary correction following Niemczyk & Iskander
        idx_kde = x_kde >= 0.05;
    
        x_eval = x_kde(idx_kde);
        f_eval = f_kde(idx_kde);

        % ------------------------------------------------------------
        % 1) Benchmark Rayleigh PDF: sigma = sqrt(2)/2
        % ------------------------------------------------------------
        pdfR_BD = (x_eval ./ sigma_ray_BD^2) .* ...
                  exp(-x_eval.^2 ./ (2 * sigma_ray_BD^2));
    
        % 1) Bibliographic MSE: KDE vs benchmark PDF
        MSE_Rayleigh_BD = mean((f_eval - pdfR_BD).^2);
    
        if max(pdfR_BD) > 0 && max(f_eval) > 0
            pdfR_BD_n = pdfR_BD / max(pdfR_BD);
            f_n       = f_eval  / max(f_eval);
    
            MSE_Rayleigh_BD_shapeNorm = mean((f_n - pdfR_BD_n).^2);
        else
            MSE_Rayleigh_BD_shapeNorm = NaN;
        end
    
        % ------------------------------------------------------------
        % 2) Fitted Rayleigh PDF: sigma estimated from the same ROI
        % ------------------------------------------------------------
        pdfR_Fit = (x_eval ./ sigma_ray_Fit^2) .* ...
                   exp(-x_eval.^2 ./ (2 * sigma_ray_Fit^2));
    
        MSE_Rayleigh_Fit = mean((f_eval - pdfR_Fit).^2);
    
        if max(pdfR_Fit) > 0 && max(f_eval) > 0
            pdfR_Fit_n = pdfR_Fit / max(pdfR_Fit);
            f_n        = f_eval  / max(f_eval);
    
            MSE_Rayleigh_Fit_shapeNorm = mean((f_n - pdfR_Fit_n).^2);
        else
            MSE_Rayleigh_Fit_shapeNorm = NaN;
        end
  
    catch
        MSE_Rayleigh_BD = NaN;
        MSE_Rayleigh_BD_shapeNorm = NaN;
        MSE_Rayleigh_Fit = NaN;
        MSE_Rayleigh_Fit_shapeNorm = NaN;
    end


    %% Gamma fit
    try
        phat = gamfit(pix_fit);
        gam_shape = phat(1);
        gam_scale = phat(2);
    catch
        gam_shape = NaN;
        gam_scale = NaN;
    end

    %% Nakagami fit
    try
        pd_n = fitdist(pix_fit, 'Nakagami');
        pv = pd_n.ParameterValues;
        Nakagami_mu = pv(1);
        Nakagami_omega = pv(2);
    catch
        Nakagami_mu = NaN;
        Nakagami_omega = NaN;
    end

    %% Burr XII fit, with second shape parameter fixed to c = 2
    try 
            burrLL = @(p) (-sum(log((2 .* pix_fit .* (p(1)-1) ./ p(2).^2) .* ...
                        (1 + (pix_fit ./ p(2)).^2).^(-p(1)) )));

            %Valores iniciales de búsqueda
            p0 = [2, mean(pix_fit)];

            pMLE = fminsearch(burrLL,p0, optimset('Display','off'));
            
            %Comprobación de validez

            if pMLE(1) <= 1 || pMLE(2) <= 0 || any(~isfinite(pMLE))
                Burr_b         = NaN;
                Burr_scale    = NaN;
            else
                Burr_b        = pMLE(1);
                Burr_scale     = pMLE(2);
            end
    
            catch
                Burr_b = NaN;
                Burr_scale = NaN;
            end 

    metrics = [ ...
        MPI, ...
        CR, ...
        Skew, ...
        Kurt, ...
        sigma_ray_BD, ...
        sigma_ray_Fit, ...
        gam_shape, ...
        gam_scale, ...
        Nakagami_mu, ...
        Nakagami_omega, ...
        Burr_b, ...
        Burr_scale, ...
        KS_Rayleigh_BD, ...
        KS_Rayleigh_Fit, ...
        MSE_Rayleigh_BD, ...
        MSE_Rayleigh_BD_shapeNorm, ...
        MSE_Rayleigh_Fit, ...
        MSE_Rayleigh_Fit_shapeNorm];

end
