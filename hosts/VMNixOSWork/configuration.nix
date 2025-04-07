{ pkgs, ... }:

let
  legacyBind = import inputs.bindPkgs { inherit (pkgs) system; };
  legacySamba = import inputs.sambaPkgs { inherit (pkgs) system; };
in
{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  # Default settings for EFI
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  fileSystems."/boot" = {
    fsType = "vfat";
  };

  # Virtualbox guest additions
  systemd.services.virtualbox.unitConfig.ConditionVirtualization = "oracle";

  # Networking
  networking.hostName = "VMNixOSWork";
  networking.networkmanager.enable = true;

  # Configure network proxy if necessary
  networking.proxy.default = "192.9.253.10:80";
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

  # Enable the X11 windowing system.
  # You can disable this if you're only using the Wayland session.
  services.xserver.enable = true;

  # GNOME
  services.xserver.displayManager.gdm.enable = true;
  services.xserver.desktopManager.gnome.enable = true;
  services.xserver.displayManager.gdm.wayland = false;
  environment.gnome.excludePackages = (with pkgs; [
    gnome-photos
    gnome-tour
    gnome-weather
    gnome-maps
    # nautilus # File manager
    totem
    gedit
    cheese
    gnome-music
    # epiphany # needed for online accounts
    # geary
    gnome-characters
    tali
    iagno
    hitori
    atomix
    yelp
    gnome-initial-setup
    #gnome-contacts
  ]);
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

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

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
    #legacyBind.bind
    #legacySamba.samba
    #wireguard-tools
    #wireguard-ui
    # gnome-notes
    # gnomeExtensions.brightness-control-using-ddcutil
  ];

  # Enable the OpenSSH daemon.
  # services.openssh.enable = true;

  # Samba
  services.samba = {
    enable = true;
    package = legacySamba.samba;
    extraConfig = ''
      [global]
        workgroup = PSFRANKSNET
        security = user
        server min protocol = CORE
        server max protocol = NT1
        ntlm auth = yes

        passdb backend = tdbsam

        printing = cups
        printcap name = cups
        load printers = yes
        cups options = raw

        server string = Oracle Linux VM
        netbios name = ENDOR

        acl group control = yes
        add user script = sudo /usr/sbin/useradd -d /home/%u -s /bin/bash %u
        add machine script = sudo /usr/sbin/useradd -g machines -c "Samba Client" -d /dev/null -s /bin/false -M %u
        add group script = sudo /usr/sbin/groupadd %g
        admin users = iand
        allow nt4 crypto = yes
        delete user script = /usr/sbin/userdel %u
        delete group script = /usr/sbin/groupdel %g
        dns proxy = no
        domain logons = yes
        domain master = yes
        idmap config * : range = 10000 - 10999
        log level = 1
        logon drive = P:
        logon home = \\GALLIFREY\%U
        logon path =
        max log size = 50
        socket options = TCP_NODELAY
        time server = yes
        wins support = true

      [homes]
        comment = Home Directories
        valid users = %S, %D%w%S
        browseable = No
        read only = No
        inherit acls = Yes

      [printers]
        comment = All Printers
        path = /var/tmp
        printable = Yes
        create mask = 0600
        browseable = No

      [print$]
        comment = Printer Drivers
        path = /var/lib/samba/drivers
        write list = @printadmin root
        force group = @printadmin
        create mask = 0664
        directory mask = 0775
    '';
  };

  # Bind
  services.bind = {
    enable = true;
    package = legacyBind.bind;
  };

  # Open ports in the firewall.
  networking.firewall.allowedTCPPorts = [ 137 138 139 445 ];
  networking.firewall.allowedUDPPorts = [ 137 138 ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # https://mynixos.com/
  system.stateVersion = "24.11";

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Postgres Global setup
  # services.postgresql = {
  #   enable = true;
  #   package = postgresPackage;  # Install & enable same version
  #   enableTCPIP = true;
  #   # Authentication only to host, cannot make local work with scram
  #   # psql -U <username> -h 127.0.0.1
  #   authentication = ''
  #     #type database  DBuser  address        auth-method
  #     #local all       all                    peer
  #     host  all       all     127.0.0.1/32   scram-sha-256
  #   '';
  # };

  # Not working/not sorted yet
  # Always mount second hard drive
  # lsblk -> get /dev/<diskname>
  # sudo blkid /dev/<diskname> -> get uuid of the disk
  # fileSystems."/mnt/data" = {
  #   device = "/dev/disk/by-uuid/b298f8d8-1745-4581-ad9e-a58023d83f61";
  #   fsType = "ext4";
  #   options = [ "defaults" "nofail" ];
  # };
}
