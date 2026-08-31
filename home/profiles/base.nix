{
  config,
  lib,
  pkgs,
  inputs,
  username,
  system,
  profile ? "minimal",
  ...
}:

let
  isDarwin = lib.hasSuffix "-darwin" system;
  homeDir = if isDarwin then "/Users/${username}" else "/home/${username}";
  link = sub: config.lib.file.mkOutOfStoreSymlink "${config.dots.repoPath}/config/${sub}";

  rebuild =
    if isDarwin then
      "nh darwin switch"
    else if profile == "desktop" then
      "nh os switch"
    else
      "nh home switch";
in
{
  imports = [
    inputs.nix-index-database.homeModules.default
    ../dev-home.nix
    ../fastfetch.nix
    ../git-hooks.nix
    (import ../../flakes/infosec/module.nix { target = "home"; })
    (import ../../flakes/maths/module.nix { target = "home"; })
  ];

  options.dots.repoPath = lib.mkOption {
    type = lib.types.str;
    default = "${homeDir}/dots";
    description = "Absolute path of the checked-out dots repo on this machine.";
  };

  config = {
    home.username = username;
    home.homeDirectory = lib.mkDefault homeDir;
    home.stateVersion = "24.05";

    programs.home-manager.enable = true;

    zi.infosec = {
      enable = true;
      sets = [ "core" ];
    };

    zi.maths = {
      enable = true;
      sets = [ "core" ];
    };

    home.sessionVariables = {
      EDITOR = "nvim";
      VISUAL = "nvim";
      TERMINAL = "ghostty";
    };

    programs.bash.enable = true;

    programs.direnv = {
      enable = true;
      nix-direnv.enable = true;
    };

    programs.git = {
      enable = true;
      settings = {
        init.defaultBranch = "main";
        pull.rebase = true;
        push.autoSetupRemote = true;
        rebase.autoStash = true;
        fetch.prune = true;
        rerere.enabled = true;
        diff.algorithm = "histogram";
        merge.conflictStyle = "zdiff3";
        include.path = "~/.config/git/local";
      };
    };

    programs.ssh = {
      enable = true;
      enableDefaultConfig = false;

      settings = {
        "*" = {
          AddKeysToAgent = "yes";
          ForwardAgent = false;
          Compression = false;
          ServerAliveInterval = 0;
          ServerAliveCountMax = 3;
          HashKnownHosts = false;
          UserKnownHostsFile = "~/.ssh/known_hosts";
          ControlMaster = "no";
          ControlPath = "~/.ssh/master-%r@%n:%p";
          ControlPersist = "no";
        };

        "github.com" = {
          User = "git";
          IdentityFile = "~/.ssh/id_ed25519";
          IdentitiesOnly = true;
          ControlMaster = "auto";
          ControlPersist = "10m";
        };
      };
    };

    programs.fish = {
      enable = true;

      shellAliases = {
        ll = "ls -l";
        la = "ls -la";
        edit = "sudo -e";
      };

      shellAbbrs = {
        update = rebuild;
        upall = "${rebuild} -u";
        flakeup = "nix flake update --flake ${config.dots.repoPath}";
        g = "git";
        gst = "git status";
        gco = "git checkout";
        gp = "git push";
        gl = "git pull";

        tw = "typst watch";
        tc = "typst compile";
        tf = "typstyle -i";
        lmk = "latexmk -pdf -pvc -interaction=nonstopmode";
        lmc = "latexmk -C";
      };
      functions = {
        dnx = {
          description = "Transcode video to DNxHR HQ for DaVinci Resolve";
          body = ''
            for f in $argv
              ffmpeg -n -i $f -c:v dnxhd -profile:v dnxhr_hq -c:a pcm_s16le \
                -pix_fmt yuv422p (path change-extension mov $f)
            end
          '';
        };
      };

      interactiveShellInit = "fish_vi_key_bindings";
    };

    home.file = {
      ".config/nvim".source = link "nvim";
      ".config/ghostty".source = link "ghostty";
      ".config/tmux".source = link "tmux";
      ".config/btop".source = link "btop";
      ".config/broot".source = link "broot";
      ".config/ranger".source = link "ranger";
    };

    home.packages = with pkgs; [
      ripgrep
      fd
      yazi
      broot
      ranger
      tmux
      jujutsu
      jrnl
      shellcheck
      gnumake
      pkg-config
      cmake
      go
      nodejs_22
      lua
      luarocks
      tree-sitter
      ffmpeg
      yt-dlp
      imagemagick
    ];
  };
}
