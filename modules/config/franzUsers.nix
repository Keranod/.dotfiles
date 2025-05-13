{ pkgs, ... }:

{
  users.users.franz = {
    isNormalUser = true;
    extraGroups = [ "networkmanager" "wheel" ];  # Allow sudo
    home = "/home/franz";
    shell = pkgs.bash;
    initialPassword = "12345";
  };

  users.users.root = {
    initialPassword = "12345";
  };
}
