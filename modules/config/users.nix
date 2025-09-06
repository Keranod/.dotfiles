{ pkgs, ... }:

{
  users.users.keranod = {
    isNormalUser = true;
    extraGroups = [
      "networkmanager"
      "wheel"
    ]; # Allow sudo
    home = "/home/keranod";
    shell = pkgs.bash;
    initialPassword = "12345";
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDx0poZ9Mj3KRbv45wlVsDjMo+f0Dkeiy1B2TaoekCWc keranod@TufNix"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILRtV1pre9LK6ZObyyQNZ38KgNW8wIfHwwt5WclGbFsB"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAID2Dz0LCMdWC/gW3jcmkrZt0emKoG000YCcdugcHD4d0 konrad.konkel@wp.pl"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIO5ImRifgMIp93zuqYkdfON3y8j73K2G1r/57iAS4PWQ keranod@NetworkBox"
    ];
  };

  users.users.root = {
    initialPassword = "12345";
  };
}
