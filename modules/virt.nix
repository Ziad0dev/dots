{ config, lib, pkgs, username, ... }:

# ── Virtualisation (libvirt / QEMU-KVM + virt-manager) ────────────────────────
# Wire into flake.nix alongside gaming.nix / llm.nix / davinci.nix.
#
# Ownership notes (the "one owner per path" rule):
#   • This file owns the whole `virtualisation.libvirtd` tree, `programs.virt-manager`
#     and `virtualisation.spiceUSBRedirection`.
#   • `virtualisation.docker` stays in configuration.nix — untouched here.
#   • `users.users.${username}.extraGroups` is also set in configuration.nix.
#     That's fine: it's a listOf str, so NixOS *merges* the definitions rather
#     than conflicting. If you'd rather keep users in one place, delete the
#     block below and append "libvirtd" to the list in configuration.nix.
#   • `programs.dconf.enable` is already true in configuration.nix (virt-manager
#     needs it) — deliberately not repeated.
#   • kvm-intel is already in hardware-configuration.nix's boot.kernelModules.
#
# Hardware context: i5-12400F (VT-x + VT-d, no E-cores, **no iGPU**) and a
# single RTX 3060. See the passthrough note at the bottom before you get ideas.

{
  # ── libvirtd ────────────────────────────────────────────────────────────────
  virtualisation.libvirtd = {
    enable = true;

    # /data is LUKS + `nofail`, unlocked post-boot via crypttab keyfile, and the
    # image pool lives there — so libvirtd must not try to autostart guests
    # before the mount exists. "ignore" = leave running guests alone on
    # daemon restart (a rebuild switch won't kill your VMs).
    onBoot = "ignore";
    onShutdown = "shutdown";

    qemu = {
      package = pkgs.qemu_kvm;

      # Guests run as the qemu-libvirtd user, not root. libvirt chowns each
      # disk image on domain start (dynamic ownership), which is why the pool
      # dir below only needs to be traversable by others.
      runAsRoot = false;

      # No ovmf block: the submodule was removed (nixpkgs #421549). libvirtd now
      # reads QEMU's own firmware descriptors from
      #   ${pkgs.qemu_kvm}/share/qemu/firmware/*.json
      # and symlinks the blobs into /run/libvirt/nix-ovmf, with the rewritten
      # metadata at /var/lib/qemu/firmware. The edk2 x86_64 *secure*-code
      # variant ships in there, so Secure Boot for Windows 11 guests still
      # works — just pick "UEFI x86_64: secboot" in virt-manager's firmware
      # dropdown instead of naming a path. pkgs.OVMFFull is no longer involved.

      # Software TPM — the other Windows 11 requirement.
      swtpm.enable = true;

      # NixOS-specific: libvirt discovers vhost-user helpers through JSON
      # descriptors in /var/lib/qemu/vhost-user, which this option populates.
      # Without it, virtiofs filesystem devices fail with "cannot find
      # virtiofsd binary" no matter what's in systemPackages.
      vhostUserPackages = [ pkgs.virtiofsd ];
    };
  };

  # The default NAT network's virbr0 comes up when libvirtd starts, but /data
  # (where the image pool lives) is a nofail mount that unlocks after boot.
  systemd.services.libvirtd = {
    wants = [ "data.mount" ];
    after = [ "data.mount" ];
  };

  # ── Group membership ────────────────────────────────────────────────────────
  # Merged with the list in configuration.nix (see header note).
  #   libvirtd → talk to qemu:///system without polkit prompts
  #   kvm      → /dev/kvm directly, which quickemu needs (it bypasses libvirt)
  # Log out and back in after the first switch; groups aren't picked up by a
  # running session.
  users.users.${username}.extraGroups = [ "libvirtd" "kvm" ];

  # ── Frontends ───────────────────────────────────────────────────────────────
  # Enables the app *and* the polkit/dconf glue. Note virt-manager still
  # defaults to qemu:///session on first launch — virt-home.nix pins it to
  # qemu:///system so it actually sees this daemon's networks and pools.
  programs.virt-manager.enable = true;

  # Pass USB devices into guests from the virt-manager UI without root.
  virtualisation.spiceUSBRedirection.enable = true;

  environment.systemPackages = with pkgs; [
    virt-viewer   # standalone SPICE/VNC console
    spice-gtk     # clipboard sharing, dynamic resolution, USB redirection
    virtio-win    # virtio driver ISO for Windows guests (renamed from win-virtio
                  # 2025-10-27; unfree, which allowUnfree already covers).
                  # Mount as a second CD-ROM during install.
    libguestfs-with-appliance # virt-df / virt-cat / virt-sparsify. The plain
                  # libguestfs attr builds the tools but ships no appliance, so
                  # every command dies at runtime looking for one.

    # Moved here from configuration.nix — this file owns VM tooling now.
    qemu          # qemu-img and friends outside of libvirt
    quickemu      # throwaway VMs, doesn't touch libvirt at all
  ];

  # ── Image pool on /data ─────────────────────────────────────────────────────
  # Root is only 324 GiB and shared with /nix/store; /data has ~617 GiB.
  #   0771 root:libvirtd → you (in libvirtd) can create images, qemu-libvirtd
  #   gets +x to traverse and libvirt chowns the image file itself.
  # libvirt storage pools are imperative state; define it once after the first
  # switch (commands in the notes at the bottom).
  systemd.tmpfiles.rules = [
    "d /data/vms 0771 root libvirtd -"
    "d /data/vms/iso 0771 ${username} libvirtd -"
  ];

  # ── Networking ──────────────────────────────────────────────────────────────
  # networking.firewall is on (NixOS default) and nothing else in the repo
  # touches it. libvirt installs its own NAT rules, but the host firewall still
  # drops guest→host traffic, which breaks guest DNS/DHCP in some setups and
  # any "reach the host's dev server from the VM" workflow. Trusting virbr0
  # fixes both. Drop this line if you'd rather guests couldn't reach host
  # services — you'll likely need a 53/67 exception on virbr0 instead.
  networking.firewall.trustedInterfaces = [ "virbr0" ];

  # NetworkManager (configuration.nix) leaves libvirt-managed bridges alone by
  # default — no unmanaged-devices stanza needed.
  #
  # Docker is also enabled and sets the FORWARD policy to DROP. Subnets don't
  # collide (docker0 172.17/16 vs virbr0 192.168.122/24) and libvirt inserts
  # its own ACCEPT rules, but if guest networking ever dies right after a
  # docker restart, that ordering is the first thing to check:
  #   sudo iptables -L FORWARD -n --line-numbers
  #   sudo systemctl restart libvirtd  # re-inserts libvirt's rules

  # ── Optional bits, left off on purpose ──────────────────────────────────────
  #
  # Nested virtualisation (running a hypervisor *inside* a guest — Docker
  # Desktop, WSL2, or a NixOS installer testing KVM):
  #   boot.extraModprobeConfig = "options kvm_intel nested=1";
  #
  # GPU passthrough: don't. The 12400F is an F-part with no iGPU, so the 3060
  # is your only display adapter — that's single-GPU passthrough, meaning the
  # host session dies on VM start and comes back on shutdown, driven by
  # hook scripts. It also fights the nvidia-open + Hyprland/Plasma setup.
  # If you ever add a cheap second GPU, the starting point is:
  #   boot.kernelParams = [ "intel_iommu=on" "iommu=pt" ];
  #   boot.initrd.kernelModules = [ "vfio_pci" "vfio_iommu_type1" "vfio" ];
  #   boot.extraModprobeConfig = "options vfio-pci ids=10de:2504,10de:228e";
  # (kernelParams is a list, so it merges cleanly with gaming.nix.)
  #
  # Hugepages are deliberately absent: 15.4 GiB total RAM with zram at 50%
  # means pinned hugepages would just squeeze the host. See the sizing note.

  # ── Sizing / usage notes ────────────────────────────────────────────────────
  # First run, after `nixos-rebuild switch` and a re-login (group membership):
  #
  #   virsh net-autostart default && virsh net-start default
  #   virsh pool-define-as vms dir --target /data/vms
  #   virsh pool-autostart vms && virsh pool-start vms
  #   virsh pool-define-as iso dir --target /data/vms/iso
  #   virsh pool-autostart iso && virsh pool-start iso
  #
  # Guest defaults that suit this box:
  #   • CPU: 4 vCPUs (of 12 threads), model = host-passthrough. No E-cores on
  #     the 12400F, so no topology games needed.
  #   • RAM: 4–6 GiB, and enable the memballoon device. 16 GiB total with
  #     zram-at-50% means an 8 GiB guest will start pushing host pages into
  #     compressed swap — you're paying CPU to hold guest RAM.
  #   • Disk: qcow2 on /data/vms with cache=none, io=native, discard=unmap.
  #   • Video: virtio + 3D acceleration off unless you need it; SPICE display.
  #   • Shared folder: filesystem device, driver virtiofs, then in the guest
  #     `mount -t virtiofs <tag> /mnt/host`.
}
