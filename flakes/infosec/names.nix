{
  core = [
    "nmap"
    "tcpdump"
    "wireshark"
    "socat"
    "netcat-gnu"
    "openssl"
    "jq"
    "hexyl"
    "proxychains-ng"
  ];

  recon = [
    "masscan"
    "rustscan"
    "naabu"
    "dnsx"
    "subfinder"
    "amass"
    "httpx"
    "katana"
    "gau"
    "waybackurls"
    "whatweb"
    "dnsrecon"
    "theharvester"
    "asnmap"
    "fierce"
  ];

  web = [
    "burpsuite"
    "zap"
    "sqlmap"
    "ffuf"
    "feroxbuster"
    "gobuster"
    "nuclei"
    "nikto"
    "wpscan"
    "dalfox"
    "arjun"
    "testssl"
    "sslscan"
    "mitmproxy"
    "wafw00f"
  ];

  binary = [
    "ghidra-bin"
    "rizin"
    "cutter"
    "radare2"
    "gdb"
    "gef"
    "imhex"
    "binwalk"
    "yara"
    "upx"
    "patchelf"
    "elfutils"
    "rr"
    "ltrace"
    "strace"
    "lldb"
    "detect-it-easy"
    "file"
  ];

  pwn = [
    "python3Packages.pwntools"
    "python3Packages.angr"
    "python3Packages.ropgadget"
    "one_gadget"
    "checksec"
    "aflplusplus"
    "honggfuzz"
    "radamsa"
    "qemu"
    "gdb"
  ];

  ad = [
    "netexec"
    "python3Packages.impacket"
    "bloodhound"
    "bloodhound-py"
    "kerbrute"
    "evil-winrm"
    "responder"
    "certipy"
    "smbmap"
    "enum4linux-ng"
    "python3Packages.ldapdomaindump"
    "freerdp"
    "krb5"
    "samba"
  ];

  crack = [
    "hashcat"
    "hashcat-utils"
    "john"
    "thc-hydra"
    "medusa"
    "haiti"
    "hash-identifier"
    "cyberchef"
  ];

  postex = [
    "metasploit"
    "chisel"
    "ligolo-ng"
    "sshuttle"
    "exploitdb"
  ];

  wireless = [
    "aircrack-ng"
    "kismet"
    "hcxtools"
    "hcxdumptool"
    "reaverwps-t6x"
    "bully"
    "wifite2"
    "bettercap"
    "mdk4"
    "macchanger"
    "iw"
  ];

  forensics = [
    "volatility3"
    "sleuthkit"
    "autopsy"
    "testdisk"
    "ddrescue"
    "foremost"
    "exiftool"
    "chainsaw"
    "capa"
    "yara"
  ];

  cloud = [
    "trivy"
    "grype"
    "syft"
    "prowler"
    "pacu"
    "kubescape"
    "kube-bench"
    "awscli2"
    "kubectl"
  ];

  mobile = [
    "jadx"
    "apktool"
    "dex2jar"
    "frida-tools"
    "android-tools"
    "scrcpy"
  ];

  wordlists = [
    "wordlists"
    "seclists"
  ];
}
