{
  pkgs,
  lib,
  privateConfigs,
  ...
}:

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

  boot.kernel.sysctl."net.ipv4.ip_forward" = true;
  boot.kernel.sysctl = {
    "net.ipv6.conf.all.disable_ipv6"     = 1;
    "net.ipv6.conf.default.disable_ipv6" = 1;
  };

  # Networking
  networking = {
    hostName = "NetworkBox";
    networkmanager.enable = false;

    # physical uplink, no IP here
    interfaces.enp3s0.useDHCP = false;

     # define VLAN devices
    vlans = {
      vlan8 = { id = 8;  interface = "enp3s0"; };
      vlan9 = { id = 9;  interface = "enp3s0"; };
    };

    # WAN: get static IP on VLAN 8
    interfaces.vlan8.ipv4.addresses = [{
      address      = "192.168.8.2";
      prefixLength = 24;
    }];
    defaultGateway = "192.168.8.1";

    # LAN: serve 192.168.9.0/24 on VLAN 9
    interfaces.vlan9.ipv4.addresses = [{
      address      = "192.168.9.1";
      prefixLength = 24;
    }];

    # 3) NAT IPv4 from LAN → WAN
    nat = {
      enable             = true;
      internalInterfaces = [ "vlan9" ];
      externalInterface  = "vlan8";
    };

    # Firewall
    firewall = {
      enable = true;

      # Only listen on your LAN VLAN
      interfaces = [ "vlan9" ];

      # Allow DHCP (67,68) and DNS (53) on LAN
      allowedUDPPorts = [ 53 67 68 ];

      # If you want the AdGuard Home UI reachable:
      allowedTCPPorts = [ 22 3000 ];

      # Masquerade/NAT is handled separately; make sure forwarding is on:
      # (NixOS will auto–allow established+related on forwarded packets)
      extraCommands = let
        tbl = "${toString tableNum}";
      in ''
        # add a rule: from tvIp → tableNum
        ${pkgs.iproute2}/bin/ip rule add from ${tvIp} lookup ${tbl} priority 100
        # in that table, send default → tun0
        ${pkgs.iproute2}/bin/ip route add default dev ${vpnInterface} table ${tbl}
      '';  # :contentReference[oaicite:1]{index=1}
      };
  };

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # List packages installed in system profile.
  # To search, go https://search.nixos.org/packages?channel=25.05&
  environment.systemPackages = with pkgs; [
    vim
    git
    nodePackages_latest.nodejs
    home-manager
    htop
    tcpdump
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
      interface = "vlan9";
      bind-interfaces = true;

      # Only DHCP
      port = 0; # <--- this disables the DNS server in dnsmasq!

      dhcp-range    = "192.168.9.100,192.168.9.200,24h";
      dhcp-option   = [ "3,192.168.9.1" "6,192.168.9.1" ];
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
          "192.168.9.1"
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

  # Tell NixOS to symlink your private VPN file into /etc/openvpn
  environment.etc."openvpn/vpn.conf" = {
    source = "/etc/vpn/AirVPN_Taiwan_UDP-443-Entry3.conf";
  };

  # Then later, set up the OpenVPN client:
  services.openvpn.servers.vpn = {
    autoStart = true;
    config    = ''
      config /etc/openvpn/vpn.conf
      pull-filter ignore redirect-gateway
    '';
  };
}
