{
  pkgs,
  config,
  ...
}:

let
  serverHostName = "NetworkBox";

  tvMAC = "A8:23:FE:FD:19:ED";
  tvFwmark = "200";
  tvTable = tvFwmark;
  tvPriority = "1000";
  tvInterface = "wg0";

  vaultDomain = "vault.keranod.dev";
  giteaDomain = "git.keranod.dev";
  webdavDomain = "webdav.keranod.dev";
  testDomain = "test.keranod.dev";

  acmeRoot = "/var/lib/acme";
  acmeVaultDomainDir = "${acmeRoot}/${vaultDomain}";
  acmeGiteaDomainDir = "${acmeRoot}/${giteaDomain}";
  acmeWebdavDomainDir = "${acmeRoot}/${webdavDomain}";
  acmeTestDomainDir = "${acmeRoot}/${testDomain}";

  vaultwardenPort = 3090;
  giteaPort = 4000;
  webdavPort = 4010;
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
    hostName = serverHostName;
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
        "vpn-network" = {
          ips = [ "10.0.0.2/24" ];
          privateKeyFile = "/etc/wireguard/${serverHostName}.key";
          # Do not remove. Otherwise WG will put to main table sending all traffic using this WG
          table = "102";
          postSetup = "ip rule add from 10.0.0.2 lookup 102";
          postShutdown = "ip rule del from 10.0.0.2 lookup 102";
          peers = [
            {
              name = "ABYSS";
              publicKey = "UIFwVqeUVYxH4QhWqyfh/Qi1HdYD1Y/YrBemuK9dZxo=";
              endpoint = "46.62.157.130:51820";
              # AllowedIPs still needs to be 0.0.0.0/0. This is a cryptographic
              # firewall and tells WireGuard what IPs it's allowed to accept/send
              # traffic for. It is not a routing instruction in this context
              # because we are overriding routing with the `table` option.
              allowedIPs = [
                "0.0.0.0/0"
              ];
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

                # Allow incoming SSH connections from specified interfaces.
                iifname { "enp0s20u1c2", "vpn-network", "enp3s0" } tcp dport 22 accept;

                # Allow all traffic from LAN and VPN interfaces to the NetworkBox
            	# (This covers AdGuard DNS queries from clients, pings to this box, etc.)
            	iifname { "enp0s20u1c2", "vpn-network" } accept;
            }

            # The 'output' chain filters traffic ORIGINATING from the NetworkBox host.
            chain output {
                type filter hook output priority 0; policy drop;

                # Allow loopback traffic
                oifname "lo" accept;

                # Allow traffic for established connections to continue
                ct state { established, related } accept;

                # Allow all traffic destined for VPN and LAN interfaces to pass.
                oifname { "vpn-network", "enp0s20u1c2" } accept;

                # Allow DNS queries for the ACME user (UID 989) (check UID using `id acme`) on the public interface
                oifname "enp3s0" meta skuid 989 udp dport 53 accept;

                # CRITICAL: EXPLICITLY DROP all DNS traffic that tries to leave
                # on the physical WAN interface or the wg-vps tunnel.
                oifname "enp3s0" tcp dport { 53, 853 } drop;
                oifname "enp3s0" udp dport { 53, 853 } drop;

                # Allow all other traffic from the NetworkBox to go directly to the WAN.
                oifname "enp3s0" accept;
            }
        }

            # The NAT table for masquerading traffic from the LAN.
        table ip nat {
            chain postrouting {
                type nat hook postrouting priority 100; policy accept;
                
                # Masquerade all other LAN traffic to exit via the WAN.
                ip saddr 192.168.9.0/24 oifname "enp3s0" masquerade;
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
        outgoing-interface = "10.0.0.2";
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
          "10.0.0.2"
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
          # equivalent of vault.keranod.dev → 10.0.0.2
          {
            domain = "${vaultDomain}";
            answer = "10.0.0.2";
          }
          {
            domain = "${giteaDomain}";
            answer = "10.0.0.2";
          }
          {
            domain = "${webdavDomain}";
            answer = "10.0.0.2";
          }
        ];
      };
    };
  };

  services.vaultwarden = {
    enable = true;
    config = {
      rocketAddress = "127.0.0.1";
      rocketPort = vaultwardenPort; # or whatever port you want
      domain = "https://${vaultDomain}"; # for local/VPN access only
      signupsAllowed = false;
    };
    # !!! Create secrets file with some random string using
    # Comment out to turn off admin panel
    # sudo mkdir /etc/secrets
    # head /dev/urandom | tr -dc A-Za-z0-9 | head -c 32 | sudo tee /etc/secrets/vaultwarden
    environmentFile = "/etc/secrets/vaultwarden";
  };

  services.gitea = {
    enable = true;
    database = {
      type = "sqlite3";
      path = "/var/lib/gitea/gitea.db";
    };
    settings = {
      server = {
        HTTP_PORT = giteaPort;
        HTTP_ADDR = "127.0.0.1";
        ROOT_URL = "https://${giteaDomain}/"; # Make sure to have a trailing slash
      };
      ssh = {
        # The SSH settings are nested under 'settings'
        ENABLE_SSH = true;
        SSH_PORT = 22;
        SSH_LISTEN_ADDR = "10.0.0.2"; # Or "10.0.0.2:22" if needed
      };
    };
  };

  sops.defaultSopsFile = ./secrets.yaml;
  sops.age.sshKeyPaths = [
    "/home/keranod/.dotfiles/.ssh/id_ed25519"
  ];
  sops.secrets.webdav_username = {
    path = "/run/webdav_secrets/webdav.username";
    owner = "webdav";
    group = "webdav";
    mode = "0400";
  };
  sops.secrets.webdav_password = {
    path = "/run/webdav_secrets/webdav.password";
    owner = "webdav";
    group = "webdav";
    mode = "0400";
  };
  # Do not put secrets files in /run/secrets otherwise there will be race condition issue
  #   sops.secrets.nginx_webdav_users = {
  #     path = "/run/webdav_secrets/webdav.users";
  #     owner = "root";
  #     group = "nginx";
  #     mode = "0640";
  #   };

  # Create the data directory for WebDAV
  systemd.tmpfiles.settings = {
    "10-webdav" = {
      # The `path` of the file
      "/var/lib/webdav-files" = {
        # file type in this case directory
        d = {
          # The remaining options apply to this path.
          user = "webdav";
          group = "webdav";
          mode = "0750";
        };
      };
    };
  };

  services.webdav = {
    enable = true;
    settings = {
      port = webdavPort;
      host = "127.0.0.1";
      root = "/var/lib/webdav-files";
      baseURL = "/"; # Important: Tell the service it's at the root of the domain.
      behindProxy = true;

      # Enable built-in basic authentication
      basicAuth.enable = true;

      # Define users from sops secrets
      users = [
        {
          # Use file paths provided by sops
          usernameFile = "/run/webdav_secrets/webdav.username";
          passwordFile = "/run/webdav_secrets/webdav.password";
          # Permissions for this user
          scope = "/var/lib/webdav-files";
          modify = true;
          rules = [
            {
              regex = ".*";
              allow = true;
            }
          ];
        }
      ];
    };
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
      "${giteaDomain}" = {
        group = "nginx";
      };
      "${webdavDomain}" = {
        group = "nginx";
      };
      "${testDomain}" = {
        group = "nginx";
      };
    };
  };

  services.nginx = {
    enable = true;

    # sort out later
    # requires = [
    #   "sops-install-secrets.service"
    #   "acme-switch.service"
    # ];
    # after = [
    #   "sops-install-secrets.service"
    #   "acme-switch.service"
    # ];

    recommendedProxySettings = true;
    recommendedGzipSettings = true;
    recommendedOptimisation = true;

    appendHttpConfig = ''
      large_client_header_buffers 8 32k;
      proxy_headers_hash_max_size 1024;
      proxy_headers_hash_bucket_size 128;
    '';

    virtualHosts."${vaultDomain}" = {
      enableACME = false; # uses the DNS-01 cert above
      forceSSL = true;

      sslCertificate = "${acmeVaultDomainDir}/full.pem";
      sslCertificateKey = "${acmeVaultDomainDir}/key.pem";

      # bind your real UI only to the VPN interface:
      listen = [
        {
          addr = "10.0.0.2";
          port = 443;
          ssl = true;
        }
      ];

      locations."/" = {
        proxyPass = "http://127.0.0.1:${toString vaultwardenPort}";
        extraConfig = ''
          proxy_set_header Host            $host;
          proxy_set_header X-Real-IP       $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
        '';
      };
    };

    virtualHosts."${giteaDomain}" = {
      enableACME = false;
      forceSSL = true;

      sslCertificate = "${acmeGiteaDomainDir}/full.pem";
      sslCertificateKey = "${acmeGiteaDomainDir}/key.pem";

      # bind the UI only to the VPN interface, just like Vaultwarden
      listen = [
        {
          addr = "10.0.0.2";
          port = 443;
          ssl = true;
        }
      ];

      locations."/" = {
        proxyPass = "http://127.0.0.1:${toString giteaPort}"; # Point to Gitea's localhost port
        extraConfig = ''
          # Do not use in Gitea otherwise cannot access it via web
          # proxy_set_header Host            $host;
          proxy_set_header X-Real-IP       $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
          # Required for Git LFS and other features
          proxy_read_timeout 3600;
        '';
      };
    };

    virtualHosts."${webdavDomain}" = {
      enableACME = false;
      forceSSL = true;

      sslCertificate = "${acmeWebdavDomainDir}/full.pem";
      sslCertificateKey = "${acmeWebdavDomainDir}/key.pem";

      listen = [
        {
          addr = "10.0.0.2";
          port = 443;
          ssl = true;
        }
      ];

      locations."/" = {
        proxyPass = "http://127.0.0.1:${toString webdavPort}";
        extraConfig = ''
          # Authentication is now handled by the upstream webdav service.
          # These lines are no longer needed here.
          # auth_basic "Restricted Access";
          # auth_basic_user_file /run/webdav_secrets/webdav.users;

          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header Host $host;
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
