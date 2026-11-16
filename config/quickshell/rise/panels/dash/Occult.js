.pragma library

// Small almanac for the grimoire dashboard: moon phase, planetary hours,
// Roman numerals and a name sigil traced on the magic square of Saturn.

// ── moon ──
// mean synodic month from a known new moon (2000-01-06 18:14 UTC); good to a
// few hours, which is plenty for a phase name
var SYNODIC = 29.530588853
var NEW_MOON_MS = Date.UTC(2000, 0, 6, 18, 14)
var PHASES = ["New Moon", "Waxing Crescent", "First Quarter", "Waxing Gibbous",
              "Full Moon", "Waning Gibbous", "Last Quarter", "Waning Crescent"]

function moon(date) {
    var days = (date.getTime() - NEW_MOON_MS) / 86400000
    var age = ((days % SYNODIC) + SYNODIC) % SYNODIC
    var frac = age / SYNODIC                              // 0 new · 0.5 full
    var illum = (1 - Math.cos(2 * Math.PI * frac)) / 2
    var idx = Math.floor(frac * 8 + 0.5) % 8
    return { age: age, frac: frac, illum: illum, name: PHASES[idx], waxing: frac < 0.5 }
}

// ── planetary hours ──
// Chaldean order; each day's first hour belongs to the day's ruler
var CHALDEAN = ["Saturn", "Jupiter", "Mars", "Sun", "Venus", "Mercury", "Moon"]
var DAY_RULER = ["Sun", "Moon", "Mars", "Mercury", "Jupiter", "Venus", "Saturn"]   // Sunday first
var GLYPH = { Saturn: "♄", Jupiter: "♃", Mars: "♂", Sun: "☉", Venus: "♀", Mercury: "☿", Moon: "☽" }

// "07:12 AM" / "19:05" → minutes after midnight, or fallback
function minutesOf(s, fallback) {
    var m = String(s || "").trim().match(/^(\d{1,2}):(\d{2})\s*(AM|PM)?$/i)
    if (!m) return fallback
    var h = parseInt(m[1]) % 12, min = parseInt(m[2])
    if (!m[3]) h = parseInt(m[1])
    else if (m[3].toUpperCase() === "PM") h += 12
    return h * 60 + min
}

// sunrise/sunset as wttr.in strings; 06:00 / 18:00 when unknown
function planetaryHour(date, sunrise, sunset) {
    var rise = minutesOf(sunrise, 360), set = minutesOf(sunset, 1080)
    var now = date.getHours() * 60 + date.getMinutes() + date.getSeconds() / 60
    var weekday = date.getDay(), n
    if (now >= rise && now < set) {
        n = Math.floor((now - rise) / ((set - rise) / 12))
    } else {
        var night = 1440 - set + rise                       // tonight's length
        var since = now >= set ? now - set : now + 1440 - set
        n = 12 + Math.floor(since / (night / 12))
        if (now < rise) weekday = (weekday + 6) % 7        // still last night
    }
    var dayRuler = DAY_RULER[weekday]
    var hourRuler = CHALDEAN[(CHALDEAN.indexOf(dayRuler) + n) % 7]
    return { day: dayRuler, hour: hourRuler, dayGlyph: GLYPH[dayRuler], hourGlyph: GLYPH[hourRuler],
             index: n + 1, daytime: n < 12 }
}

// ── numerals ──
function roman(n) {
    n = Math.floor(n)
    if (!(n > 0) || n >= 4000) return String(n)
    var v = [1000, 900, 500, 400, 100, 90, 50, 40, 10, 9, 5, 4, 1]
    var s = ["M", "CM", "D", "CD", "C", "XC", "L", "XL", "X", "IX", "V", "IV", "I"]
    var out = ""
    for (var i = 0; i < v.length; i++) while (n >= v[i]) { out += s[i]; n -= v[i] }
    return out
}

// ── sigil ──
// The magic square of Saturn; a word's letters reduced to 1–9 (a=1 … i=9,
// j=1 …) and traced across it. Returns the cells visited as [col, row] pairs,
// dropping letters that repeat the previous cell.
var KAMEA = [[4, 9, 2], [3, 5, 7], [8, 1, 6]]

function cellOf(digit) {
    for (var r = 0; r < 3; r++)
        for (var c = 0; c < 3; c++)
            if (KAMEA[r][c] === digit) return [c, r]
    return [1, 1]
}

function sigil(word) {
    var out = [], last = -1
    var w = String(word || "").toLowerCase().replace(/[^a-z]/g, "")
    for (var i = 0; i < w.length; i++) {
        var d = (w.charCodeAt(i) - 97) % 9 + 1
        if (d === last) continue
        last = d
        out.push(cellOf(d))
    }
    return out
}

// the hour of the day as a quiet line ("the witching hour", "dusk", …)
function vigil(date) {
    var h = date.getHours()
    return h < 3 ? "the witching hour" : h < 6 ? "before the dawn" : h < 12 ? "morning"
         : h < 17 ? "afternoon" : h < 20 ? "dusk" : "nightfall"
}
