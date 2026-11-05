# Policy checks on the *evaluated* NixOS configuration: things that turn into a
# vulnerable or slow machine without any build error telling you so.
#
#   nix eval --json --apply 'cfg: import ./tests/policy.nix { inherit cfg; }' \
#     .#nixosConfigurations.nixos.config
#
# Returns { failures = [ "..." ]; stats = { ... }; }. scripts/audit.sh policy
# prints the failures and exits non-zero when there are any. Only `builtins` is
# used so the expression stays trivially cheap to evaluate.
#
# Every rule is a regression guard for a property the config has today. If you
# change one on purpose, change it here in the same commit.
{ cfg }:
let
  inherit (builtins)
    attrNames
    elem
    filter
    foldl'
    isAttrs
    isList
    isString
    length
    match
    ;

  # --- tunables ---------------------------------------------------------------

  # UDP ports allowed to be open on every interface (tailscale's WireGuard port).
  # TCP is expected to be closed globally: open it per-interface instead.
  allowedGlobalUdp = [ 41641 ];

  # Budgets for "the machine got slower to boot / busier in the background".
  # Set a little above today's numbers; raise them deliberately, not by accident.
  maxBootServices = 60; # system units wanted by multi-user/graphical/sysinit (today: 48)
  maxTimers = 15; # system timers (today: 11)
  maxUserBootServices = 25; # home-manager user units started with the session

  # Stock NixOS units that legitimately restart fast (display-manager: 200ms).
  crashLoopAllow = [ "display-manager" ];

  # --- helpers ----------------------------------------------------------------

  get =
    path: default: set:
    foldl' (acc: k: if isAttrs acc && acc ? ${k} then acc.${k} else default) set path;

  when = cond: msg: if cond then [ ] else [ msg ];
  anyOf = pred: list: length (filter pred list) > 0;
  names = set: if isAttrs set then attrNames set else [ ];

  # "30s", "5min", "1h", "100ms", "2" -> seconds (null if unparseable)
  seconds =
    v:
    let
      s = toString v;
      m = match "([0-9]+)(ms|s|sec|second|seconds|m|min|minutes?|h|hr|hours?)?" s;
    in
    if m == null then
      null
    else
      let
        n = builtins.fromJSON (builtins.elemAt m 0);
        u = builtins.elemAt m 1;
      in
      if u == "ms" then
        n / 1000.0
      else if u == null || u == "s" || u == "sec" || u == "second" || u == "seconds" then
        n * 1.0
      else if u == "m" || u == "min" || u == "minute" || u == "minutes" then
        n * 60.0
      else
        n * 3600.0;

  wantedBy = u: u.wantedBy or [ ];
  bootTargets = [
    "multi-user.target"
    "graphical.target"
    "sysinit.target"
    "basic.target"
  ];

  services = cfg.systemd.services;
  timers = cfg.systemd.timers;
  enabledTimers = filter (
    n: (timers.${n}.enable or true) && (timers.${n}.timerConfig or null) != null
  ) (names timers);
  bootServices = filter (
    n: (services.${n}.enable or true) && anyOf (t: elem t bootTargets) (wantedBy services.${n})
  ) (names services);

  hmUser = cfg.home-manager.users or { };
  userBoot = foldl' (
    acc: u:
    let
      us = get [ "systemd" "user" "services" ] { } hmUser.${u};
    in
    # home-manager spells it Install.WantedBy; any non-empty list = started with a session
    acc + length (filter (n: ((us.${n}.Install or { }).WantedBy or [ ]) != [ ]) (names us))
  ) 0 (names hmUser);

  kernelParams = cfg.boot.kernelParams or [ ];
  badParam = "(mitigations=off|nopti|pti=off|nospectre_v[12]|spectre_v2=off|l1tf=off|mds=off|tsx_async_abort=off|retbleed=off|nokaslr|module\\.sig_enforce=0)";

  users = cfg.users.users;
  normalUsers = filter (n: users.${n}.isNormalUser or false) (names users);

  nixCfg = cfg.nix.settings;
  substituters = nixCfg.substituters or [ ];
  sudoRules = cfg.security.sudo.extraRules or [ ];

  fastTimers = filter (
    n:
    let
      tc = timers.${n}.timerConfig;
      secs = map (k: if tc ? ${k} then seconds tc.${k} else null) [
        "OnUnitActiveSec"
        "OnUnitInactiveSec"
        "OnActiveSec"
      ];
    in
    anyOf (x: x != null && x < 60) secs
  ) enabledTimers;

  crashLoops = filter (
    n:
    let
      sc = services.${n}.serviceConfig or { };
      r = sc.Restart or "no";
      rs = if sc ? RestartSec then seconds sc.RestartSec else null;
    in
    (services.${n}.enable or true)
    && !elem n crashLoopAllow
    && elem r [
      "always"
      "on-failure"
      "on-abnormal"
      "on-abort"
    ]
    && rs != null
    && rs < 1
  ) (names services);

  failures = builtins.concatLists [
    # ---- security -------------------------------------------------------------
    (when (cfg.networking.firewall.enable) "firewall is disabled")
    (when ((cfg.networking.firewall.allowedTCPPorts or [ ]) == [ ])
      "TCP ports are open on every interface (${toString cfg.networking.firewall.allowedTCPPorts}); open them per interface"
    )
    (when (filter (p: !elem p allowedGlobalUdp) (cfg.networking.firewall.allowedUDPPorts or [ ]) == [ ])
      "unexpected UDP port(s) open on every interface: ${
        toString (filter (p: !elem p allowedGlobalUdp) cfg.networking.firewall.allowedUDPPorts)
      }"
    )
    (when (!anyOf (p: match ".*${badParam}.*" p != null) kernelParams)
      "kernel parameter turns off a CPU/KASLR mitigation: ${
        toString (filter (p: match ".*${badParam}.*" p != null) kernelParams)
      }"
    )
    (when (
      (get [ "kernel" "sysctl" "kernel.kptr_restrict" ] 1 cfg.boot) != 0
    ) "kernel.kptr_restrict = 0 leaks kernel addresses")
    (when (
      !(cfg.services.openssh.enable or false)
      || (
        (get [ "settings" "PasswordAuthentication" ] true cfg.services.openssh) == false
        && !elem (get [ "settings" "PermitRootLogin" ] "prohibit-password" cfg.services.openssh) [
          "yes"
        ]
      )
    ) "sshd is enabled with password auth or root login allowed")
    (when (cfg.security.sudo.wheelNeedsPassword) "sudo no longer asks wheel users for a password")
    (when (
      !anyOf (
        r: anyOf (c: c.command == "ALL" && elem "NOPASSWD" (c.options or [ ])) (r.commands or [ ])
      ) sudoRules
    ) "a sudo rule grants passwordless ALL")
    (when ((nixCfg.trusted-users or [ "root" ]) == [ "root" ])
      "nix trusted-users contains non-root entries (trusted = root-equivalent): ${toString nixCfg.trusted-users}"
    )
    (when ((nixCfg.sandbox or true) != false) "nix build sandbox is disabled")
    (when ((nixCfg.require-sigs or true) != false) "nix require-sigs is disabled")
    (when (!anyOf (s: isString s && match "http://.*" s != null) substituters)
      "a nix substituter uses plain http: ${
        toString (filter (s: match "http://.*" s != null) substituters)
      }"
    )
    (when (
      (nixCfg.accept-flake-config or false) != true
    ) "nix accept-flake-config = true lets any flake set substituters and trusted keys")
    (when (
      !anyOf (u: (users.${u}.password or null) != null || (users.${u}.initialPassword or null) != null) (
        names users
      )
    ) "a user has a plaintext password/initialPassword (world-readable in the nix store)")
    (when (
      !anyOf (
        u:
        anyOf (
          g:
          elem g [
            "docker"
            "lxd"
          ]
        ) (users.${u}.extraGroups or [ ])
      ) normalUsers
    ) "a normal user is in the docker/lxd group (root-equivalent); use rootless docker")
    (when ((users.root.hashedPassword or "!") != "") "root has an empty password")

    # ---- performance ----------------------------------------------------------
    (when (
      (cfg.zramSwap.enable or false) || length (cfg.swapDevices or [ ]) > 0
    ) "no swap at all (zram or a swap device): memory pressure will freeze the desktop")
    (when (fastTimers == [ ]) "timer(s) fire more than once a minute: ${toString fastTimers}")
    (when (
      crashLoops == [ ]
    ) "service(s) restart in under a second when they fail (CPU burn loop): ${toString crashLoops}")
    (when (length bootServices <= maxBootServices)
      "${toString (length bootServices)} system units start at boot (budget ${toString maxBootServices}): boot and idle load are creeping up"
    )
    (when (
      length enabledTimers <= maxTimers
    ) "${toString (length enabledTimers)} system timers (budget ${toString maxTimers})")
    (when (userBoot <= maxUserBootServices)
      "${toString userBoot} home-manager user units start at login (budget ${toString maxUserBootServices})"
    )
    (when (
      (cfg.services.beesd.filesystems or { }) == { }
    ) "beesd (continuous dedup) is enabled: constant disk and CPU use")
  ];
in
{
  inherit failures;
  stats = {
    bootServices = length bootServices;
    timers = length enabledTimers;
    userBootServices = userBoot;
    kernelParams = length kernelParams;
  };
}
