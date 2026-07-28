{ pkgs, lib, username, ... }:

# ── Local LLM inference ───────────────────────────────────────────────────────
# llama.cpp with CUDA, serving one model over an OpenAI-compatible HTTP API on
# 127.0.0.1:8080. Weights live on /data — they're 6-20 GB each and there's no
# reason to burn root space or push them through the Nix store.
#
# Sizing: ~15.4 GiB RAM, 12 GiB VRAM, swapDevices = [ ] (zram only). That rules
# out MoE expert-offload (a 35B-A3B wants 32 GB of system RAM for the routed
# experts), so this is built around a dense 9B that fits entirely in VRAM.
# Faster and far less fiddly anyway.
#
# Owns nothing configuration.nix owns except an extra nix.settings.substituters
# entry — that option is a list and merges across modules.

{
  # ── CUDA binary cache ──────────────────────────────────────────────────────
  # cudaSupport = true pulls a large closure; fetch it rather than build it on
  # 6 cores. Caveat: nixpkgs follows chaotic/nixpkgs and this cache is populated
  # against nixpkgs-unstable revisions, so hits are likely but not guaranteed.
  # If a rebuild starts compiling cudatoolkit, that's a miss — kill it and wait
  # for the next flakeup rather than sitting through it.
  nix.settings = {
    substituters = [ "https://cuda-maintainers.cachix.org" ];
    trusted-public-keys = [
      "cuda-maintainers.cachix.org-1:0dq3bujKpuEPMCX6U4WylrUDZ9JyUG0VpVZa7CNfq5E="
    ];
  };

  # ── The server ─────────────────────────────────────────────────────────────
  # settings is a freeform attrset fed through lib.cli.toCommandLine. Names
  # longer than one character become --${name}, so they must be llama-server's
  # *long* option names: --ngl and --ctk do not exist, only -ngl/--n-gpu-layers
  # and -ctk/--cache-type-k. Getting this wrong fails at runtime, not eval.
  #
  # model is a quoted string on purpose — an unquoted path literal would be
  # copied into the Nix store at eval time, which for a 7 GB GGUF is not what
  # anyone wants. Download once, imperatively:
  #   mkdir -p /data/models && cd /data/models
  #   nix run nixpkgs#huggingface-hub -- hf download \
  #     unsloth/Qwen3.5-9B-Instruct-GGUF \
  #     Qwen3.5-9B-Instruct-UD-Q6_K_XL.gguf --local-dir .
  # Make sure it lands world-readable (0644) — the unit runs under DynamicUser
  # and won't be able to read a 0600 file owned by you.
  services.llama-cpp = {
    enable  = true;
    package = pkgs.llama-cpp.override { cudaSupport = true; };
    openFirewall = false;   # loopback only; ssh-tunnel it if you want it remote

    settings = {
      host  = "127.0.0.1";
      port  = 8080;
      model = "/data/models/Qwen3.5-9B-Instruct-UD-Q6_K_XL.gguf";

      # Q6_K on a 9B is ~7.5 GB of weights. With a q8_0 KV cache a 64k context
      # still fits inside 12 GiB, so there's no reason to drop to Q4 — Q4 is
      # for when the model doesn't otherwise fit, and this one does.
      n-gpu-layers = 99;      # NOT "ngl" — that flag doesn't exist
      ctx-size     = 65536;   # drop to 32768 if nvtop shows you're tight
      cache-type-k = "q8_0";  # NOT "ctk"
      cache-type-v = "q8_0";
      flash-attn   = "on";    # takes on/off/auto now, not 0/1

      threads      = 6;       # 12400f is 6 physical cores, no E-cores.
                              # Hyperthreads hurt llama.cpp — do not use 12.
      batch-size   = 2048;    # helps long-prompt prefill
      ubatch-size  = 512;
      jinja        = true;    # bare bool renders as a lone --jinja
    };
  };

  # /data is mounted nofail behind a LUKS unlock; without this the unit races
  # the mount on boot and dies on a missing model file. The upstream module
  # sets Restart=on-failure with RestartSec=300, so a race would cost 5min.
  systemd.services.llama-cpp.unitConfig.RequiresMountsFor = "/data";

  # ── If it dies immediately with a CUDA error ───────────────────────────────
  # The upstream unit sets MemoryDenyWriteExecute = true. If the CUDA build
  # lacks precompiled sm_86 kernels it JITs PTX at load and needs W+X pages,
  # which that blocks. Symptom is a CUDA init failure in `journalctl -u
  # llama-cpp` within seconds of start. If so, uncomment:
  #
  # systemd.services.llama-cpp.serviceConfig.MemoryDenyWriteExecute =
  #   lib.mkForce false;

  systemd.tmpfiles.rules = [
    "d /data/models 0755 ${username} users -"
  ];

  environment.systemPackages = with pkgs; [
    nvtopPackages.nvidia   # watch VRAM headroom while tuning ctx-size
    # llama-bench / llama-cli live in the llama-cpp package, which is only
    # referenced by the service above. Uncomment for them on PATH:
    # (llama-cpp.override { cudaSupport = true; })
  ];

  # ── Optional frontend ──────────────────────────────────────────────────────
  # llama-server has a usable built-in web UI at http://127.0.0.1:8080 already.
  # open-webui only earns its keep if you want persistent history and
  # multi-model switching; it drags in a Python stack and its own state dir.
  #
  # services.open-webui = {
  #   enable = true;
  #   port = 8081;
  #   environment = {
  #     OLLAMA_BASE_URL = "";
  #     OPENAI_API_BASE_URL = "http://127.0.0.1:8080/v1";
  #     WEBUI_AUTH = "False";
  #   };
  # };
}
