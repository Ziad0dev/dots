#!/usr/bin/env python3
"""Install the dots `vm` host from the installer ISO onto a blank disk, then
boot it twice and check it: LUKS, sops, home-manager, theme, impermanence.
Drives QEMU over the serial console; takes ~5 minutes with KVM.

    nix build .#nixosConfigurations.installer.config.system.build.isoImage
    nix shell --impure --expr '(builtins.getFlake "nixpkgs").legacyPackages.x86_64-linux.python3.withPackages (p: [ p.pexpect ])' \
      --command python3 tests/iso-install.py result/iso/*.iso $(nix build --print-out-paths nixpkgs#OVMF.fd) [WORKDIR] [--skip-install]

WORKDIR (default ./iso-test) holds the disk image and serial log; --skip-install
re-runs only the boot checks against the disk left by a previous run.
"""
import os, shutil, subprocess, sys, time
import pexpect

ISO = sys.argv[1]
OVMF = sys.argv[2]
_rest = [a for a in sys.argv[3:] if not a.startswith("--")]
S = os.path.abspath(_rest[0] if _rest else "iso-test")
os.makedirs(S, exist_ok=True)
DISK = f"{S}/vm-disk.qcow2"
VARS = f"{S}/vm-vars.fd"
LOG = open(f"{S}/isotest-serial.log", "a")

DISK_PW = "dots-disk"
USER, USER_PW = "ziad0dev", "dots"
PROMPT = "ISOTEST$ "


def qemu(cdrom):
    args = [
        "qemu-system-x86_64", "-enable-kvm", "-machine", "q35", "-cpu", "host",
        "-m", "4096", "-smp", "4", "-display", "none", "-serial", "stdio",
        "-monitor", "none",
        "-drive", f"if=pflash,format=raw,readonly=on,file={OVMF}/FV/OVMF_CODE.fd",
        "-drive", f"if=pflash,format=raw,file={VARS}",
        "-drive", f"file={DISK},if=virtio,format=qcow2",
        "-nic", "user,model=virtio-net-pci",
    ]
    if cdrom:
        args += ["-cdrom", ISO, "-boot", "order=d"]
    p = pexpect.spawn(args[0], args[1:], encoding="utf-8", codec_errors="replace",
                      timeout=600, maxread=65536)
    p.logfile_read = LOG
    return p


def step(msg):
    print(f"\n=== {msg}", flush=True)
    LOG.write(f"\n\n=== {msg} ===\n")
    LOG.flush()


def sh(p, cmd, timeout=120, ok=True):
    """Run cmd in the logged-in shell; return its output. Fails on non-zero if ok."""
    p.sendline(f"{cmd}; echo __RC=$?__")
    p.expect(r"__RC=(\d+)__", timeout=timeout)
    out = p.before
    rc = int(p.match.group(1))
    p.expect_exact(PROMPT, timeout=30)
    # drop the echoed command line
    out = out.split("\n", 1)[1] if "\n" in out else out
    out = out.replace("\r", "").strip()
    print(f"$ {cmd}\n{out}\n[rc={rc}]", flush=True)
    if ok and rc != 0:
        raise SystemExit(f"FAILED: {cmd}")
    return out, rc


def set_prompt(p, shell="bash"):
    if shell == "fish":
        p.sendline(f"function fish_prompt; printf '{PROMPT}'; end; function fish_right_prompt; end; set -g fish_greeting")
    else:
        p.sendline(f"export PS1='{PROMPT}'")
    p.expect_exact(PROMPT, timeout=30)
    p.expect_exact(PROMPT, timeout=30)


def boot_installed(p):
    step("boot from disk: LUKS passphrase")
    p.expect(r"(?i)passphrase for", timeout=300)
    time.sleep(1)
    p.sendline(DISK_PW)
    p.expect(r"vm login: ", timeout=300)
    p.sendline(USER)
    p.expect("Password: ", timeout=60)
    p.sendline(USER_PW)
    # the themed fish prompt isn't predictable; a failed login is
    i = p.expect([r"Cannot execute", r"Login incorrect", pexpect.TIMEOUT], timeout=15)
    if i != 2:
        raise SystemExit("FAILED: login (" + str(p.after) + ")")
    # fish is the login shell; drive a plain bash instead
    p.sendline("exec bash --norc")
    time.sleep(1)
    set_prompt(p)


