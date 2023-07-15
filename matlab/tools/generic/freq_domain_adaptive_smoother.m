function x_filtered = freq_domain_adaptive_smoother(x, med_half_wlen, filtering_perctile, outlier_neighborhood_percentage, varargin)
% freq_domain_adaptive_smoother - Filters frequency domain signal spikes
% This function filters the input multichannel signal by replacing
%   frequency domain local spikes with the median of the neighborhood
%   frequency components.
%
% Syntax:
%   x_filtered = freq_domain_adaptive_smoother(x, med_half_wlen, filtering_perctile, outlier_neighborhood_percentage, plot_flag)
%
% Inputs:
%   x: Input multichannel signal, where each row represents a channel and
%       each column represents a sample.
%   
%   med_half_wlen: Half-width of the median filter window in frequency
%       samples (integer value). Larger values provide more smoothing but may
%       reduce signal resolution.
%   filtering_perctile (%): Percentile (in range 0 to 100) used to
%       determine the threshold for spectral point filtering. Spectral
%       amplitudes above this percentile are considered for outlier
%       replacement. Suggested range: 5 to 10 (percentiles above this threshold
%       are conditionally smoothed in the frequency domain).
%   outlier_neighborhood_percentage (%): Outlier neighborhood percentage
%       used to determine the outlier threshold. The magnitude difference
%       between the filtered and original Fourier transform is multiplied by
%       this percentage to determine outlier points. Suggested range: 5 to 20
%       (signal dependent).
%   plot_flag (optional): A flag (0 or 1) to indicate whether to plot the
%       results or not. Default is 0 (no plot).
%
% Outputs:
%   x_filtered: Filtered multichannel signal with frequency domain spikes
%   replaced by smoothed values based on the adaptive filtering approach.
%
% Description:
%   The function first applies a Fourier transform on the input
%   multichannel signal 'x'. It then applies a median filter in the
%   frequency domain with a specified half-width to smoothen the Fourier
%   magnitude at each frequency point. Next, it computes the absolute error
%   between the original and smoothed Fourier magnitude and identifies
%   outlier spectral points based on the specified filtering percentile and
%   outlier neighborhood percentage. The function then replaces the outlier
%   spectral points with the smoothed values, preserving the phase
%   information. Finally, an inverse Fourier transform is applied to obtain
%   the filtered multichannel signal in the time domain.
%
% Example:
%   x = randn(8, 1000); % Example input multichannel noise signal
%   med_half_wlen = 5;
%   filtering_perctile = 5;
%   outlier_neighborhood_percentage = 10;
%   plot_flag = 1;
%   x_filtered = freq_domain_adaptive_smoother(x, med_half_wlen, filtering_perctile, outlier_neighborhood_percentage, plot_flag);
%
% Revision History:
%   2023: First release
%
% Reza Sameni, 2009-2023
% The Open-Source Electrophysiological Toolbox
% https://github.com/alphanumericslab/OSET

if nargin > 4 && ~isempty(varargin{1})
    plot_flag = varargin{1};
else
    plot_flag = 0;
end

N = size(x, 1);
T = size(x, 2);
X = fft(x, T, 2); % Fourier transform

X_shifted = fftshift(X, 2); % swap the left and right parts of the spectra (DC is shifted to the center)
X_shifted_abs = abs(X_shifted); % the Fourier transform magnitude

X_shifted_abs_filtered = zeros(size(X_shifted));
% Median filter
for t = 1 : T
    indexes = max(t - med_half_wlen, 1) : min(t + med_half_wlen, T);
    X_shifted_abs_filtered(:, t) = median(X_shifted_abs(:, indexes), 2); % the smoothed magnitude of the Fourier transform
end

% Conditional frequency domain smoothing
original_smoothed_diff = abs(X_shifted_abs - X_shifted_abs_filtered); % absolute error between filtered and original spectral magnitudes
filtering_threshold = prctile(X_shifted_abs, filtering_perctile); % filters only amplitudes above this percentile
I_filtered_indexes = abs(original_smoothed_diff) > outlier_neighborhood_percentage * X_shifted_abs_filtered & X_shifted_abs > filtering_threshold; % spectral points corresponding to the grid

X_shifted_abs_refined = X_shifted_abs;
X_shifted_abs_refined(I_filtered_indexes) = X_shifted_abs_filtered(I_filtered_indexes); % smoothed spectra only replaces outlier spectral points (corresponding to the outliers)

X_abs_refined = ifftshift(X_shifted_abs_refined, 2);
X_abs_refined(:, 2:end) = (X_abs_refined(:, 2:end) + X_abs_refined(:, end:-1:2)) / 2; % make Fourier magnitude even symetric

X_shifted_phase = angle(X); % the Fourier transform phase
X_filtered =  X_abs_refined.* exp(1j*X_shifted_phase); % the magnitude smoothed Fourier transform (the phase remains unchanged)
x_filtered = real(ifft(X_filtered, T, 2)); % Inverse Fourier transform

% Plot results if in verbose mode
if plot_flag
    for ch = 1 : N
        figure
        plot(x(ch, :));
        hold on
        plot(x_filtered(ch, :));
        title(['Ch #', num2str(ch)]);
        legend('Original', 'Filtered');
        xlabel('Samples');
        ylabel('Amplitude');
        grid
    end

    for ch = 1 : N
        f = (0:T-1)/T;
        figure
        plot(f, 20*log10(abs(X(ch, :))));
        hold on
        plot(f, 20*log10(abs(X_filtered(ch, :))));
        legend('Original', 'Filtered');
        title(['Ch #', num2str(ch), ' spectrum']);
        xlabel('Normalized frequency');
        ylabel('Magnitude (dB)');
        grid
    end
end