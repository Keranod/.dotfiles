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
    networkmanager.enable = true;
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

  systemd.services.set-proxy = {
  wantedBy = [ "multi-user.target" ];
  serviceConfig = {
    Type = "oneshot";
    ExecStart = pkgs.writeShellScript "set-proxy" ''
      if ip link show enp0s3 | grep -q "state UP"; then
        echo 'http_proxy=http://192.9.253.10:80' >> /etc/environment
        echo 'https_proxy=http://192.9.253.10:80' >> /etc/environment
      fi
    '';
  };
};

}
