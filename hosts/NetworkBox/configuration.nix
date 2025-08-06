{
  pkgs,
  ...
}:

let
  tvMAC = "A8:23:FE:FD:19:ED";
  tvFwmark = "200";
  tvTable = tvFwmark;
  tvPriority = "1000";
  tvInterface = "wg0";
in
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
    interfaces.enp0s20u1c2.ipv6.addresses = [
      {
        address = "fd00:9::1";
        prefixLength = 64;
      }
    ];

    wireguard = {
      enable = true;
      interfaces = {
        "wg-lab" = {
          ips = [ "10.100.0.1/24" ];   # home end of the tunnel
          privateKeyFile = "/etc/wireguard/NetworkBox.key";
          
          peers = [
            # VPS Connection
            {
              publicKey  = "51Nk/d1A63/M59DHV9vOz5qlWfX8Px/QDym54o1z0l0=";
              # tell it to reach VPS on its public IP:51820
              endpoint   = "46.62.157.130:51820";
              allowedIPs = [ "10.100.0.100/32" ];  # VPS tunnel IP
              persistentKeepalive = 25;
            }

            # myAndroid
            {
              publicKey  = "hrsWUOfTMhdwyyR+iVogT4OcPTVUMYoUwLFe9VFrVg4=";
              allowedIPs = [ "10.100.0.2/32" ];
            }
          ];
        };
      };
    };

    nftables = {
      enable = true;
      ruleset = ''
        table inet mangle {
          chain prerouting {
            type filter hook prerouting priority raw; policy accept;
            # ether saddr ${tvMAC} counter mark set ${tvFwmark}
          }
        }

        table ip nat {
          chain postrouting {
            type nat hook postrouting priority 100; policy accept;

            # LAN → WAN (default NAT)
            ip saddr 192.168.9.0/24 oifname "enp3s0" masquerade

            # meta mark ${tvFwmark} oifname "${tvInterface}" masquerade
          }
        }

        table ip6 nat {
          chain postrouting {
            type nat hook postrouting priority 100; policy accept;

            # meta mark ${tvFwmark} oifname "${tvInterface}" masquerade
          }
        }
      '';
    };
  };

  environment.systemPackages = with pkgs; [
    nodePackages_latest.nodejs
    home-manager
    wireguard-tools
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
      port = 0;

      dhcp-range = [ "192.168.9.100,192.168.9.200,24h" ];
      dhcp-option = [
        "3,192.168.9.1"
        "6,192.168.9.1"
      ];
      dhcp-host = [
        "7C:F1:7E:6C:60:00,192.168.9.2"
      ];
    };
  };

  services.radvd = {
    enable = true;
    config = ''
      interface enp0s20u1c2 {
        AdvSendAdvert on;
        prefix fd00:9::/64 {
          AdvOnLink      on;
          AdvAutonomous  on;   # clients auto-SLAAC a ULA
        };

        # tell clients to use your ULA DNS
        RDNSS fd00:9::1 {
          AdvRDNSSLifetime 600;
        };

        # Add this to tell clients to route all IPv6 traffic via you
        route ::/0 {
        AdvRoutePreference medium;
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
          "127.0.0.1" # <- needs to have localhost oterwise nixos overrides nameservers in netwroking and domain resolution does not work at all
          "192.168.9.1"
          "10.100.0.1"
          "fd00:9::1"
        ];
        port = 53;
        upstream_dns = [
          "https://dns.adguard-dns.com/dns-query"
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
