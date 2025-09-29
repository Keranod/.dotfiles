{
  pkgs,
  config,
  ...
}:

let
  serverHostName = "NetworkBox";

  # My user home dir
  keranodHomeDir = "/home/keranod";

  # TV
  tvMAC = "A8:23:FE:FD:19:ED";
  tvFwmark = "200";
  tvTable = tvFwmark;
  tvPriority = "1000";
  tvInterface = "wg0";

  # SSH Key
  sshKey = "${keranodHomeDir}/.dotfiles/.ssh/id_ed25519";

  # Wireguard
  wireguardDir = "/etc/wireguard";

  # secrets
  secretsDir = "/etc/secrets";

  # default services path
  defaultServicesPath = "/var/lib";

  # Acme
  acmeRoot = "${defaultServicesPath}/acme";

  defaultDomain = "keranod.dev";

  wildcardDomain = "*.${defaultDomain}";

  # Hetzner API file
  hetznerSecretsPath = "${secretsDir}/hetznerAPI";

  # Adguard
  adguardPort = 3080;
  adguardDomain = "adguard.${defaultDomain}";

  # Vaultwarden
  vaultDir = "${defaultServicesPath}/vaultwarden";
  vaultDomain = "vault.${defaultDomain}";
  vaultwardenPort = 3090;

  # Gitea
  giteaDir = "${defaultServicesPath}/gitea";
  giteaDomain = "git.${defaultDomain}";
  giteaPort = 4000;

  # WebDAV
  webdavDomain = "webdav.${defaultDomain}";
  webdavPort = 4010;
  webdavSecretsPath = "${secretsDir}/webdav.env";
  webdavDirPath = "${defaultServicesPath}/webdav-files";

  # Radicale
  radicaleDomain = "radicale.${defaultDomain}";
  radicalePort = 4020;
  radicaleSecretsPath = "${secretsDir}/radicale.env";
  radicaleDirPath = "${defaultServicesPath}/radicale/collections";

  # Restic
  resticSecretsPath = "${secretsDir}/restic.env";

  # USB mount dir
  usbMountDir = "/mnt/usb";

  # Backup
  backupPaths = [
    "${wireguardDir}"
    "${secretsDir}"
    "${acmeRoot}"
    "${vaultDir}"
    "${webdavDirPath}"
    "${keranodHomeDir}"
    "${radicaleDirPath}"
  ];
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

  # creating dir like this is permament?
  # create secrets folder this way
  systemd.tmpfiles.settings = {
    "10-usb-mount" = {
      "${usbMountDir}" = {
        d = {
          user = "root";
          group = "root";
          mode = "0755";
        };
      };
    };
    # Create the data directory for WebDAV
    "10-webdav" = {
      # The `path` of the file
      "${webdavDirPath}" = {
        # file type in this case directory
        d = {
          # The remaining options apply to this path.
          user = "webdav";
          group = "webdav";
          mode = "0750";
        };
      };
    };
    "10-secrets" = {
      # The `path` of the file
      "${secretsDir}" = {
        # file type in this case directory
        d = {
          # The remaining options apply to this path.
          user = "root";
          group = "root";
          mode = "0755";
        };
      };
    };
  };

  users.groups.web-services = {
    members = [
      "nginx"
      "vaultwarden"
    ];
  };

  # Use UUID to mount for more reliable approach
  # lsblk -o NAME,UUID
  # manual mount `sudo mount /dev/sdb1 /mnt/usb`
  # manual mount `sudo mount UUID=3c44cefb-02b2-4299-8e8c-4f029e30889d /mnt/usb`
  # manual unmount `sudo umount /mnt/usb`
  fileSystems."${usbMountDir}" = {
    device = "/dev/disk/by-uuid/3c44cefb-02b2-4299-8e8c-4f029e30889d";
    fsType = "ext4";
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

  environment.systemPackages = with pkgs; [
    nodePackages_latest.nodejs
    home-manager
    wireguard-tools
    restic
    nginx
  ];

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

  sops.defaultSopsFile = ./secrets.yaml;
  sops.age.sshKeyPaths = [
    sshKey
  ];
  # sops.secrets.<name of the secret in the file>
  sops.secrets.webdav_env_file = {
    # This path will be referenced by the webdav service
    path = webdavSecretsPath;
    owner = "webdav";
    group = "webdav";
    mode = "0640";
  };
  sops.secrets.radicale_env_file = {
    # This path will be referenced by the webdav service
    path = radicaleSecretsPath;
    owner = "radicale";
    group = "radicale";
    mode = "0640";
  };
  sops.secrets.restic_password = {
    # This path will be referenced by the webdav service
    path = resticSecretsPath;
    owner = "keranod";
    group = "root";
    mode = "0600";
  };
  sops.secrets.hetzner_dns_api_key = {
    path = hetznerSecretsPath;
    owner = "acme";
    group = "acme";
    mode = "0440";
  };

  # Enable the OpenSSH service
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false; # Disable password login
      PermitRootLogin = "no"; # Root login disabled
      PubkeyAuthentication = true; # Ensure pubkey authentication is enabled
    };
  };

  # ACME via DNS-01, using the Hetzner DNS LEGO plugin
  # Sometimes fails for new domain no clue why just run `sudo systemctl start acme-<domain>.service` and if still do not work troubleshoot
  security.acme = {
    acceptTerms = true;
    defaults = {
      email = "konrad.konkel@wp.pl";
      dnsProvider = "hetzner";
      dnsResolver = "127.0.0.1:5335";
      credentialFiles = {
        # Need to suffix variable name with _FILE
        # Get API from your DNS provider and put in proper format https://go-acme.github.io/lego/dns/
        "HETZNER_API_KEY_FILE" = hetznerSecretsPath;
      };
      postRun = "systemctl restart nginx";
    };
    certs = {
      "${defaultDomain}" = {
        group = "web-services";
        extraDomainNames = [ wildcardDomain ];
      };
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
    openFirewall = false;
    port = adguardPort;
    host = "127.0.0.1";
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
          {
            domain = "${radicaleDomain}";
            answer = "10.0.0.2";
          }
          {
            domain = "${adguardDomain}";
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
    # environmentFile = "/etc/secrets/vaultwarden";
  };

  services.gitea = {
    enable = true;
    database = {
      type = "sqlite3";
      path = "${giteaDir}/gitea.db";
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

  services.webdav = {
    enable = true;
    # Point the service to the environment file created by sops
    environmentFile = config.sops.secrets.webdav_env_file.path;
    settings = {
      port = webdavPort;
      address = "127.0.0.1";
      directory = webdavDirPath;
      prefix = "/";
      behindProxy = true;

      users = [
        {
          username = "{env}WEBDAV_USER";
          password = "{env}WEBDAV_PASS";
          permissions = "CRUD";
        }
      ];
    };
  };

  services.radicale = {
    enable = true;
    settings = {
      server = {
        hosts = [ "127.0.0.1:${toString radicalePort}" ];
      };
      auth = {
        type = "htpasswd";
        htpasswd_filename = radicaleSecretsPath;
        htpasswd_encryption = "bcrypt";
      };
      storage = {
        filesystem_folder = radicaleDirPath;
      };
    };
  };

  services.nginx = {
    enable = true;

    logError = "stderr info";

    recommendedProxySettings = true;
    recommendedGzipSettings = true;
    recommendedOptimisation = true;

    appendHttpConfig = ''
      large_client_header_buffers 8 32k;
      proxy_headers_hash_max_size 1024;
      proxy_headers_hash_bucket_size 128;

      # Proxy Read Buffer (for Upstream Responses like WebDAV GET/AdGuard)
      # Sets the number (8) and size (128k) of buffers used for reading a response from the upstream server.
      proxy_buffers 8 128k; 
      # Sets the size of the buffer for the first part of the response.
      proxy_buffer_size 128k;

      # Client Body Buffer (for Request Body like WebDAV PUT)
      # Sets the buffer size for reading the client request body.
      client_body_buffer_size 128k;
    '';

    virtualHosts."${vaultDomain}" = {
      enableACME = false;
      forceSSL = true;
      useACMEHost = defaultDomain;

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
      useACMEHost = defaultDomain;

      listen = [
        {
          addr = "10.0.0.2";
          port = 443;
          ssl = true;
        }
      ];

      locations."/" = {
        proxyPass = "http://127.0.0.1:${toString giteaPort}";
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
      useACMEHost = defaultDomain;

      listen = [
        {
          addr = "10.0.0.2";
          port = 443;
          ssl = true;
        }
      ];

      locations."/" = {
        proxyPass = "http://127.0.0.1:${toString webdavPort}/";
        extraConfig = ''
          proxy_redirect off;

          # Your WebDAV server expects the X-Forwarded-Host header.
          proxy_set_header X-Forwarded-Host $host;
          proxy_set_header X-Forwarded-Proto $scheme;
          proxy_set_header X-Forwarded-Server $host;

          # Let the WebDAV server know what the original request method was
          proxy_set_header X-HTTP-Method-Override $request_method;
        '';
      };
    };

    virtualHosts."${radicaleDomain}" = {
      enableACME = false;
      forceSSL = true;
      useACMEHost = defaultDomain;

      listen = [
        {
          addr = "10.0.0.2";
          port = 443;
          ssl = true;
        }
      ];

      locations."/radicale/" = {
        proxyPass = "http://127.0.0.1:${toString radicalePort}/";
        extraConfig = ''
          proxy_set_header  X-Script-Name /radicale;
          proxy_set_header  X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header  X-Forwarded-Host $host;
          proxy_set_header  X-Forwarded-Port $server_port;
          proxy_set_header  X-Forwarded-Proto $scheme;
          proxy_set_header  Host $host;
          proxy_pass_header Authorization;
        '';
      };
    };

    virtualHosts."${adguardDomain}" = {
      enableACME = false;
      forceSSL = true;
      useACMEHost = defaultDomain;

      listen = [
        {
          addr = "10.0.0.2";
          port = 443;
          ssl = true;
        }
      ];

      locations."/" = {
        proxyPass = "http://127.0.0.1:${toString adguardPort}/";
        extraConfig = ''
          # Standard proxy headers for a modern web application
          # proxy_set_header Host $host;
          # proxy_set_header X-Real-IP $remote_addr;
          # proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          # proxy_set_header X-Forwarded-Proto $scheme;
        '';
      };
    };
  };

  # restic-backups-usb.service
  # To check backups run as `root` `restic snapshots -r /mnt/usb/restic-repo/`
  services.restic.backups."usb" = {
    paths = backupPaths;
    repository = "${usbMountDir}/restic-repo";
    passwordFile = "${resticSecretsPath}";
    timerConfig = {
      # Daily at 2am
      OnCalendar = "*-*-* 02:00:00";
      Persistent = true;
    };
    initialize = true;
    pruneOpts = [ "--keep-daily 7" ];
  };

  services.ntopng = {
    enable = false;
    extraConfig = ''
      --http-port=3001
    '';
  };
}
