{ pkgs, config, ... }:

# One environment, three interpreters.
#
# You cannot merge fish, nushell and xonsh — structured pipelines and inline
# Python are properties of those LANGUAGES, and fish can't acquire them. What
# you can share is everything around the language:
#
#   starship   one prompt
#   atuin      one history database (fish history is visible inside nu)
#   zoxide     one directory-jump database
#   carapace   one completion engine (nu + xonsh only, see below)
#   direnv     already shared, configured in home.nix
#
# fish stays the login shell. It keeps its abbreviations, and users.users
# .shell = pkgs.fish stays put — nushell is not POSIX and breaks anything
# assuming sh-like behaviour.
#
# Division of labour:
#   fish    everything, by default
#   nu      structured data — `nu` for a session, `nuf` for one-liners
#   xonsh   Python at the prompt — `xonsh` for a session, `py` for one-liners

{
  home.packages = with pkgs; [
    nushell
    xonsh
    # jc converts the output of ~100 POSIX tools to JSON, which is what makes
    # the fish-side `nuf`/`jqf` helpers genuinely useful rather than a toy:
    #   ps aux | jc --ps | nuf 'from json | where cpu_percent > 10'
    python3Packages.jc
    # jq is already in systemPackages (rescue set) — not repeated here.
  ];

  # ── Shared prompt ────────────────────────────────────────────────────────
  programs.starship = {
    enable = true;
    enableFishIntegration = true;
    enableNushellIntegration = true;
    # No xonsh option exists — wired by hand in .xonshrc below.
    settings = {
      add_newline = false;
      format = "$directory$git_branch$git_status$nix_shell$character";
      character = {
        success_symbol = "[❯](#42be65)";
        error_symbol = "[❯](#ee5396)";
      };
      directory = {
        style = "#33b1ff";
        truncation_length = 3;
        truncate_to_repo = false;
      };
      git_branch.style = "#be95ff";
      git_status.style = "#ee5396";
      nix_shell = {
        symbol = "❄ ";
        style = "#33b1ff";
        format = "[$symbol$name]($style) ";
      };
    };
  };

  # ── Shared history ───────────────────────────────────────────────────────
  # One SQLite database behind all three shells, so a command typed in fish
  # is in your history inside nu. NOTE: atuin takes over Ctrl-R from fzf.
  # fzf keeps Ctrl-T (files) and Alt-C (dirs), which is the better split —
  # fzf never had cross-shell history to begin with.
  programs.atuin = {
    enable = true;
    enableFishIntegration = true;
    enableNushellIntegration = true;
    flags = [ "--disable-up-arrow" ]; # keep fish's own prefix search on Up
    settings = {
      style = "compact";
      inline_height = 15;
      show_preview = true;
      enter_accept = true;
      filter_mode_shell_up_key_binding = "directory";
      sync_address = ""; # local only — no account, nothing leaves the machine
    };
  };

  # ── Shared completions ───────────────────────────────────────────────────
  # Deliberately NOT enabled for fish: fish's native completions are the best
  # of any shell, and carapace would replace them with something worse. The
  # point of carapace here is giving nu and xonsh fish-grade completions.
  programs.carapace = {
    enable = true;
    enableFishIntegration = false;
    enableNushellIntegration = true;
  };

  # zoxide is enabled in dev-home.nix; add the nushell side here.
  programs.zoxide.enableNushellIntegration = true;

  # fzf and atuin both bind Ctrl-R; home-manager warns unless one yields.
  # atuin wins because it is the cross-shell piece — fzf keeps Ctrl-T (files)
  # and Alt-C (directories), which it does better anyway.
  programs.fzf.historyWidget.command = "";

  # ── Nushell ──────────────────────────────────────────────────────────────
  programs.nushell = {
    enable = true;
    shellAliases = {
      ll = "ls -l";
      la = "ls -la";
      g = "git";
    };
    extraConfig = ''
      $env.config = {
        show_banner: false
        edit_mode: emacs
        table: { mode: rounded, index_mode: auto }
        completions: {
          case_sensitive: false
          quick: true
          partial: true
          algorithm: "fuzzy"
        }
        history: {
          file_format: "sqlite"
          isolation: true
        }
      }

      # Same abbreviation targets as fish, so muscle memory carries over.
      alias update = nh os switch
      alias upall = nh os switch -u
      alias gst = git status
    '';
  };

  # ── Xonsh ────────────────────────────────────────────────────────────────
  # No home-manager module exists, so everything is hand-wired. Each init
  # line is the form that project documents for xonsh specifically.
  home.file.".xonshrc".text = ''
    $XONSH_SHOW_TRACEBACK = True
    $XONSH_HISTORY_BACKEND = "sqlite"
    $AUTO_CD = True
    $COMPLETIONS_CONFIRM = False

    aliases["ll"] = "ls -l"
    aliases["la"] = "ls -la"
    aliases["update"] = "nh os switch"

    execx($(${pkgs.starship}/bin/starship init xonsh))
    execx($(${pkgs.atuin}/bin/atuin init xonsh))
    execx($(${pkgs.zoxide}/bin/zoxide init xonsh), 'exec', __xonsh__.ctx, filename='zoxide')
    exec($(${pkgs.carapace}/bin/carapace _carapace xonsh))
  '';

  # ── Bridges, callable from fish ──────────────────────────────────────────
  # These are wrappers, not integration. Data serialises to text at every
  # boundary and each call is a fresh process, so they suit a one-off
  # transformation mid-pipeline — not multi-stage structured work. For that,
  # type `nu`, do the work, exit.
  programs.fish.functions = {
    nuf = {
      description = "run a nu expression over stdin  (ls | nuf 'from json | get name')";
      body = ''
        nu --stdin -c "\$in | $argv"
      '';
    };

    nut = {
      description = "jc a command, then query it with nu  (nut ps aux -- 'where cpu_percent > 10')";
      body = ''
        set -l split (contains -i -- -- $argv)
        if test -z "$split"
          echo "usage: nut <command...> -- '<nu expression>'" >&2
          return 2
        end
        set -l cmd $argv[1..(math $split - 1)]
        set -l expr $argv[(math $split + 1)..-1]
        command $cmd | jc --$cmd[1] | nu --stdin -c "\$in | from json | $expr"
      '';
    };

    py = {
      description = "python/xonsh one-liner, stdin available as \$(cat)";
      body = ''
        xonsh -c "$argv"
      '';
    };

    pyf = {
      description = "pure-python one-liner over stdin, lines in `data`";
      body = ''
        python3 -c "
import sys
data = sys.stdin.read().splitlines()
$argv
"
      '';
    };
  };
}
