.pragma library

// The cover's color, as the Catppuccin Mocha accent of the same hue: every album has its
// own color, never one outside the palette.

var MOCHA = {
    red: "#f38ba8", peach: "#fab387", yellow: "#f9e2af", green: "#a6e3a1", teal: "#94e2d5",
    sky: "#89dceb", blue: "#89b4fa", lavender: "#b4befe", mauve: "#cba6f7", pink: "#f5c2e7",
};
var TEAL = MOCHA.teal;
var CRUST = "#11111b";
var TEXT = "#cdd6f4";

function hsl(hex) {
    const h = String(hex).replace("#", "").slice(-6);
    const r = parseInt(h.slice(0, 2), 16) / 255, g = parseInt(h.slice(2, 4), 16) / 255,
          b = parseInt(h.slice(4, 6), 16) / 255;
    const max = Math.max(r, g, b), min = Math.min(r, g, b), l = (max + min) / 2;
    if (max === min) {
        return { h: 0, s: 0, l: l };
    }
    const d = max - min;
    const s = l > 0.5 ? d / (2 - max - min) : d / (max + min);
    let hue;
    if (max === r) {
        hue = (g - b) / d + (g < b ? 6 : 0);
    } else if (max === g) {
        hue = (b - r) / d + 2;
    } else {
        hue = (r - g) / d + 4;
    }
    return { h: hue * 60, s: s, l: l };
}

const HUES = Object.keys(MOCHA).map(name => ({ name: name, h: hsl(MOCHA[name]).h }));

// a gray, black or white cover keeps the theme's teal
function accentFor(color) {
    if (!color) {
        return TEAL;
    }
    const c = hsl(color.toString());
    if (c.s < 0.18 || c.l < 0.08 || c.l > 0.94) {
        return TEAL;
    }
    let best = HUES[0], distance = 360;
    for (const entry of HUES) {
        const d = Math.min(Math.abs(entry.h - c.h), 360 - Math.abs(entry.h - c.h));
        if (d < distance) {
            best = entry;
            distance = d;
        }
    }
    return MOCHA[best.name];
}

// The color of a picture's pixels (RGBA bytes): the hue that the most colorful pixels share,
// as a Mocha accent; teal when there is too little color.
function accentFromPixels(data) {
    const weights = {};
    let total = 0;
    for (let i = 0; i + 3 < data.length; i += 4) {
        if (data[i + 3] < 128) {
            continue;
        }
        const hex = "#" + [data[i], data[i + 1], data[i + 2]].map(v => (v < 16 ? "0" : "") + v.toString(16)).join("");
        const c = hsl(hex);
        if (c.s < 0.25 || c.l < 0.12 || c.l > 0.9) {
            continue;
        }
        const accent = accentFor(hex);
        const weight = c.s * (1 - Math.abs(c.l - 0.5));
        weights[accent] = (weights[accent] || 0) + weight;
        total += weight;
    }
    let best = TEAL, most = 0;
    for (const accent in weights) {
        if (weights[accent] > most) {
            best = accent;
            most = weights[accent];
        }
    }
    // a few colored pixels on a gray cover do not make it colored
    return total * 4 * 1000 / data.length > 60 ? best : TEAL;
}

// microseconds -> 3:07, 1:02:07
function duration(us) {
    const total = Math.max(0, Math.floor(us / 1000000));
    const h = Math.floor(total / 3600), m = Math.floor(total / 60) % 60, s = total % 60;
    const ss = s < 10 ? "0" + s : "" + s;
    if (h > 0) {
        return h + ":" + (m < 10 ? "0" + m : m) + ":" + ss;
    }
    return m + ":" + ss;
}
