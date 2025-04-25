{ pkgs, lib, ... }:

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

  # Networking
  networking = {
    hostName             = "NetworkBox";
    networkmanager.enable = false;

    # Static IP on enp3s0
    interfaces.enp3s0 = {
      useDHCP       = false;
      ipv4.addresses = [
        { address = "192.168.1.2"; prefixLength = 24; }
      ];
    };

    defaultGateway = "192.168.1.1";
    nameservers    = [ "127.0.0.1" ];

    # Enable forwarding if you ever proxy/NAT through this box
    forwardEnable = true;

    firewall = {
      enable         = true;
      allowedUDPPorts = [ 53 ];   # DNS
    };
  };

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
    nodePackages_latest.nodejs
    home-manager
    htop
  ];

  # https://mynixos.com/
  system.stateVersion = "24.11";

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
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

  # AdGuard Home: DNS + DHCP
  services.adguardhome = {
    enable         = true;
    openFirewall   = true;   # auto-opens 53 & 3000
    restartOnChange = true;
    immutable      = true;   # lock UI edits
    mutableSettings = true;  # re-seed on service start

    settings = {
      # DNS
      dns = {
        bind_hosts   = [ "0.0.0.0" ];
        port         = 53;
        upstream_dns = [
          "94.140.14.14"
          "94.140.15.15"
        ];
      };

      # DHCP
      dhcp = {
        enabled     = true;
        interface   = "enp3s0";
        gateway_ip  = "192.168.1.1";
        subnet_mask = "255.255.255.0";
        range_start = "192.168.1.100";
        range_end   = "192.168.1.200";
        lease_time  = 86400;
        options = [
          # Option 6 = DNS server; we explicitly list AGH AND a fallback
          "6 ip 192.168.1.2,1.1.1.1"
        ];

        static_leases = {
          "AA:BB:CC:DD:EE:FF" = "192.168.1.50";  # TV’s MAC → .50
        };
      };

      # Blocklists / filtering (defaults)
      filtering = {
        protection_enabled = true;
        filtering_enabled  = true;
        parental           = false;
      };
    };
  };
}
