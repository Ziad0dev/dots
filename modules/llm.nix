{
  config,
  lib,
  pkgs,
  username,
  ...
}:

let
  modelDir = "/var/lib/dots/models";

  # CUDA build for every GPU generation nixpkgs targets, so nothing here is
  # tied to one card. The NixOS CUDA cache (nix.settings below) serves it
  # prebuilt: it's downloaded, never compiled on this machine.
  llama = pkgs.llama-cpp.override { cudaSupport = true; };

  freeGpu = pkgs.writeShellScript "free-gpu" ''
    set -u
    api=http://127.0.0.1:11434
    ${pkgs.curl}/bin/curl -sf --max-time 2 "$api/api/ps" \
      | ${pkgs.jq}/bin/jq -r '.models[]?.name' 2>/dev/null \
      | while read -r m; do
          [ -n "$m" ] || continue
          ${pkgs.curl}/bin/curl -sf --max-time 5 "$api/api/generate" \
            -d "{\"model\":\"$m\",\"keep_alive\":0}" >/dev/null || true
        done
    exit 0
  '';

  sandbox = {
    DynamicUser = true;
    PrivateUsers = true;
    PrivateTmp = true;
    ProtectSystem = "strict";
    ProtectHome = true;
    NoNewPrivileges = true;
    CapabilityBoundingSet = [ "" ];
    MemoryDenyWriteExecute = true;
    RestrictAddressFamilies = [
      "AF_INET"
      "AF_INET6"
      "AF_UNIX"
    ];
  };

  # One unit per model, all on :8080 but the FIM one. Where layers and MoE
  # experts go is left to llama-server's --fit (on by default): it sizes them
  # to the VRAM that's free when the unit starts, so no card size or layer
  # count is written down here. -c is the context each model is used with.
  models = {
    llama-uncensored = {
      description = "Huihui Qwen3.5-9B abliterated (uncensored general)";
      file = "Huihui-Qwen3.5-9B-abliterated.Q6_K.gguf";
      args = "-c 16384 --flash-attn on --jinja";
    };
    llama-hermes = {
      description = "Hermes 4 14B (steerable)";
      file = "NousResearch_Hermes-4-14B-IQ4_XS.gguf";
      args = "-c 8192 --flash-attn on --jinja --cache-type-k q8_0 --cache-type-v q8_0";
    };
    llama-sec = {
      description = "WhiteRabbitNeo V3-7B (security)";
      file = "WhiteRabbitNeo_WhiteRabbitNeo-V3-7B-Q5_K_M.gguf";
      args = "-c 16384 --flash-attn on --jinja";
    };
    llama-agent = {
      description = "Qwen2.5-Coder-14B (agent / tool-calling)";
      file = "Qwen2.5-Coder-14B-Instruct-Q4_K_M.gguf";
      args = "-c 16384 --flash-attn on --jinja";
    };
    llama-gemma = {
      description = "Gemma 4 12B Unified (general / vision / audio)";
      file = "gemma-4-12B-it-Q4_K_M.gguf";
      args = "-c 16384 --flash-attn on --jinja --temp 1.0 --top-p 0.95 --top-k 64";
    };
    llama-coder = {
      description = "Gemma 4 26B A4B MoE (coding / agentic)";
      file = "gemma-4-26B-A4B-it-Q4_K_M.gguf";
      args = "-c 16384 --flash-attn on --jinja --temp 1.0 --top-p 0.95 --top-k 64 --cache-type-k q8_0 --cache-type-v q8_0";
    };
    llama-fim = {
      description = "Qwen2.5-Coder-3B FIM (llama.vim)";
      file = "qwen2.5-coder-3b-q8_0.gguf";
      port = 8012;
      args = "-c 8192";
    };
  };

  # every unit that holds the GPU: one runs at a time, and the user may start
  # and stop each without sudo (the polkit rule below, with ollama)
  gpuUnits = [ "llama-cpp" ] ++ builtins.attrNames models;

  # a missing model would fail and retry every 5 min until someone notices;
  # skip the start instead (the unit just stays inactive)
  gpuUnit = self: model: {
    conflicts = map (u: "${u}.service") (lib.remove self gpuUnits);
    unitConfig = {
      StartLimitBurst = 5;
      ConditionPathExists = model;
    };
    wantedBy = lib.mkForce [ ];
    serviceConfig.ExecStartPre = freeGpu;
  };
in
{
  nix.settings = {
    extra-substituters = [ "https://cache.nixos-cuda.org" ];
    extra-trusted-public-keys = [
      "cache.nixos-cuda.org:74DUi4Ye579gUqzH4ziL9IyiJBlDpMRn9MBN8oNan9M="
    ];
  };

  services.llama-cpp = {
    enable = true;
    package = llama;
    settings = {
      model = "${modelDir}/Qwen3.5-9B-Q6_K.gguf";
      host = "127.0.0.1";
      port = 8080;
      ctx-size = 16384;
      flash-attn = "on";
    };
  };

  systemd.services = {
    llama-cpp = gpuUnit "llama-cpp" config.services.llama-cpp.settings.model;
  }
  // lib.mapAttrs (
    name: m:
    lib.recursiveUpdate (gpuUnit name "${modelDir}/${m.file}") {
      inherit (m) description;
      serviceConfig = sandbox // {
        ExecStart = "${llama}/bin/llama-server -m ${modelDir}/${m.file} --host 127.0.0.1 --port ${toString (m.port or 8080)} ${m.args}";
      };
    }
  ) models;

  # By user, not session: ghostty and the Quickshell bar (whose Oracle starts
  # these) run as systemd user services, outside the login session, where
  # polkit sees no active session and refused them. The unit list keeps it narrow.
  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      var units = ${builtins.toJSON (map (u: "${u}.service") (gpuUnits ++ [ "ollama" ]))};
      if (action.id == "org.freedesktop.systemd1.manage-units"
          && subject.user == "${username}"
          && units.indexOf(action.lookup("unit")) >= 0) {
        return polkit.Result.YES;
      }
    });
  '';

  systemd.tmpfiles.rules = [
    "d /var/lib/dots/models 0755 ${username} users -"
  ];

  environment.systemPackages = with pkgs; [
    nvtopPackages.nvidia
    omp
    llama
  ];
}
