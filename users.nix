{ config, pkgs, ... }:

{
  users.users.keranod = {
    isNormalUser = true;
    extraGroups = [ "networkmanager" "wheel" ];  # Allow sudo
    home = "/home/keranod";
    shell = pkgs.bash;
    hashedPassword = "";  # Forces password change on first login
  };

  users.users.root = {
    hashedPassword = "";  # Forces password change on first login
  };
}
