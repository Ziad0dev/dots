{ ... }:
{
  # hyprlock authenticates through PAM but ships no service file of its own.
  # Without this it logs "Pam module /etc/pam.d/hyprlock does not exist" and
  # falls back to /etc/pam.d/su, which works but is not the intended path.
  security.pam.services.hyprlock = { };
}
