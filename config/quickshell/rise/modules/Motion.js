.pragma library

// Shared motion vocabulary for Anim / CAnim. Curves are Material 3 Expressive
// (the same values end-4 and caelestia ship); the spatial ones overshoot, so use
// them only for position/scale/reveal — never for opacity-only or colour.
var curves = {
    spatialFast: [0.42, 1.67, 0.21, 0.90, 1, 1],  // snappy move with a visible settle
    spatial:     [0.38, 1.21, 0.22, 1.00, 1, 1],  // panel reveal: gentle overshoot
    effects:     [0.34, 0.80, 0.34, 1.00, 1, 1],  // opacity / colour
    size:        [0.05, 0.70, 0.10, 1.00, 1, 1],  // width/height: emphasized decelerate, no overshoot
    exit:        [0.30, 0.00, 0.80, 0.15, 1, 1]   // leaving: emphasized accelerate
}

var durations = {
    spatialFast: 350,
    spatial:     380,
    effects:     200,
    size:        250,
    exit:        150
}

function curve(kind) { return curves[kind] || curves.effects }
function duration(kind) { return durations[kind] || durations.effects }
