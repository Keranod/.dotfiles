{
  pkgs,
  bindPkgs_,
  sambaPkgs_,
  privateConfigs,
  privateConfigsStore,
  ...
}:

let
  tvIp = "192.168.8.50"; # your TV’s static IP
  vpnInterface = "tun0"; # OpenVPN interface
  tableNum = 100; # custom routing table
  # ovpnPath = "${privateConfigs}/AirVPN_Taiwan_UDP-443-Entry3.ovpn";
  # vpnConfig = builtins.readFile ovpnPath;
in
{
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
  ];

  # Default settings for EFI
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  fileSystems."/boot" = {
    fsType = "vfat";
  };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # Virtualbox guest additions
  systemd.services.virtualbox.unitConfig.ConditionVirtualization = "oracle";
  # Enable VirtualBox guest additions
  virtualisation.virtualbox.guest = {
    enable = true;
    seamless = true;
    clipboard = true;
  };

  # Networking
  networking.hostName = "VMNixOSWork";
  networking.networkmanager.enable = true;
  networking.proxy.default = "192.9.253.10:80";
  networking.proxy.httpsProxy = "192.9.253.10:80";
  networking.proxy.httpProxy = "192.9.253.10:80";

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

  # Enable the X11 windowing system.
  # You can disable this if you're only using the Wayland session.
  services.xserver.enable = true;

  # GNOME
  services.xserver.displayManager.gdm.enable = true;
  services.xserver.desktopManager.gnome.enable = true;
  services.xserver.displayManager.gdm.wayland = false;
  environment.gnome.excludePackages = (
    with pkgs;
    [
      gnome-photos
      gnome-tour
      gnome-weather
      gnome-maps
      totem
      gedit
      cheese
      gnome-music
      gnome-characters
      tali
      iagno
      hitori
      atomix
      yelp
      gnome-initial-setup
    ]
  );
  programs.dconf.enable = true;

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "gb";
    variant = "";
  };

  # Configure console keymap
  console.keyMap = "uk";

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable sound with pipewire.
  hardware.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # For vscode extensions
  programs.nix-ld.enable = true;

  # List packages installed in system profile.
  # To search, go https://search.nixos.org/packages?channel=24.11&
  environment.systemPackages = with pkgs; [
    vim
    git
    nodejs_22
    home-manager
    gnome.gnome-tweaks
    gnome-online-accounts
  ];

  fileSystems."/etc/privateConfigs" = {
    device  = privateConfigsStore;
    fsType  = "none";
    options = [ "bind" "ro" ];
  };

  services.openvpn.servers.airvpn = {
    # point to the .ovpn inside the bind-mount:
    config = ''config /etc/privateConfigs/AirVPN_Taiwan_UDP-443-Entry3.ovpn'';
    autoStart  = true;
  };

  # Enable the OpenSSH daemon.
  # services.openssh.enable = true;

  # Samba
  # `testparm` to test config after rebuilding and switching
  # services.samba = {
  #   enable = true;
  #   package = sambaPkgs_.samba;
  #   openFirewall = true;

  #   settings = {
  #     global = {
  #       "workgroup" = "TESTDOMAIN";
  #       "netbios name" = "VMNixOSWork"; # Use the DC's NetBIOS name as desired.
  #       "server string" = "Samba NT4 DC for TESTDOMAIN";
  #       "security" = "user";
  #       "domain logons" = "yes"; # Crucial for domain controller functionality.
  #       "domain master" = "yes";
  #       "ntlm auth" = "yes";
  #       "passdb backend" = "tdbsam";

  #       # WINS support (ensure Windows clients use this DC for WINS):
  #       "wins support" = "yes";

  #       "add user script" = "sudo /usr/sbin/useradd -d /home/%u -s /bin/bash %u";
  #       "add group script" = "sudo /usr/sbin/groupadd %g";
  #       "delete user script" = "/usr/sbin/userdel %u";
  #       "delete group script" = "/usr/sbin/groupdel %g";

  #       # Logon information:
  #       "logon drive" = "P:";
  #       "logon home" = "\\\\VMNixOSWork\\%U";
  #       "logon path" = "";
  #       "max log size" = "50";

  #       "socket options" = "TCP_NODELAY";
  #       "time server" = "yes";
  #     };
  #   };
  #   shares = {
  #     Publiczny = {
  #       "path" = "/home/franz/publiczny";
  #       "writable" = "yes";
  #       "guest ok" = "yes";
  #       # Need to chmod 777 the path directory
  #     };
  #   };
  # };

  # Bind configuration
  # services.bind = {
  #   enable = true;
  #   package = bindPkgs_.bind;
  #   zones = {
  #     "TESTDOMAIN" = {
  #       master = true;
  #       file = pkgs.writeText "testdomain.zone" ''
  #         $TTL 3600
  #         @   IN SOA  dc1.TESTDOMAIN. hostmaster.TESTDOMAIN. (
  #                 2025041001 ; serial
  #                 3600       ; refresh
  #                 900        ; retry
  #                 604800     ; expire
  #                 3600       ; minimum
  #             )
  #             IN NS  dc1.TESTDOMAIN.
  #         dc1 IN A 192.168.56.4
  #         _ldap._tcp.dc._msdcs IN SRV 0 100 389 dc1.TESTDOMAIN.
  #       '';
  #     };
  #   };
  # };

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [
  #   53 # for DNS
  #   137
  #   138
  #   139
  #   445
  # ];
  # networking.firewall.allowedUDPPorts = [
  #   53 # for DNS
  #   137
  #   138
  # ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # https://mynixos.com/
  system.stateVersion = "24.11";

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
}
