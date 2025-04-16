{ pkgs, ... }:

{
  users.users.keranod = {
    isNormalUser = true;
    extraGroups = [ "networkmanager" "wheel" ];  # Allow sudo
    home = "/home/keranod";
    shell = pkgs.bash;
    initialPassword = "12345";
    openssh.authorizedKeys.keyFiles = [
      (builtins.toFile "keranod_id_rsa.pub" (builtins.readFile ../hosts/TufNix/id_rsa.pub))
    ];
  };

  users.users.root = {
    initialPassword = "12345";
  };
}
