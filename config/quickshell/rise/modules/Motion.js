.pragma library

// Shared motion vocabulary for Anim / CAnim: Caelestia's Material 3 Expressive
// tokens, copied from caelestia-dots/shell (GPL-3.0-only),
// plugin/src/Caelestia/Config/tokens.hpp (AnimCurves, AnimDurationTokens).
// The spatial curves overshoot, so they're for position/size/scale/reveal,
// never for opacity-only or colour.
var curves = {
    spatialFast: [0.42, 1.67, 0.21, 0.90, 1, 1],  // expressiveFastSpatial
    spatial:     [0.38, 1.21, 0.22, 1.00, 1, 1],  // expressiveDefaultSpatial (Caelestia's plain `Anim {}`)
    spatialSlow: [0.39, 1.29, 0.35, 0.98, 1, 1],  // expressiveSlowSpatial
    effectsFast: [0.31, 0.94, 0.34, 1.00, 1, 1],  // expressiveFastEffects
    effects:     [0.34, 0.80, 0.34, 1.00, 1, 1],  // expressiveDefaultEffects
    effectsSlow: [0.34, 0.88, 0.34, 1.00, 1, 1],  // expressiveSlowEffects (Caelestia's CAnim)
    size:        [0.05, 0.70, 0.10, 1.00, 1, 1],  // emphasizedDecel: widths/heights/fills, no overshoot
    exit:        [0.30, 0.00, 0.80, 0.15, 1, 1]   // emphasizedAccel: leaving
}

var durations = {
    spatialFast: 350,
    spatial:     500,
    spatialSlow: 650,
    effectsFast: 150,
    effects:     200,
    effectsSlow: 300,
    size:        400,  // Caelestia's durations.normal
    exit:        200   // Caelestia's durations.small
}

function curve(kind) { return curves[kind] || curves.effects }
function duration(kind) { return durations[kind] || durations.effects }

// a hand-tuned `ms` wins (the bar's short snaps are deliberate: every frame
// of a bar animation is a redraw at 240 Hz); the token otherwise
function durationOr(kind, ms) { return ms > 0 ? ms : duration(kind) }
