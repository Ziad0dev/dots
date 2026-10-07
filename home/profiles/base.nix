{
  config,
  lib,
  pkgs,
  inputs,
  username,
  system,
  standalone,
  hmConfigName,
  dotsLink,
  ...
}:

let
  isDarwin = lib.hasSuffix "-darwin" system;
  homeDir = if isDarwin then "/Users/${username}" else "/home/${username}";
  cfg = config.dots;

  # A home-manager riding on NixOS or nix-darwin is rebuilt by the system;
  # a standalone one by `nh home switch` against its own output name.
  rebuild =
    if standalone then
      "nh home switch -c ${hmConfigName}"
    else if isDarwin then
      "nh darwin switch"
    else
      "nh os switch";
in
{
  imports = [
    inputs.nix-index-database.homeModules.default
    ../dev-home.nix
    ../fastfetch.nix
    ../nvim.nix
    ../git-hooks.nix
    ../themectl.nix
    ../yazi.nix
    (import ../../flakes/infosec/module.nix { target = "home"; })
    (import ../../flakes/maths/module.nix { target = "home"; })
  ];

  options.dots.repoPath = lib.mkOption {
    type = lib.types.str;
    default = "${homeDir}/dots";
    description = "Absolute path of the checked-out dots repo on this machine.";
  };

  options.dots.liveConfig = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = ''
      Link config/ from the checkout at dots.repoPath, so edits land without a
      rebuild. Off, every linked config is copied into the store instead: pure,
      rolls back with the generation, needs no checkout, read-only at runtime.
    '';
  };

  options.dots.src = lib.mkOption {
    type = lib.types.str;
    readOnly = true;
    default = if cfg.liveConfig then cfg.repoPath else "${inputs.self}";
    defaultText = lib.literalExpression ''if liveConfig then repoPath else "''${inputs.self}"'';
    description = "Where config/ is read from at runtime: the checkout, or the flake source in the store.";
  };

  options.dots.theme = lib.mkOption {
    type = lib.types.str;
    default = "oxocarbon";
    description = "Theme under config/themes rendered on a fresh home's first activation, and baked into anything that cannot follow themectl at runtime.";
  };

  config = {
    # `dotsLink "hypr"` is what every module puts behind home.file.*.source
    _module.args.dotsLink =
      sub:
      if cfg.liveConfig then
        config.lib.file.mkOutOfStoreSymlink "${cfg.repoPath}/config/${sub}"
      else
        "${inputs.self}/config/${sub}";

    home.username = username;
    home.homeDirectory = lib.mkDefault homeDir;
    home.stateVersion = "24.05";

    programs.home-manager.enable = true;

    # the NixOS host installs nh itself; everywhere else it comes from here
    programs.nh = lib.mkIf (standalone || isDarwin) {
      enable = true;
      flake = cfg.repoPath;
    };

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
      LIBSQLITE3 = "${pkgs.sqlite.out}/lib/libsqlite3.so";
      NVIM_LUA_CPATH =
        let
          luaEnv = pkgs.neovim-unwrapped.lua;
        in
        luaEnv.pkgs.getLuaCPath luaEnv.pkgs.jsregexp;
      NVIM_LUA_PATH =
        let
          luaEnv = pkgs.neovim-unwrapped.lua;
        in
        luaEnv.pkgs.getLuaPath luaEnv.pkgs.jsregexp;
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
        flakeup = "nix flake update --flake ${cfg.repoPath}";
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

      interactiveShellInit = ''
        fish_vi_key_bindings
        set -g fish_greeting
        set -l __dots_theme "${config.xdg.stateHome}/dots/theme"
        for f in fzf.fish prompt.fish
            test -r $__dots_theme/$f; and source $__dots_theme/$f
        end
      '';
    };

    home.file = {
      ".config/nvim".source = dotsLink "nvim";
      ".config/ghostty".source = dotsLink "ghostty";
      ".config/tmux".source = dotsLink "tmux";
      ".config/broot".source = dotsLink "broot";
      ".config/ranger".source = dotsLink "ranger";
      ".gnupg/gpg-agent.conf".text = "allow-preset-passphrase\n";

      ".config/btop/btop.conf".source = dotsLink "btop/btop.conf";
      ".config/btop/themes/dots.theme".source =
        config.lib.file.mkOutOfStoreSymlink "${config.xdg.stateHome}/dots/theme/btop.theme";
    };

    home.packages = with pkgs; [
      ripgrep
      fd
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
      ghostscript
      sqlite
      mermaid-cli
      yt-dlp
      imagemagick
      claude-code
    ];
  };
}
