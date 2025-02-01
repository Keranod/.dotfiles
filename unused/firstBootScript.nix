{ config, pkgs, ... }:

let
  firstBootScript = "/home/keranod/.dotfiles/firstBootScript.sh";
in
{
  systemd.services.firstBootScript = {
    description = "firstBootScript";
    after = [ "network.target" ];

    serviceConfig.ExecStart = ''
      ${pkgs.bash}/bin/bash ${firstBootScript}
    '';

    wantedBy = [ "multi-user.target" ];
  };
}
