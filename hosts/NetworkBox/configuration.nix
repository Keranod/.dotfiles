{
  pkgs,
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

  boot.kernel.sysctl = {
    # IPv4
    "net.ipv4.ip_forward" = 1; # Enable IPv4 forwarding
    # Enable routing through local networks (needed for the WireGuard VPN setup)
    "net.ipv4.conf.all.route_localnet" = 1;
    "net.ipv4.conf.default.route_localnet" = 1;

    # IPv6
    "net.ipv6.conf.all.forwarding" = 1;
    "net.ipv6.conf.all.disable_ipv6" = 0;
    "net.ipv6.conf.default.disable_ipv6" = 0;
    "net.ipv6.conf.default.forwarding" = 1;
  };

  # Networking
  networking = {
    hostName = "NetworkBox";
    firewall.enable = false;

    # physical uplink, no IP here
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

    # LAN: serve 192.168.9.0/24 on enp0s20u1c2
    interfaces.enp0s20u1c2.ipv4.addresses = [
      {
        address = "192.168.9.1";
        prefixLength = 24;
      }
    ];

    # VPN - use wireguard config, create folder and config files in /etc/wireguard
    # https://airvpn.org/generator/
    # [Interface]
    # [...] <- other config
    # Table = off

    # # after wg0 is up, create routing table & rule:
    # PostUp   = /run/current-system/sw/bin/ip route add default dev %i table 200
    # PostUp   = /run/current-system/sw/bin/ip rule  add from 192.168.9.60/32 table 200 priority 1000

    # # on teardown, clean up:
    # PostDown = /run/current-system/sw/bin/ip rule  del from 192.168.9.60/32 table 200 priority 1000
    # PostDown = /run/current-system/sw/bin/ip route del default dev %i table 200

    # DO NOT COMMIT CONFIG FILES
    # sudo wg-quick down wg0 -> stop connection
    # sudo wg-quick up wg0 -> start connection

    wg-quick.interfaces = {
      wg0 = {
        configFile = "/etc/wireguard/wg0.conf"; # Put your real file path here (outside repo)
        autostart = true;
      };
    };

    nftables = {
      enable = true;
      ruleset = ''
        table ip nat {
          chain postrouting {
            type nat hook postrouting priority 100; policy accept;

            # LAN → WAN (default NAT)
            ip saddr 192.168.9.0/24 oifname "enp3s0" masquerade

            # Phone → VPN (should be wg0 not enp3s0)
            ip saddr 192.168.9.60/32 oifname "wg0" masquerade
          }
        }
      '';
    };
  };

  environment.systemPackages = with pkgs; [
    vim
    git
    nodePackages_latest.nodejs
    home-manager
    htop
    tcpdump
    dig
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
      interface = "enp0s20u1c2";
      bind-interfaces = true;

      # disable dnsmasq’s DNS (AdGuard handles DNS)
      port = 0;

      # DHCP ranges: IPv4 + small IPv6 pool (only phone will match the static below)
      dhcp-range = [
        "192.168.9.100,192.168.9.200,24h"
        "[fd7d:76ee:e68f:a993::100],[fd7d:76ee:e68f:a993::200],64,24h"
      ];

      # Global DHCP options:
      # 3 = default gateway, 6 = IPv4 DNS server
      dhcp-option = [
        "3,192.168.9.1"
        "6,192.168.9.1"
        # push your IPv6 DNS via DHCPv6
        "option6:dns-server,[fd7d:76ee:e68f:a993::1]"
      ];

      # Static leases (MAC → IPv4 [,IPv6]):
      dhcp-host = [
        "7C:F1:7E:6C:60:00,192.168.9.2" # TP‑Link
        "A8:23:FE:FD:19:ED,192.168.9.50" # TV
        "E0:CC:F8:FA:FB:42,192.168.9.60,[fd7d:76ee:e68f:a993:8ed5:faf4:b85c:13ed]" # your phone
      ];
    };
  };

  services.radvd = {
    enable = true;
    config = ''
      interface enp0s20u1c2 {
        AdvSendAdvert on;
        prefix fd7d:76ee:e68f:a993::/64 {
          AdvOnLink on;
          AdvAutonomous off;      # we’re using DHCPv6 for addresses
        };
        RDNSS fd7d:76ee:e68f:a993::1 {
          AdvRDNSSLifetime 600;
        };
      };
    '';
  };

  services.ndppd = {
    enable = true;
    proxies = {
      enp0s20u1c2 = {
        rules = {
          "fd7d:76ee:e68f:a993:8ed5:faf4:b85c:13ed" = {
            method = "static"; # answer NDP immediately
            interface = "wg0";
            # timeout = 500;         # optional cache timeout (ms)
          };
        };
      };
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
          "127.0.0.1" # <- needs to have localhost oterwise nixos overrides nameservers in netwroking and domain resolution does not work at all
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

  services.ntopng = {
    enable = true;
    extraConfig = ''
      --http-port=3001
    '';
  };
}
