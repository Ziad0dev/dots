{ ... }:

{
  dconf.settings = {
    "org/virt-manager/virt-manager/connections" = {
      autoconnect = [ "qemu:///system" ];
      uris = [ "qemu:///system" ];
    };

    "org/virt-manager/virt-manager" = {
      xmleditor-enabled = true;
    };
    "org/virt-manager/virt-manager/console" = {
      auto-redirect = false;
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
