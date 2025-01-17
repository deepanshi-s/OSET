close all;
clear;
clc;
resultfname_amp = 'testProcessSeizureEEGPhaseAmplitudeFeaturesXCorrBased_amp.txt';
resultfname_amp_wavelet = 'testProcessSeizureEEGPhaseAmplitudeFeaturesXCorrBased_amp_wavelet.txt';
% this is the same as the previous one; except that the feature vectors are
% kept in the frequency domain (look at F, F1, and F2 and how they are
% transposed). This gives equal number of features for all subjects
% regardless of the number of channels

% parameters
subject = {'Dog_1', 'Dog_2', 'Dog_3', 'Dog_4', 'Dog_5', 'Patient_1', 'Patient_2'};
ffs = 400;
f0 = 60; % powerline frequency Hz
Q = 60; % notch filter Q-factor
% wlens = [1.0 3.0 10.0]; % energy window lengths in seconds
% bins = 0:.01:3;
x = [];
drop = 2000; % the number of samples to exclude from the head and tail of the data during processing
% bins = 256;
nfft = 400;
freqfeatures = 54;
maxnumberofeigs = 15;
% % % SpectralWinLen = 5; % in seconds
% % % SpectralOverlapPercentage = 50; % [0 99]

% preprocessing: resample the data to 120Hz with a polyphase bandpass filter passing [1Hz-55Hz]
load BandpassFilter1Hzto55HzAt400Hz h % load the bandpass filter used for resampling the input data
% h1 = spectrum.welch('Hamming', round(SpectralWinLen*ffs), SpectralOverlapPercentage); % Create a Welch spectral estimator.

