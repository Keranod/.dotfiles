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

  boot.kernel.sysctl."net.ipv4.ip_forward" = true;
  boot.kernel.sysctl = {
    "net.ipv6.conf.all.disable_ipv6"     = 1;
    "net.ipv6.conf.default.disable_ipv6" = 1;
  };
  # Networking
  networking = {
    hostName = "VMNixOSWork";
    networkmanager.enable = false;

    interfaces.enp0s3.useDHCP = true;

    interfaces.enp0s8 = {
      useDHCP = false;
      ipv4.addresses = [ { address = "192.168.56.10"; prefixLength = 24; } ];
    };

     nat = {
      enable             = true;
      internalInterfaces = [ "enp0s8" ];
      externalInterface  = "enp0s3";
    };
  };

  # === only set proxy vars in shells when enp0s3 is actually up ===
    environment.etc."profile.d/proxy-enp0s3.sh".text = ''
      #!/usr/bin/env bash
      if ip -4 addr show enp0s3 | grep -q "inet "; then
        export http_proxy="http://192.9.253.10:80"
        export https_proxy="$http_proxy"
        export no_proxy="127.0.0.1,localhost,192.168.56.10"
        sudo systemctl set-environment http_proxy="http://proxy:3128" https_proxy="http://proxy:3128"
        sudo systemctl restart nix-daemon
      fi
    '';
    environment.etc."profile.d/proxy-enp0s3.sh".mode = "0755";

  services.dnsmasq = {
    enable = true;
    settings = {
      interface = "enp0s8";
      bind-interfaces = true;

      # Only DHCP
      port = 0; # <--- this disables the DNS server in dnsmasq!

      dhcp-range    = "192.168.56.100,192.168.56.200,24h";
      dhcp-option   = [ "3,192.168.56.10" "6,192.168.56.10" ];
      dhcp-host = [
        "7C:F1:7E:6C:60:00,192.168.9.2" # TP-Link
        "A8:23:FE:FD:19:ED,192.168.9.50" # TV
      ];
    };
  };

  # AdGuard Home: DNS
  services.adguardhome = {
    enable = true;
    openFirewall = true; # auto-opens 53 & 3000
    mutableSettings = false; # re-seed on service start

    settings = {
      # DNS
      dns = {
        bind_hosts = [
          "192.168.56.10"
        ];
        port = 53;
        upstream_dns = [
          "94.140.14.14"
          "94.140.15.15"
        ];
        # Bootstrap DNS: used only to resolve the upstream hostnames
        bootstrap_dns = [
          "9.9.9.10"
          "149.112.112.10"
        ];
      };

      # DHCP
      dhcp = {
        enabled = false;
      };

      # Blocklists / filtering (defaults)
      filtering = {
        protection_enabled = true;
        filtering_enabled = true;
        parental = false;
      };
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
}
