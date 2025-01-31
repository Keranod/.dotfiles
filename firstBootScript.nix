{ config, pkgs, ... }:

let
  firstBootScript = "/home/keranod/.dotfiles/firstBootScript.sh";
in
{
  systemd.services.firstBootScript = {
    description = "firstBootScript";
    after = [ "network.target" ];

    serviceConfig.ExecStart = ''
      if [ ! -x ${firstBootScript} ]; then
        chmod +x ${firstBootScript}
      fi
      ${pkgs.bash}/bin/bash ${firstBootScript}
    '';

    wantedBy = [ "multi-user.target" ];
  };
}
