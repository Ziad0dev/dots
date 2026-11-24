{
  config,
  lib,
  pkgs,
  ...
}:

# Download bufferbloat, fixed on this machine. A full download fills a queue
# upstream (the ISP side), and everything else waits behind it: pings went
# from 5 ms idle to 69 ms average and 221 ms peaks. The gateway's Smart Queues
# fix that but its CPU tops out around 730 Mb/s on a gigabit line, so the
# shaping happens here instead: incoming internet traffic is redirected to an
# IFB device and shaped with CAKE a little below the line rate, which moves
# the queue to this machine, where CAKE keeps it short and fair.
#
# Only internet traffic is shaped: sources in `lanSubnets` (the LAN, IoT and
# guest VLANs, the media servers' clients) pass at full speed. Upload is left
# to the default fq_codel: it showed no bufferbloat. This protects this
# machine's own traffic; another device saturating the line still affects it.
let
  cfg = config.dots.sqm;
  iface = config.dots.lanInterface;
  ifb = "ifb-sqm";

  sqm = pkgs.writeShellApplication {
    name = "dots-sqm";
    runtimeInputs = [ pkgs.iproute2 ];
    text = ''
      iface=${lib.escapeShellArg iface}
      ifb="${ifb}"
      stop() {
        tc qdisc del dev "$iface" ingress 2>/dev/null || true
        ip link del "$ifb" 2>/dev/null || true
      }
      case "''${1:-}" in
        start)
          # idempotent: a restart rebuilds it from scratch
          stop
          ip link add name "$ifb" type ifb
          ip link set "$ifb" up
          tc qdisc add dev "$iface" handle ffff: ingress
          # local sources skip the shaper (accepted here, never redirected)
          ${lib.concatMapStringsSep "\n" (net: ''
            tc filter add dev "$iface" parent ffff: protocol ip prio 1 u32 match ip src ${net} action ok
          '') cfg.lanSubnets}
          tc filter add dev "$iface" parent ffff: protocol all prio 2 matchall \
            action mirred egress redirect dev "$ifb"
          tc qdisc replace dev "$ifb" root cake bandwidth ${cfg.download} besteffort ingress
          ;;
        stop) stop ;;
        *) echo "usage: dots-sqm start|stop" >&2; exit 2 ;;
      esac
    '';
  };
in
{
  options.dots.sqm = {
    enable = lib.mkEnableOption "CAKE shaping of internet downloads on the LAN interface (bufferbloat)";
    download = lib.mkOption {
      type = lib.types.strMatching "[0-9]+(kbit|mbit|gbit)";
      default = "900mbit";
      example = "450mbit";
      description = ''
        Rate incoming internet traffic is shaped to. It must sit a little
        below the line's real download speed, or the queue stays upstream
        and nothing improves; about 95 % of a measured speed test is a good
        start.
      '';
    };
    lanSubnets = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "10.0.0.0/8"
        "172.16.0.0/12"
        "192.168.0.0/16"
      ];
      description = "IPv4 source networks that are never shaped (the local networks).";
    };
  };

  config = lib.mkIf cfg.enable {
    # loaded at boot: the service's sandbox can't load modules itself
    boot.kernelModules = [
      "ifb"
      "sch_cake"
      "act_mirred"
      "cls_u32"
      "cls_matchall"
    ];

    systemd.services.dots-sqm = {
      description = "CAKE shaping of internet downloads (bufferbloat)";
      wantedBy = [ "multi-user.target" ];
      # the interface must exist; the unit follows it if it goes away
      bindsTo = [ "sys-subsystem-net-devices-${iface}.device" ];
      after = [ "sys-subsystem-net-devices-${iface}.device" ];
      unitConfig.StartLimitBurst = 5;
      serviceConfig = import ../lib/hardening.nix // {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${lib.getExe sqm} start";
        ExecStop = "${lib.getExe sqm} stop";
        # tc and ip link need the network admin capability, nothing more
        CapabilityBoundingSet = [ "CAP_NET_ADMIN" ];
        AmbientCapabilities = [ "CAP_NET_ADMIN" ];
      };
    };
  };
}
