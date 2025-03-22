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

  # Fail2ban global setup
  services.fail2ban = {
    enable = true;
    package = fail2ban;
    # Ban IP after 5 failures
    maxretry = 5;
    ignoreIP = [
      "84.39.117.57" # whitelist a specific IP
    ];
    bantime = "24h"; # Ban IPs for one day on the first ban
    bantime-increment = {
      enable = true; # Enable increment of bantime after each violation
      formula = "ban.Time * math.exp(float(ban.Count+1)*1.5)/math.exp(1*1.5)";
      multipliers = "1 2 4 8 16 32 64";
      maxtime = "168h"; # Do not ban for more than 1 week
      overalljails = true; # Calculate the bantime based on all the violations
    };
    jails = {
      apache-nohome-iptables.settings = {
        # Block an IP address if it accesses a non-existent
        # home directory more than 5 times in 10 minutes,
        # since that indicates that it's scanning.
        filter = "apache-nohome";
        action = ''iptables-multiport[name=HTTP, port="http,https"]'';
        logpath = "/var/log/httpd/error_log*";
        backend = "auto";
        findtime = 600;
        bantime  = 600;
        maxretry = 5;
      };
    };
  };
}
