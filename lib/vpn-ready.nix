pkgs:

pkgs.writeShellScript "wait-for-vpn-dns" ''
  i=0
  while [ $i -lt 40 ]; do
    ${pkgs.getent}/bin/getent hosts mullvad.net >/dev/null 2>&1 && exit 0
    ${pkgs.coreutils}/bin/sleep 2
    i=$((i + 1))
  done
  exit 1
''
