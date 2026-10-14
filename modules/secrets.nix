{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  cfg = config.dots.secrets;
in
{
  imports = [ inputs.sops-nix.nixosModules.sops ];

  # Hosts opt in once their encrypted file and age key are provisioned;
  # each host declares its own sops.secrets.
  options.dots.secrets = {
    enable = lib.mkEnableOption "SOPS-encrypted host secrets";

    file = lib.mkOption {
      type = lib.types.path;
      description = "Path to this host's encrypted SOPS file, stored outside the public repo.";
    };

    keyFile = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/sops-nix/key.txt";
      description = "The host's age private key. It never enters the store.";
    };
  };

  config = lib.mkMerge [
    {
      environment.systemPackages = [
        pkgs.secretspec
        pkgs.pass
        pkgs.gnupg
        pkgs.pinentry-qt
        pkgs.pinentry-curses
        pkgs.bitwarden-cli
        pkgs.sops
        pkgs.age
      ];

      programs.gnupg.agent = {
        enable = true;
        pinentryPackage = pkgs.pinentry-qt;
        settings = {
          # the login password unlocks the key for the whole session
          # (pam-gnupg below); short TTLs would bring the prompt back mid-day
          default-cache-ttl = 34560000;
          max-cache-ttl = 34560000;
          no-allow-external-cache = "";
        };
      };

      # pam-gnupg: logging in through SDDM (and unlocking the lock screen) hands the
      # password to gpg-agent for the keygrips in ~/.config/pam-gnupg, so the
      # GPG key behind pass/pass-secret-service never asks separately. Needs
      # the GPG passphrase to equal the login password.
      # sddm's PAM stack is just `include login`, so hook login itself
      security.pam.services.login.gnupg.enable = true;
      security.pam.services.quickshell-lock.gnupg.enable = true;
    }

    (lib.mkIf cfg.enable {
      sops = {
        defaultSopsFile = cfg.file;
        age.keyFile = cfg.keyFile;
        # only the age key above; no host SSH keys exist on these machines
        age.sshKeyPaths = [ ];
        gnupg.sshKeyPaths = [ ];
      };
    })
  ];
}
