# hosts/claude-vm/agent.nix
#
# Everything that makes this a Claude Code box rather than a generic VM.
{
  config,
  lib,
  pkgs,
  username,
  ...
}:

let
  claudeSettings = {
    "$schema" = "https://json.schemastore.org/claude-code-settings.json";

    # Pre-enable the plugin instead of running /plugin install by hand after
    # every reset. mattpocock-skills ships in Claude Code's official
    # marketplace, so no extraKnownMarketplaces entry is needed. If it ever
    # stops resolving, check the marketplace slug under /plugin > Marketplaces.
    enabledPlugins = {
      "mattpocock-skills@claude-plugins-official" = true;
    };

    env = {
      # Store is read-only; let the updater not bother.
      DISABLE_AUTOUPDATER = "1";
    };
  };

  settingsFile = (pkgs.formats.json { }).generate "claude-settings.json" claudeSettings;
in
{
  # hosts/nixos sets allowUnfree globally. The guest gets a scoped predicate
  # instead — claude-code is the only unfree thing it should need.
  nixpkgs.config.allowUnfreePredicate =
    pkg:
    builtins.elem (lib.getName pkg) [
      "claude-code"
      "claude"
    ];

  users.users.${username} = {
    isNormalUser = true;
    description = "agent sandbox user";

    # Must match ziad0dev's uid on the host: virtualisation.sharedDirectories
    # uses 9p with security_model=none, so uids pass through unmapped and a
    # mismatch makes /mnt/work read-only in practice.
    uid = 1001;

    password = "dev"; # plaintext in the store — acceptable for a throwaway guest
    extraGroups = [ "wheel" ];
    shell = pkgs.fish;
  };
  programs.fish.enable = true;
  security.sudo.wheelNeedsPassword = false;
  services.getty.autologinUser = username;

  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = true;
    };
  };
  # Guest sits behind QEMU user-mode NAT; only forwarded ports are reachable.
  networking.firewall.enable = false;

  # Toolchains come from ../../modules/dev-langs.nix — zig, zls, clang stack,
  # python/uv/ruff/pyright, sbcl+swank. Only what that module doesn't cover:
  environment.systemPackages = with pkgs; [
    claude-code

    git
    gh
    jujutsu
    nodejs_22 # for `npx skills@latest add ...` if you take the editable route
    ripgrep
    fd
    jq
    tree
    curl
    unzip

    neovim
    tmux
    htop
  ];

  # `C` copies once and leaves the file writable, so /config edits inside the
  # guest survive on a persistent image and get re-seeded after a reset.
  systemd.tmpfiles.rules = [
    "d /home/${username}/.claude 0700 ${username} users -"
    "C /home/${username}/.claude/settings.json 0600 ${username} users - ${settingsFile}"
    "d /home/${username}/src 0755 ${username} users -"
  ];

  environment.shellAliases = {
    yolo = "claude --dangerously-skip-permissions";
  };

  users.motd = ''
    claude-vm — disposable agent sandbox

      yolo          claude --dangerously-skip-permissions
      /mnt/work     9p share from the host (/data/vms/share)
      ~/src         guest-local scratch, gone on the next ephemeral boot

    First run: `claude` prints a login URL. Open it on the host, paste the
    code back. Credentials land in ~/.claude.json and do NOT survive an
    ephemeral (-snapshot) boot — use `claude-vm.sh persist` to keep them.
  '';
}
