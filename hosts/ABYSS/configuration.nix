{ pkgs, lib, ... }:

let
  domain        = "keranod.dev";
  acmeRoot = "/var/lib/acme";
  acmeDir     = "${acmeRoot}/${domain}";
  hysteriaConfig = pkgs.writeText "hysteria2-config.yaml" ''
    listen: :443
    protocol: tcp
    tls:
      cert: ${acmeDir}/fullchain.pem
      key: ${acmeDir}/key.pem
    auth:
      type: password
      password: "5kYxPZ+hr4DwXL3OZmH0P1LQREdPBp9QutKHv3p1BA="
    masquerade:
      type: proxy
      proxy:
        url: "https://${domain}/"
        rewriteHost: true
  '';
in
{
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
  ];

  # Disable EFI bootloader and use GRUB for Legacy BIOS
  boot = {
    # IP forwarding & NAT so clients can access internet
    kernel.sysctl = {
      "net.ipv4.ip_forward" = true;
      "net.ipv6.conf.all.forwarding" = true;
      "net.ipv4.conf.all.route_localnet" = 1;
      "net.ipv4.conf.default.route_localnet" = 1;
    };

    loader.grub = {
      enable = true;
      device = "/dev/sda"; # or the appropriate disk, replace /dev/sda with your disk name

      # Set boot partition label for GRUB to use
      useOSProber = true;
    };
  };

  # Networking
  networking = {
    hostName = "ABYSS";
    networkmanager.enable = true;

    wireguard = {
      enable = true;
      interfaces = {
        wg0 = {
          ips = [ "10.100.0.1/24" ];
          listenPort = 51820;
          privateKeyFile = "/etc/wireguard/server.key";

          peers = [
            # myAndoird
            {
              publicKey = "VzIT73Ifb+gnEoT8FNCBihAuOPYREXL6HdMwAjNCJmw=";
              allowedIPs = [ "10.100.0.2/32" ];
            }
            # babyIPhone
            {
              publicKey = "9aLtuWpRtk5qaQeEVSgQcu1Fgtej4gUauor19nVKnBA=";
              allowedIPs = [ "10.100.0.3/32" ];
            }
            # TufNix
            {
              publicKey = "Pegp2QEADJjV/zDPCXxA4OKObSCSBOFm0dRJvEPRjzg=";
              allowedIPs = [ "10.100.0.4/32" ];
            }
          ];
        };
      };
    };

    firewall.enable = false;

    nftables = {
      enable = true;

      ruleset = ''
        table ip nat {
          chain postrouting {
            type nat hook postrouting priority 100; policy accept;
            ip saddr 10.100.0.0/24 oifname "enp1s0" masquerade
          }
        }

        table ip filter {
          chain input {
            type filter hook input priority 0; policy drop;
            ct state established,related accept
            iifname "lo" accept

            # WireGuard handshake
            udp dport 51820 accept
            # Let's Encrypt HTTP-01 challenge
            tcp dport 80 accept    
            # Hysteria traffic         
            tcp dport 443 accept               

            # SSH - No global "accept" for port 22
            iifname "wg0" tcp dport 22 accept

            # AdGuard UI — only on VPN interface!
            iifname "wg0" tcp dport 3000 accept

            # DNS (server itself or VPN clients)
            iifname "wg0" udp dport 53 accept
            iifname "wg0" tcp dport 53 accept
          }

          chain forward {
            type filter hook forward priority 0; policy accept;
          }
        }
      '';
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
    unzip
    htop
    wireguard-tools
    tcpdump
    dig
    hysteria
  ];

  # Enable the OpenSSH service
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false; # Disable password login
      PermitRootLogin = "no"; # Root login disabled
      PubkeyAuthentication = true; # Ensure pubkey authentication is enabled
      KexAlgorithms = [ "curve25519-sha256" ];
      Ciphers = [ "chacha20-poly1305@openssh.com" ];
      Macs = [ "hmac-sha2-512-etm@openssh.com" ];
    };
  };

  services.adguardhome = {
    enable = true;
    openFirewall = true; # opens port 3000 (UI) and 53 (DNS)
    mutableSettings = false;

    settings = {
      dns = {
        bind_hosts = [
          "127.0.0.1"
          "10.100.0.1"
        ]; # VPN + localhost access
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

  security.acme = {
    acceptTerms = true;
    defaults.email = "konrad.konkel@wp.pl";
    certs."${domain}".webroot = "/var/www";
  };

  services.nginx = {
    enable = true;
    listenPorts = [ 80 8443 ]; 
    virtualHosts."${domain}" = {
      root = "/var/www";
    };
  };

  systemd.services.hysteria-server = {
    description = "Hysteria 2 Server";
    after = [ "network.target" "acme-finished-${domain}.service" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      ExecStart = "${pkgs.hysteria}/bin/hysteria server --config ${hysteriaConfig}";
      Restart = "always";

      # Secure sandboxing
      # DynamicUser = true;
      User = "root";
      AmbientCapabilities = "CAP_NET_BIND_SERVICE";
      SupplementaryGroups = [ "acme" ]; # <-- grant read access to certs
      ReadOnlyPaths = [ "${acmeRoot}" ]; # optionally restrict further
    };
  };
}
