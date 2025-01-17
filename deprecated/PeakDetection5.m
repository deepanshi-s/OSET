function [peaks, peak_indexes] = PeakDetection5(x, ff, varargin)
% Deprecated: PeakDetection5 is deprecated. Use peak_detection_local_search instead.
    warning('Deprecated: PeakDetection is deprecated. Use peak_detection_local_search instead.');

if nargin > 2 && ~isempty(varargin{1})
    flag = varargin{1};
else
    flag = abs(max(x)) > abs(min(x));
end    

omit_close_peaks = 0;
[peaks, peak_indexes] = peak_detection_simple(x, ff, flag, omit_close_peaks);
