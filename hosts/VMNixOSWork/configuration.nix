{
  pkgs,
  lib,
  ...
}:

{
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
  ];

  # Default settings for EFI
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  fileSystems."/boot" = {
    fsType = "vfat";
  };

  # Virtualbox guest additions
  systemd.services.virtualbox.unitConfig.ConditionVirtualization = "oracle";
  # Enable VirtualBox guest additions
  virtualisation.virtualbox.guest = {
    enable = true;
    seamless = true;
    clipboard = true;
  };

  # Networking
  networking = {
    hostName = "VMNixOSWork";
    networkmanager.enable = false;

    interfaces.enp0s3.useDHCP = true;

    interfaces.enp0s8 = {
      useDHCP = false;
      address = "192.168.56.10";
      prefixLength = 24;
    };

     nat = {
      enable             = true;
      internalInterfaces = [ "enp0s8" ];
      externalInterface  = "enp0s3";
    };
  };

  # List packages installed in system profile.
  # To search, go https://search.nixos.org/packages?channel=24.11&
  environment.systemPackages = with pkgs; [
    vim
    git
    nodePackages_latest.nodejs
    home-manager
    htop
    tcpdump
    openvpn
  ];

  # Enable the OpenSSH daemon.
  # services.openssh.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [
  # ];
  # networking.firewall.allowedUDPPorts = [
  # ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # === only set proxy vars in shells when enp0s3 is actually up ===
    environment.etc."profile.d/proxy-enp0s3.sh".text = ''
      #!/usr/bin/env bash
      if ip -4 addr show enp0s3 | grep -q "inet "; then
        export http_proxy="http://192.9.253.10:80"
        export https_proxy="$http_proxy"
        export no_proxy="127.0.0.1,localhost,192.168.56.10"
      fi
    '';
    environment.etc."profile.d/proxy-enp0s3.sh".mode = "0755";
}
