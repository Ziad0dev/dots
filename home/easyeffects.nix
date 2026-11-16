# EasyEffects microphone chain for the EPZ G30 boom mic.
# Output is deliberately left untouched: the IEM EQ lives in the cable's own DSP.
#
# Two input presets that differ ONLY in the noise-reduction stage, so Discord's Krisp
# is never stacked on top of EasyEffects' own denoiser:
#   mic-clean    EasyEffects (RNNoise) removes noise         -> Discord noise suppression: None
#   mic-discord  EasyEffects does NOT denoise (default)      -> Discord noise suppression: Krisp
# mic-discord is the login default because it is by far the cheapest on CPU
# (DeepFilterNet cost ~50% of a core; RNNoise is far lighter but still not free).
# Switch with `dots-mic-mode` (Super+Alt+D).
{ lib, ... }:
let
  # high-pass -> [denoise] -> gate -> compressor -> de-esser -> limiter
  chain =
    { denoise }:
    {
      blocklist = [ ];
      plugins_order = [ "filter#0" ] ++ lib.optional denoise "rnnoise#0" ++ [
        "gate#0"
        "compressor#0"
        "deesser#0"
        "limiter#0"
      ];

      # cut desk thumps and breath rumble
      "filter#0" = {
        bypass = false;
        type = "High-pass";
        mode = "BWC (BT)";
        slope = "x2";
        equal-mode = "IIR";
        frequency = 90.0;
      };
    }
    // lib.optionalAttrs denoise {
      # RNNoise: light CPU use compared to DeepFilterNet
      "rnnoise#0" = {
        bypass = false;
      };
    }
    // {
      # soft gate: attenuates between words rather than hard-muting (no clipped word starts)
      "gate#0" = {
        bypass = false;
        mode = "Downward";
        attack = 10.0;
        release = 150.0;
        curve-threshold = -48.0;
        curve-zone = -6.0;
        reduction = -18.0;
        makeup = 0.0;
      };

      # even out loud/quiet speech without squashing it
      "compressor#0" = {
        bypass = false;
        mode = "Downward";
        attack = 12.0;
        release = 150.0;
        threshold = -20.0;
        ratio = 3.0;
        knee = -6.0;
        makeup = 3.0;
        sidechain = {
          type = "Feed-forward";
          mode = "RMS";
          source = "Middle";
          preamp = 0.0;
          reactivity = 10.0;
          lookahead = 0.0;
        };
      };

      # off by default: it depends on your voice. Set bypass = false if "s" sounds harsh.
      "deesser#0" = {
        bypass = true;
        mode = "Wide";
        threshold = -22.0;
        ratio = 3.0;
      };

      # ceiling so a shout never clips for the people listening
      "limiter#0" = {
        bypass = false;
        mode = "Herm Thin";
        threshold = -3.0;
        lookahead = 5.0;
        attack = 5.0;
        release = 20.0;
        gain-boost = false;
      };
    };
in
{
  services.easyeffects = {
    # Only the input pipeline is loaded at login; output is left as-is.
    preset = {
      input = "mic-discord";
      output = "";
    };
    extraPresets = {
      mic-clean.input = chain { denoise = true; };
      mic-discord.input = chain { denoise = false; };
    };
  };
}
