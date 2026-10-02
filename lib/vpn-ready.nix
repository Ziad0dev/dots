pkgs:

pkgs.writeShellScript "wait-for-vpn-dns" ''
  i=0
  err=
  while [ $i -lt 40 ]; do
    err=$(${pkgs.curl}/bin/curl -sS -o /dev/null --max-time 5 https://indexers.prowlarr.com/ 2>&1) && exit 0
    ${pkgs.coreutils}/bin/sleep 2
    i=$((i + 1))
  done
  echo "vpn dns still unhealthy after 80s, continuing anyway (last error: ''${err:-none})" >&2
  exit 0
''
