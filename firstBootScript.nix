{ config, pkgs, ... }:

let
  # Path to your script
  firstBootScript = "/home/keranod/.dotfiles/firstBootScript.sh";
in
{
  systemd.services.firstBootScript = {
    description = "firstBootScript";
    after = [ "network.target" ];

    # Run as root user to allow sudo privileges in the script
    user = "root";
    
    # Execute the script
    serviceConfig.ExecStart = ''
      sudo ${pkgs.bash}/bin/bash ${firstBootScript}
    '';

    # Make the service a one-shot service
    wantedBy = [ "multi-user.target" ];
  };
}
