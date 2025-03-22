{ pkgs, ... }:

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
    nginx
    goaccess
    certbot
    unzip
  ];

  # Enable the OpenSSH service
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;  # Disable password login
      PermitRootLogin = "no";         # Root login disabled
      PubkeyAuthentication = true;    # Ensure pubkey authentication is enabled
    };
  };

  networking.firewall = {
    enable = true;
    # allowedTCPPorts = [ ];  # No allowed ports
    # allowedUDPPorts = [ ];  # No allowed UDP ports
    # rejectPackets = true;
    extraCommands = ''
      iptables -A INPUT -p tcp --dport 5432 -j DROP
    '';
  };

  # https://mynixos.com/
  system.stateVersion = "24.11";

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Postgres Global setup
  services.postgresql = {
    enable = true;
    package = postgresPackage;  # Install & enable same version 
    enableTCPIP = true;
    # Authentication only to host, cannot make local work with scram
    # psql -U <username> -h 127.0.0.1
    authentication = ''
      #type database  DBuser  address        auth-method
      #local all       all                    peer
      host  all       all     127.0.0.1/32   scram-sha-256
    '';
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
    ignoreIP = ["84.39.117.57"]; # Whitelist trusted IPs
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
        logpath = "/var/log/auth.log";
        backend = "auto";
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
        enabled = true;
        filter = "nginx-404";
        logpath = "/var/log/nginx/access.log";
        backend = "auto";
        maxretry = 10;
        findtime = 600;
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

}
