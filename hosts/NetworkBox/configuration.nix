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

  boot.kernel.sysctl."net.ipv6.conf.all.disable_ipv6" = true;
  boot.kernel.sysctl."net.ipv6.conf.default.disable_ipv6" = true;
  boot.kernel.sysctl."net.ipv6.conf.lo.disable_ipv6" = true;

  # Networking
  networking = {
    hostName = "NetworkBox";
    networkmanager.enable = false;

    enableIPv6 = false;

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

    nat = {
      enable = true;
      internalInterfaces = [ ]; # your LAN side interface
      externalInterface = "enp3s0"; # same interface because Huawei is upstream
      enableIPv6 = false; # no IPv6
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
        ip6tables -P INPUT DROP
        ip6tables -P FORWARD DROP
        ip6tables -P OUTPUT DROP
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
        "A8:23:FE:FD:19:ED,192.168.8.50" # TV
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
          "0.0.0.0"
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
        # interface_name = "enp3s0";
        # local_domain_name = "lan";
        # dhcpv4 = {
        #   gateway_ip = "192.168.8.2";
        #   subnet_mask = "255.255.255.0";
        #   range_start = "192.168.8.100";
        #   range_end = "192.168.8.200";
        #   lease_duration = 0;
        # };
        # static_leases = {
        #   "e0:cc:f8:fa:fb:42" = "192.168.8.50"; # TV’s MAC → .50
        # };
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
