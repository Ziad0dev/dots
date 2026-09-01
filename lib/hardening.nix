{
  NoNewPrivileges = true;
  PrivateTmp = true;
  PrivateDevices = true;
  ProtectHome = true;
  ProtectSystem = "full";
  ProtectKernelTunables = true;
  ProtectKernelModules = true;
  ProtectKernelLogs = true;
  ProtectControlGroups = true;
  ProtectClock = true;
  ProtectHostname = true;
  ProtectProc = "invisible";
  RestrictNamespaces = true;
  RestrictRealtime = true;
  RestrictSUIDSGID = true;
  LockPersonality = true;
  SystemCallArchitectures = "native";
  CapabilityBoundingSet = [ "" ];
  RestrictAddressFamilies = [
    "AF_INET"
    "AF_INET6"
    "AF_UNIX"
    "AF_NETLINK"
  ];
}
