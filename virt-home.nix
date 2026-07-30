{ ... }:

# virt-manager, declaratively. Without this it opens on qemu:///session — a
# per-user daemon with no networks and no access to the /data pool — and every
# guide's `virsh` output looks nothing like what the GUI shows.
#
# programs.dconf.enable is already true system-wide (configuration.nix), which
# is what makes HM's dconf writes stick.

{
  dconf.settings = {
    "org/virt-manager/virt-manager/connections" = {
      autoconnect = [ "qemu:///system" ];
      uris = [ "qemu:///system" ];
    };

    # Sensible console defaults: grab keyboard only when the console has focus,
    # resize the guest display with the window, and skip the "are you sure"
    # prompts that get in the way of iterating on throwaway VMs.
    "org/virt-manager/virt-manager" = {
      xmleditor-enabled = true; # edit domain XML in the GUI, no virsh round-trip
    };
    "org/virt-manager/virt-manager/console" = {
      auto-redirect = false; # don't hijack USB devices automatically
      resize-guest = 1;
      scaling = 2;
    };
    "org/virt-manager/virt-manager/confirm" = {
      forcepoweroff = false;
      removedev = false;
    };
    "org/virt-manager/virt-manager/new-vm" = {
      graphics-type = "spice";
      cpu-default = "host-passthrough";
      storage-format = "qcow2";
    };
  };
}
