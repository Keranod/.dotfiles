{ pkgs, ... }:

{
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
  ];

  # Default settings for EFI
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = false;
  fileSystems."/boot" = {
    fsType = "vfat";
  };

  # Networking
  networking = {
    hostName = "NetworkBox";
    networkmanager.enable = false;

    # Static IP on enp3s0
    interfaces.enp3s0 = {
      useDHCP = false;
      ipv4.addresses = [
        {
          address = "192.168.8.2";
          prefixLength = 24;
        }
      ];
    };

    defaultGateway = "192.168.8.1";
    nameservers = [ "127.0.0.1" ];

    firewall = {
      enable = true;
      # DNS + DHCP (67 & 68) + AdGuard UI (3000)
      allowedUDPPorts = [
        53
        67
        68
      ];
    };
  };

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # List packages installed in system profile.
  # To search, go https://search.nixos.org/packages?channel=24.11&
  environment.systemPackages = with pkgs; [
    vim
    git
    nodePackages_latest.nodejs
    home-manager
    htop
  ];

  # Enable the OpenSSH service
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false; # Disable password login
      PermitRootLogin = "no"; # Root login disabled
      PubkeyAuthentication = true; # Ensure pubkey authentication is enabled
    };
  };

  # AdGuard Home: DNS + DHCP
  services.adguardhome = {
    enable = true;
    openFirewall = true; # auto-opens 53 & 3000
    mutableSettings = false; # re-seed on service start

    settings = {
      # DNS
      dns = {
        bind_hosts = [
          "0.0.0.0"
          "::"
        ];
        port = 53;
        upstream_dns = [
          "94.140.14.14"
          "94.140.15.15"
          "2a10:50c0::ad1:ff"
          "2a10:50c0::ad2:ff"
        ];
        # Bootstrap DNS: used only to resolve the upstream hostnames
        bootstrap_dns = [
          "9.9.9.10"
          "149.112.112.10"
          "2620:fe::10"
          "2620:fe::fe:10"
        ];
      };

      # DHCP
      dhcp = {
        enabled = true;
        interface_name = "enp3s0";
        local_domain_name = "lan";
        dhcpv4 = {
          gateway_ip = "192.168.8.1";
          subnet_mask = "255.255.255.0";
          range_start = "192.168.8.100";
          range_end = "192.168.8.200";
          lease_duration = 0;
        };
        dhcpv6 = {
          ra_slaac_only = true;
        };

        static_leases = {
          "A8:23:FE:FD:19:ED" = "192.168.8.50"; # TV’s MAC → .50
        };
      };

      # Blocklists / filtering (defaults)
      filtering = {
        protection_enabled = true;
        filtering_enabled = true;
        parental = false;
      };
    };
  };
}
