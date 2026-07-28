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
# Backend is Vulkan, not CUDA. llama-cpp-vulkan is a top-level nixpkgs attr
# (pkgs/by-name/ll/llama-cpp-vulkan), so Hydra builds it and it substitutes as
# a 23 MiB download with an 88 MiB closure. The CUDA variant has no such attr —
# cudaSupport defaults false, so any CUDA build is local and drags the whole
# CUDA runtime into the closure. The NVIDIA driver already provides the Vulkan
# ICD, so nothing else in configuration.nix needs to change.

{
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
  #     unsloth/Qwen3.5-9B-GGUF Qwen3.5-9B-Q6_K.gguf --local-dir .
  # (repo is Qwen3.5-9B-GGUF — no "-Instruct". Siblings in that repo are named
  #  Qwen3.5-9B-Q8_0.gguf / -Q3_K_M.gguf etc, so Q6_K follows the pattern; if
  #  the download 404s, `hf download unsloth/Qwen3.5-9B-GGUF --include "*Q6*"`
  #  will show what's actually there.)
  # Make sure it lands world-readable (0644) — the unit runs under DynamicUser
  # and won't be able to read a 0600 file owned by you.
  services.llama-cpp = {
    enable  = true;
    package = pkgs.llama-cpp-vulkan;
    openFirewall = false;   # loopback only; ssh-tunnel it if you want it remote

    settings = {
      host  = "127.0.0.1";
      port  = 8080;
      model = "/data/models/Qwen3.5-9B-Q6_K.gguf";

      # Q6_K on a 9B is ~7.5 GB of weights. With a q8_0 KV cache a 64k context
      # still fits inside 12 GiB, so there's no reason to drop to Q4 — Q4 is
      # for when the model doesn't otherwise fit, and this one does.
      n-gpu-layers = 99;      # NOT "ngl" — that flag doesn't exist
      ctx-size     = 65536;   # drop to 32768 if nvtop shows you're tight
      cache-type-k = "q8_0";  # NOT "ctk"
      cache-type-v = "q8_0";
      flash-attn   = "auto";  # auto, not on: Vulkan FA coverage is patchier
                              # than CUDA's, and auto falls back cleanly

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

  # ── Not on by default ──────────────────────────────────────────────────────
  # Upstream sets wantedBy = [ "multi-user.target" ], i.e. start at boot and
  # hold ~8 GiB of VRAM forever. On a 12 GiB card that leaves nothing for
  # games. wantedBy is a list and lists merge, so [] alone won't override it —
  # mkForce is required.
  #
  # The unit stays enabled and startable, it just doesn't autostart:
  #   systemctl start llama-cpp    # before working
  #   systemctl stop  llama-cpp    # before gaming
  systemd.services.llama-cpp.wantedBy = lib.mkForce [ ];

  # Automatic alternative: gamemode already runs on this box (gaming.nix), and
  # it can shell out on start/end. Untested here, and there's a wrinkle —
  # gamemoded runs as your user, so stopping a system unit needs a polkit rule
  # granting manage-units on llama-cpp.service. Worth it only if the manual
  # start/stop above gets annoying.
  #
  # programs.gamemode.settings.custom = {
  #   start = "${pkgs.systemd}/bin/systemctl stop llama-cpp.service";
  #   end   = "${pkgs.systemd}/bin/systemctl start llama-cpp.service";
  # };

  # ── If it dies immediately ─────────────────────────────────────────────────
  # The upstream unit sets MemoryDenyWriteExecute = true. NVIDIA's Vulkan
  # driver compiles SPIR-V to native code at pipeline-creation time and may
  # want W+X pages for it. Symptom is a device-init or pipeline failure in
  # `journalctl -u llama-cpp` within seconds of start. If so, uncomment:
  #
  # systemd.services.llama-cpp.serviceConfig.MemoryDenyWriteExecute =
  #   lib.mkForce false;
  #
  # If it starts but reports 0 offloaded layers, the unit can't see the ICD or
  # the device nodes. Check `vulkaninfo --summary` as your user first, then
  # compare against the sandbox: PrivateDevices is already false upstream and
  # /dev/nvidia* is 0666, so this shouldn't happen, but that's where to look.

  systemd.tmpfiles.rules = [
    "d /data/models 0755 ${username} users -"
  ];

  environment.systemPackages = with pkgs; [
    nvtopPackages.nvidia   # watch VRAM headroom while tuning ctx-size

    # Puts llama-cli, llama-server and llama-bench on PATH, from the same
    # store path the service uses. Note llama-cli loads its OWN copy of the
    # model — stop the service before using it or you'll run out of VRAM.
    llama-cpp-vulkan
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
