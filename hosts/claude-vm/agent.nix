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

    enabledPlugins = {
      "mattpocock-skills@claude-plugins-official" = true;
    };

    env = {

      DISABLE_AUTOUPDATER = "1";
    };
  };

  settingsFile = (pkgs.formats.json { }).generate "claude-settings.json" claudeSettings;
in
{

  nixpkgs.config.allowUnfreePredicate =
    pkg:
    builtins.elem (lib.getName pkg) [
      "claude-code"
      "claude"
    ];

  users.users.${username} = {
    isNormalUser = true;
    description = "agent sandbox user";

    uid = 1001;

    password = "dev";
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

  networking.firewall.enable = false;

  environment.systemPackages = with pkgs; [
    claude-code

    git
    gh
    jujutsu
    nodejs_22
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
