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

  vaultDomain = "vault.keranod.dev";

  acmeRoot = "/var/lib/acme";
  acmeVaultDomainDir = "${acmeRoot}/${vaultDomain}";

  # Wireguard
  # Keys dir
  wireguardKeysDir = "/etc/wireguard/keys";
  # Connection 1

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
    nameservers = [ "127.0.0.1" ];

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
        "wg-vps" = {
          ips = [ "10.100.0.1/24" ]; # home end of the tunnel
          privateKeyFile = "/etc/wireguard/NetworkBox.key";
          mtu = 1340;
          peers = [
            # VPS Connection
            {
              publicKey = "51Nk/d1A63/M59DHV9vOz5qlWfX8Px/QDym54o1z0l0=";
              # tell it to reach VPS on its public IP:51820
              endpoint = "46.62.157.130:51820";
              allowedIPs = [
                "10.100.0.100/32"
                "10.200.0.0/24"
              ]; # VPS tunnel IP
              persistentKeepalive = 25;
            }

          ];
        };
        "wg-vps2" = {
          ips = [ "10.150.0.1/24" ]; # home end of the tunnel
          privateKeyFile = "/etc/wireguard/NetworkBox.key";
          mtu = 1340;
          # Do not remove. Otherwise WG will put to main table sending all traffic using this WG
          table = "102";
          postSetup = "ip rule add from 10.150.0.1 lookup 102";
          postShutdown = "ip rule del from 10.150.0.1 lookup 102";
          peers = [
            # VPS Connection
            {
              publicKey = "51Nk/d1A63/M59DHV9vOz5qlWfX8Px/QDym54o1z0l0=";
              endpoint = "46.62.157.130:51822";
              # AllowedIPs still needs to be 0.0.0.0/0. This is a cryptographic
              # firewall and tells WireGuard what IPs it's allowed to accept/send
              # traffic for. It is not a routing instruction in this context
              # because we are overriding routing with the `table` option.
              allowedIPs = [ "0.0.0.0/0" ];
              persistentKeepalive = 25;
            }
          ];
        };
        "wg-devices" = {
          ips = [ "10.200.0.1/24" ];
          listenPort = 51821;
          privateKeyFile = "/etc/wireguard/NetworkBox.key";
          mtu = 1340;
          peers = [
            # myAndroid
            {
              publicKey = "hrsWUOfTMhdwyyR+iVogT4OcPTVUMYoUwLFe9VFrVg4=";
              allowedIPs = [ "10.200.0.2/32" ];
            }
            # TufNix
            {
              publicKey = "PtnqtGZnHgoknbZuXuQyRH/kc85am3f66eHRAwG4lAc=";
              allowedIPs = [ "10.200.0.3/32" ];
            }
          ];
        };
      };
    };

    # !!! REMEMBER TO SORT OUT IPV6 ALSO WHEN SENDING TRAFFIC VIA VPS OUT
    nftables = {
      enable = true;
      ruleset = ''
        table inet myfilter {
          # The 'input' chain filters traffic coming IN to the NetworkBox host.
          chain input {
            type filter hook input priority 0; policy drop;
            
            # Allow all loopback traffic
            iifname "lo" accept;

            # Allow inbound connections for existing connections
            ct state { established, related } accept;

            # Allow the outer WG tunnel to connect
            # Rate-limit new connections to the WireGuard tunnel on the public interface
            iifname "wg-vps" udp dport 51821 ct state new limit rate 5/second accept;

            # Allow incoming SSH connections from specified interfaces.
            iifname { "enp3s0", "enp0s20u1c2", "wg-vps" } tcp dport 22 accept;

            # Allow DNS on LAN both ways
            iifname { "enp3s0", "enp0s20u1c2" } tcp dport 53 accept;
            
            # Allow incoming traffic from the LAN
            iifname "enp0s20u1c2" accept;

            # Allow traffic from VPN devices. This traffic has already been
            # decrypted by the 'wg-vps' tunnel and now arrives on the 'wg-devices'
            # virtual interface. This single rule is all need for this tunnel.
            iifname "wg-devices" accept;
          }

          # The 'output' chain filters traffic ORIGINATING from the NetworkBox host.
          chain output {
            type filter hook output priority 0; policy drop;

            # Allow loopback traffic (AdGuard Home -> Unbound on 127.0.0.1)
            oifname "lo" accept;

            # Allow traffic for established connections to continue
            ct state { established, related } accept;

            # CRITICAL: EXPLICITLY DROP all DNS traffic that tries to leave
            # on the physical WAN interface or the wg-vps tunnel.
            oifname { "enp3s0", "wg-vps" } tcp dport { 53, 853 } drop;
            oifname { "enp3s0", "wg-vps" } udp dport { 53, 853 } drop;

            # Allow DNS-over-TLS ONLY via the wg-vps2 interface.
            oifname "wg-vps2" tcp dport 853 accept;
            oifname "wg-vps2" udp dport 853 accept;

            # Allow encrypted WireGuard packets to reach the VPS servers.
            udp dport { 51820, 51822 } oifname "enp3s0" accept;

            # Allow SSH from NetworkBox over wg0 to VPS
            oifname "wg-vps" tcp dport 22 accept;

            # Allow all other traffic (non-DNS) to go out of the physical WAN interface.
            oifname "enp3s0" accept;
          }
        }

        # NAT table remains unchanged and separate.
        table ip nat {
          chain postrouting {
            type nat hook postrouting priority 100; policy accept;

            # LAN → WAN (default NAT)
            ip saddr 192.168.9.0/24 oifname "enp3s0" masquerade
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

  # To test if working use `dig @127.0.0.1 -p 5335 google.com`
  services.unbound = {
    enable = true;
    settings = {
      server = {
        interface = [ "127.0.0.1" ];
        port = 5335;
        access-control = [ "127.0.0.1 allow" ];
        harden-glue = true;
        harden-dnssec-stripped = true;
        use-caps-for-id = false;
        prefetch = true;
        edns-buffer-size = 1232;
        hide-identity = true;
        hide-version = true;
        # force outbound queries to use this IP.
        outgoing-interface = "10.150.0.1";
      };
      forward-zone = {
        name = ".";
        # This is the key setting to enable DNS-over-TLS.
        forward-tls-upstream = true;
        forward-addr = [
          "94.140.14.14@853#dns.adguard-dns.com"
          #"1.1.1.1@853#cloudflare-dns.com"
          #"9.9.9.9@853#dns.quad9.net"
        ];
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
          "10.200.0.1"
          "fd00:9::1"
        ];
        port = 53;
        upstream_dns = [
          "127.0.0.1:5335"
        ];
        # Bootstrap DNS: used only to resolve the upstream hostnames
        bootstrap_dns = [ ];
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

        rewrites = [
          # equivalent of vault.keranod.dev → 10.100.0.1
          {
            domain = "${vaultDomain}";
            answer = "10.200.0.1";
          }
        ];
      };
    };
  };

  services.vaultwarden = {
    enable = true;
    config = {
      rocketAddress = "127.0.0.1";
      rocketPort = 8222; # or whatever port you want
      domain = "https://${vaultDomain}"; # for local/VPN access only
      signupsAllowed = false;
    };
    # !!! Create secrets file with some random string using
    # head /dev/urandom | tr -dc A-Za-z0-9 | head -c 32 | sudo tee /etc/secrets/vaultwarden
    environmentFile = "/etc/secrets/vaultwarden";
  };

  # ACME via DNS-01, using the Hetzner DNS LEGO plugin
  security.acme = {
    acceptTerms = true;
    defaults = {
      email = "konrad.konkel@wp.pl";
      dnsProvider = "hetzner";
      dnsResolver = "127.0.0.1:5335";
      credentialFiles = {
        # Need to suffix variable name with _FILE
        # Get API from your DNS provider and put in proper format https://go-acme.github.io/lego/dns/
        "HETZNER_API_KEY_FILE" = "/etc/secrets/hetznerDNSApi";
      };
      postRun = "systemctl restart nginx";
    };
    certs = {
      # the Vaultwarden subdomain
      "${vaultDomain}" = {
        group = "nginx";
      };
    };
  };

  services.nginx = {
    enable = true;
    recommendedProxySettings = true;
    recommendedGzipSettings = true;
    recommendedOptimisation = true;

    virtualHosts."${vaultDomain}" = {
      enableACME = false; # uses the DNS-01 cert above
      forceSSL = true;

      sslCertificate = "${acmeVaultDomainDir}/full.pem";
      sslCertificateKey = "${acmeVaultDomainDir}/key.pem";

      # bind your real UI only to the VPN interface:
      listen = [
        {
          addr = "10.200.0.1";
          port = 443;
          ssl = true;
        }
      ];

      locations."/" = {
        proxyPass = "http://127.0.0.1:8222";
        extraConfig = ''
          proxy_set_header Host            $host;
          proxy_set_header X-Real-IP       $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
        '';
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
