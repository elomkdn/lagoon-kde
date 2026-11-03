.pragma library

// Lyrics from lrclib.net, a free and open database of synced lyrics. Only asked for when
// the lyrics are turned on in the settings and opened: the requests carry the track's title
// and artist. Its search finds what its exact lookup misses: another album, a remaster, a
// video's title; the length keeps the right recording among the results.

const cache = {};

// "[01:02.50] line" -> [{ time: 62.5, text: "line" }], in order
function parse(lrc) {
    const lines = [];
    for (const raw of String(lrc).split("\n")) {
        const stamps = raw.match(/\[(\d+):(\d+(?:\.\d+)?)\]/g);
        if (!stamps) {
            continue;
        }
        const text = raw.replace(/\[[^\]]*\]/g, "").trim();
        for (const stamp of stamps) {
            const m = stamp.match(/\[(\d+):(\d+(?:\.\d+)?)\]/);
            lines.push({ time: parseInt(m[1]) * 60 + parseFloat(m[2]), text: text });
        }
    }
    return lines.sort((a, b) => a.time - b.time);
}

// for comparing: lowercase, without accents, spaces or punctuation
function normalized(text) {
    return String(text).normalize("NFD").replace(/[^\p{L}\p{N}]/gu, "").toLowerCase();
}

// "(feat. X)", "[Official Video]", " - Remastered 2011", " - From "8 Mile" Soundtrack": what a
// player adds to the song's name
const EXTRA = "feat|ft\\.|with |official|video|audio|lyric|clip|visuali[sz]er|remaster|remix|edit|version|"
    + "soundtrack|from |live|mono|stereo|bonus|deluxe|hd\\b|4k\\b";

function cleanTitle(title) {
    return String(title)
        .replace(new RegExp("\\s*[(\\[][^)\\]]*(" + EXTRA + ")[^)\\]]*[)\\]]", "gi"), "")
        .replace(new RegExp("\\s+[-–—]\\s+[^-–—]*(" + EXTRA + ")[^-–—]*$", "i"), "")
        .trim();
}

function firstArtist(artist) {
    return String(artist).split(/,|&|\s(?:feat\.?|ft\.?|x)\s/i)[0].trim();
}

// the searches, from the surest to the widest; a video's title is often "Artist - Title"
function searches(artist, title) {
    const clean = cleanTitle(title), first = firstArtist(artist);
    const list = [];
    const dash = clean.match(/^(.+?)\s+[-–—]\s+(.+)$/);
    if (first) {
        list.push({ track: clean, artist: first });
    }
    if (dash) {
        list.push({ track: dash[2], artist: firstArtist(dash[1]) });
    }
    list.push({ track: dash ? dash[2] : clean, artist: dash ? firstArtist(dash[1]) : first, wide: true });
    return list;
}

// the entry for this song: the same title and artist, of about its length, synced if there is one
function best(entries, search, seconds) {
    const track = normalized(search.track), artist = normalized(search.artist);
    const same = (a, b) => a && b && (a.includes(b) || b.includes(a));
    const off = entry => seconds > 0 && entry.duration ? Math.abs(entry.duration - seconds) : 0;
    const fitting = entries.filter(entry => !entry.instrumental && (entry.syncedLyrics || entry.plainLyrics)
        && same(normalized(cleanTitle(entry.trackName)), track)
        && (!artist || same(normalized(entry.artistName), artist)) && off(entry) <= 15);
    fitting.sort((a, b) => (b.syncedLyrics ? 1 : 0) - (a.syncedLyrics ? 1 : 0) || off(a) - off(b));
    return fitting[0] ?? null;
}

function get(url, done) {
    const request = new XMLHttpRequest();
    request.onreadystatechange = function () {
        if (request.readyState !== XMLHttpRequest.DONE) {
            return;
        }
        if (request.status !== 200) {
            done(null);
            return;
        }
        try {
            done(JSON.parse(request.responseText));
        } catch (error) {
            done(null);
        }
    };
    request.open("GET", url);
    request.setRequestHeader("Lrclib-Client", "Teal Pill (https://github.com/elomkdn/teal-pill)");
    request.send();
}

// callback({ synced: [...] } | { plain: [...] } | { none: true } | { error: true })
function fetch(artist, title, seconds, callback) {
    const key = [artist, title, Math.round(seconds)].join("\u0001");
    if (cache[key]) {
        callback(cache[key]);
        return;
    }
    const list = searches(artist, title);
    // lrclib is often "busy, retry in a moment": no lyrics only if every search got an answer
    let failed = false;
    function next(at) {
        if (at >= list.length) {
            if (!failed) {
                cache[key] = { none: true };
            }
            callback(failed ? { error: true } : cache[key]);
            return;
        }
        const search = list[at];
        const query = search.wide
            ? "q=" + encodeURIComponent(search.artist + " " + search.track)
            : "track_name=" + encodeURIComponent(search.track) + "&artist_name=" + encodeURIComponent(search.artist);
        get("https://lrclib.net/api/search?" + query, entries => {
            failed = failed || entries === null;
            const entry = entries ? best(entries, search, seconds) : null;
            if (!entry) {
                next(at + 1);
                return;
            }
            cache[key] = entry.syncedLyrics
                ? { synced: parse(entry.syncedLyrics) }
                : { plain: entry.plainLyrics.split("\n").map(text => ({ time: -1, text: text.trim() })) };
            callback(cache[key]);
        });
    }
    next(0);
}
