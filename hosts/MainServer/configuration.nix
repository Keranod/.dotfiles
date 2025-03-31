{ pkgs, lib, ... }:

let
  postgresVersion = "17";  # Define PostgreSQL version once
  postgresPackage = pkgs."postgresql_${postgresVersion}";
in
{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

# Disable EFI bootloader and use GRUB for Legacy BIOS
boot.loader.grub.enable = true;
boot.loader.grub.device = "/dev/sda";  # or the appropriate disk, replace /dev/sda with your disk name

# Set boot partition label for GRUB to use
boot.loader.grub.useOSProber = true;

# File system settings for boot
# fileSystems."/boot" = {
#   fsType = "ext4";  # Assuming you want to use ext4 for the boot partition in legacy BIOS
# };


  # Networking
  networking.hostName = "MainServer";
  networking.networkmanager.enable = true;

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  time.timeZone = "Europe/London";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_GB.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_GB.UTF-8";
    LC_IDENTIFICATION = "en_GB.UTF-8";
    LC_MEASUREMENT = "en_GB.UTF-8";
    LC_MONETARY = "en_GB.UTF-8";
    LC_NAME = "en_GB.UTF-8";
    LC_NUMERIC = "en_GB.UTF-8";
    LC_PAPER = "en_GB.UTF-8";
    LC_TELEPHONE = "en_GB.UTF-8";
    LC_TIME = "en_GB.UTF-8";
  };

  programs.dconf.enable = true;

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "gb";
    variant = "";
  };

  # Configure console keymap
  console.keyMap = "uk";

  # Enable CUPS to print documents.
  # services.printing.enable = true;

  # Enable sound with pipewire.
  # hardware.pulseaudio.enable = false;
  # security.rtkit.enable = true;
  # services.pipewire = {
  #   enable = true;
  #   alsa.enable = true;
  #   alsa.support32Bit = true;
  #   pulse.enable = true;
  # };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # List packages installed in system profile.
  # To search, go https://search.nixos.org/packages?channel=24.11&
  environment.systemPackages = with pkgs; [
    vim
    git
    nodejs_22
    home-manager
    goaccess
    unzip
    htop
  ];

  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 80 443 ];
    # allowedUDPPorts = [ ];  # No allowed UDP ports
    # rejectPackets = true;
    # Allow local connections to 5432 but block external
     extraCommands = ''
      iptables -A INPUT -p tcp --dport 5432 -s 127.0.0.1 -j ACCEPT
      iptables -A INPUT -p tcp --dport 5432 -j DROP
    '';
  };

  # https://mynixos.com/
  system.stateVersion = "24.11";

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Enable the OpenSSH service
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;  # Disable password login
      PermitRootLogin = "no";         # Root login disabled
      PubkeyAuthentication = true;    # Ensure pubkey authentication is enabled
    };
  };

  # Postgres Global setup
  services.postgresql = {
    enable = true;
    package = postgresPackage;  # Install & enable same version
    enableTCPIP = true;
    # Authentication only to host, cannot make local work with scram
    # psql -U <username> -h 127.0.0.1
    authentication = ''
      #type database  DBuser  address        auth-method
      #local all       all                    scram-sha-256
      host  all       all     127.0.0.1/32   scram-sha-256
    '';
     settings = {
      listen_addresses = lib.mkForce "127.0.0.1";
     };
  };

  # ACME (Let's Encrypt)
  security.acme = {
    acceptTerms = true;
    defaults.email = "konrad.konkel@wp.pl";
  };

  # Nginx setup
  services.nginx = {
    enable = true;

    recommendedProxySettings = true;
    recommendedGzipSettings = true;
    recommendedOptimisation = true;

    # Drop direct request to IP of server
    virtualHosts."_" = {
      default = true;
      extraConfig = ''
        return 444;
      '';
    };

    # Redirect www. to non www. for better SEO
    virtualHosts."www.thecuriousendeavor.com" = {
      forceSSL = true;
      enableACME = true;

      extraConfig = ''
        return 301 https://thecuriousendeavor.com$request_uri;
      '';
    };

    virtualHosts."thecuriousendeavor.com" = {
      forceSSL = true;
      enableACME = true;

      root = "/var/www/WatchesWithMark/WatchesWithMark-frontend/dist";

      locations."/" = {
        index = "index.html";
        tryFiles = "$uri $uri/ /index.html";

        extraConfig = ''
          add_header X-Frame-Options "SAMEORIGIN" always;
          add_header X-Content-Type-Options "nosniff" always;
        '';
      };

      # Serve static assets from the correct directory
      locations."/assets/" = {
          extraConfig = ''
          expires 1y;
          add_header Cache-Control "public, max-age=31556952, immutable";
        '';
      };

      # Cache static assets efficiently
      locations."~* \\.(?:css|js|woff2|ttf|eot|otf)$" = {
        extraConfig = ''
          expires 1y;
          add_header Cache-Control "public, max-age=31556952, immutable";
        '';
      };

      locations."~* \\.(?:jpg|jpeg|png|gif|ico|webp|svg)$" = {
        extraConfig = ''
          expires 30d;
          add_header Cache-Control "public, max-age=2592000, immutable";
        '';
      };

      locations."^~ /uploads/" = {
  extraConfig = ''
    proxy_pass http://localhost:1337;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
  '';
};


      # Rate limit API requests
      locations."~* ^/(api|uploads)/" = {
        extraConfig = ''
          proxy_pass http://localhost:1337; # Backend (Strapi admin panel)
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
        '';
      };

      # Restrict access to Strapi admin panel
      locations."~ /(admin|i18n|content-manager|content-type-builder|upload/|users-permissions)" = {
        extraConfig = ''
          allow 84.39.117.57;
          allow 84.39.117.56;
          allow 217.146.82.84;
          allow 62.232.65.182;
          deny all;

          error_page 403 =302 /404.html;

          proxy_pass http://localhost:1337;
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
        '';
      };

      # Logs location
      locations."/nginx-logs/" = {
        extraConfig = ''
          allow 84.39.117.57;
          allow 84.39.117.56;
          allow 217.146.82.84;
          allow 62.232.65.182;
          deny all;

          error_page 403 =302 /404.html;

          # Dir where logs are stored
          alias /var/log/nginx/;

          # Autoindex fires up only index.html not found, rename index.html if you want to list files in dir
          # Enable autoindex to list .html files
          autoindex on;
          autoindex_format html;
          autoindex_exact_size off;  # Optional: Hide exact file sizes
          autoindex_localtime on;    # Optional: Show local time
        '';
      };

      # Security headers
      extraConfig = ''
        gzip on;
        gzip_static on;
        gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript image/svg+xml;
        gzip_proxied any;
        gzip_min_length 256;
      '';
    };
  };

  # Strapi
  systemd.services.strapi = {
    description = "Strapi Headless CMS";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      WorkingDirectory = "/var/www/WatchesWithMark/backend";
      ExecStart = "/run/current-system/sw/bin/bash -c 'PATH=/run/current-system/sw/bin:$PATH /run/current-system/sw/bin/npm start'";
      Restart = "always";
      User = "keranod";
      Group = "users";
      Environment = "NODE_ENV=production";
      StandardOutput = "journal";
      StandardError = "journal";
    };
  };

  # Filters for Fail2Ban
  environment.etc = {
    "fail2ban/filter.d/nginx-badbots.conf".text = ''
      [Definition]
      failregex = ^<HOST>.*"(GET|POST).* (?:config\.json|wp-login\.php|xmlrpc\.php|phpmyadmin|/boaform).*" 403
      ignoreregex =
    '';

    "fail2ban/filter.d/nginx-404.conf".text = ''
      [Definition]
      failregex = ^<HOST>.*"(GET|POST) .*" 404
      ignoreregex =
    '';

    "fail2ban/filter.d/nginx-login.conf".text = ''
      [Definition]
      failregex = ^<HOST>.*"(GET|POST).* /login.*" 401
      ignoreregex =
    '';
  };

  # Fail2Ban Global Setup
  services.fail2ban = {
    enable = true;
    extraPackages = [pkgs.ipset]; # Needed for banning on IPv4 & IPv6
    banaction = "iptables-ipset-proto6-allports";
    maxretry = 5;
    ignoreIP = ["84.39.117.57 84.39.117.56 217.146.82.84 62.232.65.182"]; # Whitelist trusted IPs
    bantime = "24h";

    bantime-increment = {
      enable = true;
      multipliers = "1 2 4 8 16 32 64"; # Exponential increase
      maxtime = "168h"; # Max ban time (7 days)
      overalljails = true;
    };

    jails = {
      # SSH Protection
      sshd.settings = {
        enabled = true;
        filter = "sshd";
        backend = "systemd";
        maxretry = 3;
        findtime = 600;
      };

      # Nginx Bad Bots
      nginx-badbots.settings = {
        enabled = true;
        filter = "nginx-badbots";
        logpath = "/var/log/nginx/access.log";
        backend = "auto";
        maxretry = 5;
        findtime = 600;
      };

      # Nginx 404 Error Protection
      nginx-404.settings = {
        enabled = false;
        filter = "nginx-404";
        logpath = "/var/log/nginx/access.log";
        backend = "auto";
        maxretry = 10;
        findtime = 600;
        ignoreregex = "GET /api/(metadata|home-page|repairs|articles|logo).* HTTP/\S+";
      };

      # Nginx Login Protection
      nginx-login.settings = {
        enabled = true;
        filter = "nginx-login";
        logpath = "/var/log/nginx/access.log";
        backend = "auto";
        maxretry = 5;
        findtime = 600;
      };
    };
  };

  systemd.timers."goaccess-report" = {
    wantedBy = [ "timers.target" ];
    partOf = [ "goaccess-report.service" ];
    timerConfig = {
      OnCalendar = "*:0/15";  # Runs every 15 minutes
      Persistent = true;
    };
  };

  systemd.services.goaccess-report = {
    description = "GoAccess Nginx Log Analyzer";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      WorkingDirectory = "/var/log/nginx";
      ExecStart = "/run/current-system/sw/bin/goaccess /var/log/nginx/access.log -o /var/log/nginx/access.html --log-format=COMBINED";
      Restart = "always";
      User = "root"; # Adjust if needed
      Group = "users";
      StandardOutput = "journal";
      StandardError = "journal";
    };
  };

}
