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
      ipv6.addresses = [
        {
          address = "fd00:1234:5678:1::1";
          prefixLength = 64;
        }
      ];
    };

    nat = {
      enable = true;
      internalInterfaces = [ ]; # your LAN side interface
      externalInterface = "enp3s0"; # same interface because Huawei is upstream
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
      extraInputRules = ''
         # Accept ICMPv6/NDP so RAs get through
        ip6tables -A INPUT -p ipv6-icmp -j ACCEPT

        # Accept DNS (UDP & TCP 53)
        ip6tables -A INPUT -p udp --dport 53 -j ACCEPT
        ip6tables -A INPUT -p tcp --dport 53 -j ACCEPT

        # …then your final DROP policy
        ip6tables -P INPUT DROP

      '';
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

  services.dnsmasq = {
    enable = true;
    settings = {
      interface = "enp3s0";
      bind-interfaces = true;

      # Only DHCP
      port = 0; # <--- this disables the DNS server in dnsmasq!

      dhcp-range = "192.168.8.100,192.168.8.200,255.255.255.0,24h";
      dhcp-option = [
        "3,192.168.8.2" # router/gateway
        "6,192.168.8.2" # DNS server (AdGuard)
      ];
      dhcp-host = [
        "7C:F1:7E:6C:60:00,192.168.8.3" # TP-Link
        "A8:23:FE:FD:19:ED,192.168.8.50" # TV
      ];
    };
  };

  services.radvd = {
    enable = true;
    # This string is exactly what goes into /etc/radvd.conf
    config = ''
        interface enp3s0 {
        AdvSendAdvert on;

        prefix fd00:1234:5678:1::/64 {
          AdvOnLink      on;
          AdvAutonomous  on;
        };

        # your DNS server (AdGuardHome) lives at ::1
        RDNSS fd00:1234:5678:1::1 {
          AdvRDNSSLifetime 600;
        };

        # advertise “lan.local” as the search domain – no quotes around the name
        DNSSL lan.local {
          AdvDNSSLifetime 600;
        };
      };
    '';
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
          "0.0.0.0"
          "::"
        ];
        port = 53;
        upstream_dns = [
          "94.140.14.14"
          "94.140.15.15"
          # "2a10:50c0::ad1:ff"
          # "2a10:50c0::ad2:ff"
        ];
        # Bootstrap DNS: used only to resolve the upstream hostnames
        bootstrap_dns = [
          "9.9.9.10"
          "149.112.112.10"
          # "2620:fe::10"
          # "2620:fe::fe:10"
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
}