for m = 1 : length(subject),
    % search path and subjects
    path = ['E:\Sameni\Projects\Seizure\' subject{m} '\'];
    d = dir([path '*.mat']);
    NumRecords = length(d);
    for k = 1 : NumRecords,
        % clear previous variable to save memory
        if(~isempty(x))
            clear x;
        end
        
        % load data
        load([path d(k).name]);
        reg = regexp(d(k).name, '_');
        varname = [d(k).name(reg(2)+1:reg(4)-1) '_' num2str(str2double(d(k).name(end-7:end-4)))];
        md = d(k).name(reg(2)+1:reg(3)-1);
        if(isequal(md, 'interictal'))
            mode = 1;
        elseif(isequal(md, 'preictal'))
            mode = 2;
        elseif(isequal(md, 'test'))
            mode = 3;
        end
        eval(['data = ' varname '; clear ' varname ';']);
        x = data.data;
        fs = data.sampling_frequency;
        clear data;
        
        % resample data for high sampling rates
        if(fs > ffs)
            x = resample(x', ffs, round(fs))';
            fs = ffs;
        end
        
        % bandpass filter
        x = filter(h, 1, x, [], 2);
        
        % drop transient samples due to filtering
        x = x(:,drop:end-drop);
        
        % normalize channels
        x = (x - mean(x, 2)*ones(1, size(x,2)))./(std(x, [], 2)*ones(1, size(x,2)));
        
        %         xx = xcorr((x.*(ones(size(x,1),1)*hamming(size(x, 2))'))')';%,'unbiased')';
        xx = zeros(size(x,1), size(x,2)*2-1);
        for i = 1:size(x,1),
            xx(i, :) = xcorr(x(i, :)); % ,'coeff'
        end
        
        X = fft(xx, nfft, 2);
        
        Xamp = abs(X);
        %         Xphase = zeros(size(X,1), freqfeatures);
        %         for i = 1:size(x, 1),
        %             %             Xphase(i, :) = phase(X(i, 1:freqfeatures));% - LPFilter(phase(X(i, 1:freqfeatures)), 1.0/fs);
        %             Xphase(i, :) = diff(phase(X(i, [1 1:freqfeatures])));% - LPFilter(phase(X(i, 1:freqfeatures)), 1.0/fs);
        %         end
        %         freq = fs*(0:nfft-1)/nfft;
        
        Famp = Xamp(:, 1:freqfeatures);
        
        C_amp = 20*log10(Famp.'*Famp/size(Famp,1));
        
        L = 4;
        wtype = {'db4','sym5','coif3'};
        waveletfeatures = [];%zeros(1, 4*L*length(wtype));
        for i = 1:length(wtype),
            [C, S] = wavedec2(C_amp, L, wtype{i});
            [Ea, Eh, Ev, Ed] = wenergy2(C, S);
            waveletfeatures = [waveletfeatures log([Ea(:) ; Eh(:) ; Ev(:) ; Ed(:)]')];
            % % %             for LL = 1:L;
            % % %                 A = appcoef2(C, S, wtype{i}, LL);
            % % %                 [H, V, D] = detcoef2('all', C, S, LL);
            % % %                 waveletfeatures((i-1)*4*L + (LL-1)*4 + 1 : (i-1)*4*L + LL*4) = [sqrt(mean(A(:).^2)) ; sqrt(mean(H(:).^2)) ; sqrt(mean(V(:).^2)) ; sqrt(mean(D(:).^2))]';
            % % %             end
        end
        %         C_phase = Xphase.'*Xphase/size(Xphase,1);
        
        %                 f = fs*(0:freqfeatures-1)/nfft;
        %                 figure
        %                 subplot(121);
        %                 surf(f, f, C_amp, 'EdgeColor', 'none');
        %                 axis xy; axis tight; colormap(jet); view(0,90);
        %         hold on
        %         for i = 1:size(x, 1),
        %             plot(freq, 20*log10(Xamp),'b');
        %             plot(freq, 20*log10(X1amp),'r');
        %             plot(freq, 20*log10(X2amp),'g');
        %         end
        %         grid;
        %                 subplot(122);
        %                 surf(f, f, C_phase, 'EdgeColor', 'none');
        %                 axis xy; axis tight; colormap(jet); view(0,90);
        %         hold on
        %         for i = 1:size(x, 1),
        %             plot(freq, Xphase,'b');
        %             plot(freq, X1phase,'r');
        %             plot(freq, X2phase,'g');
        %         end
        %         grid;
        
        feature_amp = C_amp(tril(true(size(C_amp.')))); % take the lower triangular elements of the symmetric matrix
        egs_amp = real(eig(C_amp)); [~, II] = sort(egs_amp, 1, 'descend');
        feature_eigs_amp = 10*log10(egs_amp(II)); % take the eigenvalues of the frequency domain correlation coefficients
        feature_eigs_amp = feature_eigs_amp(1:maxnumberofeigs); % take the first eigenvalues (up to the number of the channels)
        
        %         feature_phase = C_phase(tril(true(size(C_phase.')))); % take the lower triangular elements of the symmetric matrix
        %         egs_phase = real(eig(C_phase)); [~, II] = sort(egs_phase, 1, 'descend');
        %         feature_eigs_phase = 10*log10(egs_phase(II)); % take the eigenvalues of the frequency domain correlation coefficients
        %         feature_eigs_phase = feature_eigs_phase(1:maxnumberofeigs); % take the first eigenvalues (up to the number of the channels)
        
        % write results
        fid_amp = fopen(resultfname_amp,'a');
        fid_amp_wavelet = fopen(resultfname_amp_wavelet,'a');
        fprintf(fid_amp, '%s\t%d\t%d\t%d', d(k).name, m, k, mode);
        fprintf(fid_amp_wavelet, '%s\t%d\t%d\t%d', d(k).name, m, k, mode);
        for i = 1 : length(feature_amp)
            fprintf(fid_amp, '\t%12.8f', feature_amp(i));
        end
        for i = 1 : length(feature_eigs_amp)
            fprintf(fid_amp, '\t%12.8f', feature_eigs_amp(i));
        end
        for i = 1 : length(waveletfeatures)
            fprintf(fid_amp_wavelet, '\t%12.8f', waveletfeatures(i));
        end
        fprintf(fid_amp, '\n');
        fprintf(fid_amp_wavelet, '\n');
        fclose(fid_amp);
        fclose(fid_amp_wavelet);
        disp(['subject: ', d(k).name]);
    end
end

clock