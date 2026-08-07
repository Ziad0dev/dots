# modules/ollama.nix — ollama daemon on the RTX 3060, OpenAI-compatible on :11434
#
# Why this exists alongside llm.nix: ollama picks the GPU/CPU layer split
# itself, so a MoE that doesn't fit VRAM "just works" without hand-tuning
# --n-cpu-moe, and it loads/unloads on demand instead of needing one systemd
# unit per model. llm.nix stays for the tuned/pinned setups — the FIM
# completer on :8012 that llama.vim talks to, and WhiteRabbitNeo, which isn't
# in ollama's library anyway.
#
#   ollama pull <model>
#   ollama run  <model>
#   ollama ps                     # what's currently holding VRAM
#   ollama stop <model>           # free the card without killing the daemon
#
# API: http://127.0.0.1:11434  (native)  and  /v1  (OpenAI-compatible)
{ config, lib, pkgs, ... }:

{
  services.ollama = {
    enable = true;

    # `acceleration = "cuda"` was removed upstream — it's a package choice now
    # (pkgs.ollama / -cuda / -rocm / -vulkan / -cpu).
    #
    # Vulkan, not CUDA, for the same reason llm.nix uses llama-cpp-vulkan:
    # cache.nixos.org can't redistribute CUDA-enabled builds, so ollama-cuda
    # is always a local compile. ollama-vulkan is cached and exercises the
    # same backend that's already proven to work on this 3060. Costs maybe
    # 10-20% throughput against CUDA.
    #
    # Careful with bare `pkgs.ollama`: with acceleration unset it falls back
    # to nixpkgs.config.cudaSupport/rocmSupport, and with neither set you
    # silently get a CPU-only runner.
    package = pkgs.ollama-vulkan;

    # Setting user/group to non-null makes the module create a real system
    # account and drop DynamicUser. REQUIRED here: with DynamicUser the uid is
    # transient, so nothing can own a models directory outside /var/lib and
    # every pull fails on permissions (and `chown ollama:ollama` errors with
    # "invalid user", since no such user exists).
    user = "ollama";
    group = "ollama";

    host = "127.0.0.1";
    port = 11434;

    # Keep weights off the root SSD. Note this is bind-mounted into the unit's
    # mount namespace — if the directory doesn't exist the service dies at
    # step NAMESPACE with a bare "No such file or directory", which looks
    # nothing like a permissions problem. The tmpfiles rule below prevents it.
    modelsDir = "/data/models/ollama";

    # NOT using loadModels. The llm.nix units already have Gemma 4 12B and
    # 26B A4B as GGUFs under /data/models; pulling them here too would store
    # ~22 GB of the same weights again in ollama's blob format. Pull models
    # by hand when you actually want to try something new.
    #
    # loadModels = [ ... ];

    environmentVariables = {
      # Preserve llm.nix's invariant: one model holds the 3060 at a time.
      OLLAMA_MAX_LOADED_MODELS = "1";

      # Unload after 5 minutes idle so the card is free for llama-* units or
      # a game. "0" unloads after every request; "-1" pins indefinitely.
      OLLAMA_KEEP_ALIVE = "5m";

      OLLAMA_FLASH_ATTENTION = "1";

      # Halves KV cache memory — the difference between a 26B fitting
      # reasonably and thrashing on a 12 GB card. Small quality cost.
      OLLAMA_KV_CACHE_TYPE = "q8_0";

      # Default is 4096 regardless of what the model supports, which silently
      # truncates long contexts rather than erroring.
      OLLAMA_CONTEXT_LENGTH = "16384";
    };
  };

  # /data/models itself is created by llm.nix; this is the ollama subdir.
  systemd.tmpfiles.rules = [
    "d /data/models/ollama 0750 ollama ollama -"
  ];

  # The upstream module only orders after network.target. /data is a nofail
  # LUKS mount unlocked post-boot, so without this the unit races the mount
  # and fails at step NAMESPACE on every reboot.
  systemd.services.ollama = {
    unitConfig.RequiresMountsFor = "/data";
    after = [ "data.mount" ];
  };

  # The module's DeviceAllow covers the nvidia char devices and char-drm at
  # the cgroup level, but cgroup policy isn't file permissions: /dev/dri/*
  # is 0660 root:render, so a static (non-dynamic) user still needs the
  # groups to open them for the Vulkan backend.
  users.users.ollama.extraGroups = [
    "video"
    "render"
  ];

  # NOT opening the firewall: the claude-vm guest reaches this at
  # 10.0.2.2:11434 through QEMU's slirp mapping to host loopback, and
  # Tailscale peers don't need it.

  # Both directions of the shared-GPU problem:
  #
  #   llama-* starting  ->  automatic. Every llama-* unit in llm.nix runs an
  #                         ExecStartPre that tells ollama to unload.
  #
  #   ollama loading    ->  NOT automatic. The daemon allocates on demand and
  #                         there's no hook to intercept it, so if a llama-*
  #                         unit owns the card, ollama spills to RAM or fails.
  #                         Run `gpu-check` first.
  environment.shellAliases = {
    gpu-check = "systemctl list-units 'llama-*' --state=running --no-legend; ollama ps";
    gpu-free = "systemctl stop 'llama-*'; ollama ps";
  };
}
