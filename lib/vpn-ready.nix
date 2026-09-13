pkgs:

pkgs.writeShellScript "wait-for-vpn-dns" ''
  i=0
  while [ $i -lt 40 ]; do
    ${pkgs.curl}/bin/curl -s -o /dev/null --max-time 5 https://indexers.prowlarr.com/ && exit 0
    ${pkgs.coreutils}/bin/sleep 2
    i=$((i + 1))
  done
  echo "vpn dns still unhealthy after 80s, continuing anyway" >&2
  exit 0
''
