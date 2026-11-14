.pragma library

// value kept between low and high: 0 to 1 unless told otherwise
function clamp(value, low = 0, high = 1) {
    return Math.max(low, Math.min(value, high));
}
