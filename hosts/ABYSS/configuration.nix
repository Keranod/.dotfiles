{ pkgs, ... }:

let
  domain = "keranod.dev";
  vaultDomain = "vault.keranod.dev";
  acmeRoot = "/var/lib/acme";
  acmeDomainDir = "${acmeRoot}/${domain}";
  acmeVaultDomainDir = "${acmeRoot}/${vaultDomain}";
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
      # "net.ipv6.conf.all.forwarding" = true;
      # "net.ipv4.conf.all.route_localnet" = 1;
      # "net.ipv4.conf.default.route_localnet" = 1;
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
    networkmanager.enable = false;

    wireguard = {
      enable = true;
      interfaces = {
        wg0 = {
          ips = [ "10.100.0.100/32" ];
          listenPort = 51820;
          privateKeyFile = "/etc/wireguard/server.key";

          peers = [
            # NetworkBox
            {
              publicKey = "rGShQxK1qfo6GCmgVBoan3KKxq0Z+ZkF1/WxLKvM030=";
              allowedIPs = [ "10.100.0.1/32" ];
            }
          ];
        };
      };
    };

    firewall.enable = false;

    nftables = {
      enable = true;
      ruleset = ''
        # NAT table for DNAT/SNAT
        table ip nat {
          chain prerouting {
            type nat hook prerouting priority 0;
            # Device traffic → home-devices
            iifname "enp1s0" udp dport 51821 dnat to 10.200.0.1:51822
          }
          chain postrouting {
            type nat hook postrouting priority 100;
            oifname "enp1s0" masquerade
          }
        }

        # Filter table to lock down inputs
        table ip filter {
          chain input {
            type filter hook input priority 0; policy drop;

            # allow loopback & established
            iif "lo" accept
            ct state established,related accept

            # allow the home↔VPS tunnel itself
            iifname "enp1s0" udp dport 51820 accept

            # allow traffic arriving over wg0 (so ping, replies, etc. aren't dropped)
            iifname "wg0" accept

            # allow incoming device→home forwarding
            iifname "enp1s0" udp dport 51821 accept
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
    nodePackages_latest.nodejs
    home-manager
    wireguard-tools
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
    enable = false;
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
          "tls://dns.adguard-dns.com"
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

        rewrites = [
          # equivalent of vault.keranod.dev → 10.100.0.1
          {
            domain = "vault.keranod.dev";
            answer = "10.100.0.1";
          }
        ];
      };
    };
  };

  services.vaultwarden = {
    enable = false;
    config = {
      rocketAddress = "127.0.0.1";
      rocketPort = 8222; # or whatever port you want
      domain = "https://${vaultDomain}"; # for local/VPN access only
      signupsAllowed = false;
    };
    environmentFile = "/etc/secrets/vaultwarden";
  };

  # ACME via DNS-01, using the Hetzner DNS LEGO plugin
  # security.acme = {
  #   acceptTerms = true;
  #   defaults = {
  #     email = "konrad.konkel@wp.pl";
  #     dnsProvider = "hetzner";
  #     dnsResolver = "1.1.1.1:53";
  #     credentialFiles = {
  #       # Need to suffix variable name with _FILE
  #       "HETZNER_API_KEY_FILE" = "/etc/secrets/hetznerDNSApi";
  #     };
  #     postRun = "systemctl restart nginx";
  #   };

  #   certs = {
  #     # your root domain, in case you need it:
  #     "${domain}" = { };

  #     # the Vaultwarden subdomain
  #     "${vaultDomain}" = { };
  #   };
  # };

  services.nginx = {
    enable = false;
    recommendedProxySettings = true;
    recommendedGzipSettings = true;
    recommendedOptimisation = true;

    virtualHosts."${vaultDomain}" = {
      enableACME = true; # uses the DNS-01 cert above
      addSSL = true; # auto-creates your HTTPS vhost

      # bind your real UI only to the VPN interface:
      listen = [
        {
          addr = "10.100.0.1";
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

  systemd.services.hysteria-server = {
    enable = false;
    description = "Hysteria 2 Server";
    after = [
      "network.target"
      "acme-finished-${domain}.service"
    ];
    wantedBy = [ "multi-user.target" ];

    preStart = ''
            PASSWORD="$(cat /etc/secrets/hysteriav2)"
            cat > /run/hysteria/config.yaml <<EOF
      #disableUDP: true
      tls:
        cert: ${acmeDomainDir}/fullchain.pem
        key:  ${acmeDomainDir}/key.pem
      auth:
        type:     password
        password: "$PASSWORD"
      obfs:
        type: salamander
        salamander:
          password: "$PASSWORD"
      masquerade:
        type: proxy
        forceHTTPS: true
        proxy:
            url: "https://www.wechat.com"
            rewriteHost: true
      EOF
    '';

    serviceConfig = {
      Type = "simple";
      User = "root";
      AmbientCapabilities = "CAP_NET_BIND_SERVICE";
      StandardOutput = "journal";
      StandardError = "journal";
      RuntimeDirectory = "hysteria";

      ExecStart = "${pkgs.hysteria}/bin/hysteria server --config /run/hysteria/config.yaml";
      Restart = "always";
    };
  };
}