def main():
    if "--skip-install" in sys.argv:
        return boot_checks()
    for f in (DISK, VARS):
        if os.path.exists(f):
            os.remove(f)
    subprocess.run(["qemu-img", "create", "-f", "qcow2", DISK, "20G"], check=True,
                   stdout=subprocess.DEVNULL)
    shutil.copy(f"{OVMF}/FV/OVMF_VARS.fd", VARS)
    os.chmod(VARS, 0o644)

    step("boot the installer ISO")
    p = qemu(cdrom=True)
    p.expect(r"nixos@nixos:~\]\$", timeout=300)
    set_prompt(p)
    sh(p, "command -v dots-install && ls /etc/dots/hosts")

    step("dots-install vm")
    p.sendline(f"sudo dots-install vm --age-key /etc/dots/hosts/vm/test-age-key.txt; echo __RC=$?__")
    p.expect_exact("disk passphrase: ", timeout=60)
    p.sendline(DISK_PW)
    p.expect_exact("again: ", timeout=30)
    p.sendline(DISK_PW)
    p.expect(r"__RC=(\d+)__", timeout=3600)
    rc = int(p.match.group(1))
    p.expect_exact(PROMPT, timeout=30)
    print(f"dots-install rc={rc}", flush=True)
    if rc != 0:
        raise SystemExit("FAILED: dots-install")
    sh(p, "sudo ls -l /mnt/persist/var/lib/sops-nix/ && sudo lsblk -f /dev/vda")
    sh(p, "sudo stat -c '%a %n' /mnt/nix /mnt/home /mnt/persist /mnt/nix/store")
    p.sendline("sudo poweroff")
    p.expect(pexpect.EOF, timeout=180)
    boot_checks()


def boot_checks():
    step("first boot of the installed system")
    p = qemu(cdrom=False)
    boot_installed(p)
    sh(p, "for m in / /nix /persist /home /boot; do findmnt -no TARGET,FSTYPE,SOURCE $m; done")
    sh(p, "systemctl is-system-running --wait", timeout=300, ok=False)
    sh(p, "systemctl --failed --no-legend")
    sh(p, f"echo {USER_PW} | sudo -S cat /run/secrets/hello")
    sh(p, "readlink ~/.config/nvim ~/.config/tmux")
    sh(p, "cat ~/.local/state/dots/theme/current && ls ~/.local/state/dots/theme | wc -l")
    sh(p, "themectl current && themectl list | wc -l")
    sh(p, "getent passwd " + USER + " | cut -d: -f7")
    sh(p, "systemctl status home-manager-" + USER + " --no-pager | head -5")
    sh(p, "cat /etc/machine-id")
    sh(p, f"echo {USER_PW} | sudo -S sh -c 'touch /etc/ephemeral-test /var/log/persist-test'")
    sh(p, "touch ~/home-persist-test")
    p.sendline(f"echo {USER_PW} | sudo -S reboot")
    p.expect(r"(?i)reboot", timeout=60)

    step("second boot: impermanence")
    boot_installed(p)
    sh(p, "test ! -e /etc/ephemeral-test && echo 'root reset: /etc/ephemeral-test gone'")
    sh(p, "test -e /var/log/persist-test && echo '/var/log kept'")
    sh(p, "test -e ~/home-persist-test && echo '/home kept'")
    sh(p, "cat /etc/machine-id")
    sh(p, "systemctl --failed --no-legend")
    p.sendline(f"echo {USER_PW} | sudo -S poweroff")
    p.expect(pexpect.EOF, timeout=180)
    step("ALL CHECKS PASSED")


if __name__ == "__main__":
    main()
