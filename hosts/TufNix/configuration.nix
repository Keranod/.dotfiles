{
  pkgs,
  ...
}:

let
  postgresVersion = "17"; # Define PostgreSQL version once
  postgresPackage = pkgs."postgresql_${postgresVersion}";
  anydesk = pkgs.anydesk;
in
{
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ./gpu.nix
  ];

  # Default settings for EFI
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  fileSystems."/boot" = {
    fsType = "vfat";
  };

  # Networking
  networking.hostName = "TufNix";
  networking.networkmanager.enable = true;

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable the X11 windowing system.
  # You can disable this if you're only using the Wayland session.
  services.xserver.enable = true;

  # GNOME
  services.xserver = {
    displayManager.gdm = {
      enable = true;
      wayland = false;
    };
    desktopManager.gnome.enable = true;
  };
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
    nodePackages_latest.nodejs
    home-manager
    gnome-tweaks
    gnome-online-accounts
    #xdg-desktop-portal
    #xdg-desktop-portal-gtk
    #gvfs
    gnome-network-displays
    anydesk
  ];

  # Enable the OpenSSH daemon.
  # services.openssh.enable = true;

  # Open ports in the firewall.
  networking.firewall.allowedTCPPorts = [
    5173
    45000
  ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # Postgres Global setup
  services.postgresql = {
    enable = true;
    package = postgresPackage; # Install & enable same version
    enableTCPIP = true;
    # Authentication only to host, cannot make local work with scram
    # psql -U <username> -h 127.0.0.1
    authentication = ''
      #type database  DBuser  address        auth-method
      #local all       all                    peer
      host  all       all     127.0.0.1/32   scram-sha-256
    '';
  };

  # Stop the service to change password and settings
  systemd.services.anydesk = {
    description = "AnyDesk remote desktop service";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      # run the headless daemon
      ExecStart = "${anydesk}/bin/anydesk --service";
      Type = "simple";
      Restart = "always";
    };
  };

  # Always mount second hard drive
  # sudo lsblk -o name,mountpoint,label,size,uuid -> get disk details
  fileSystems."/mnt/data" = {
    device = "/dev/disk/by-uuid/d7222132-56ed-4f35-889e-417f9d7c3f3b";
    fsType = "ext4";
    options = [
      "defaults"
      "nofail"
      "x-systemd.automount"
      "x-systemd.device-timeout=10s"
    ];
  };

  # xdg.portal = {
  #   enable = true;
  #   extraPortals = [
  #     pkgs.xdg-desktop-portal-gtk
  #   ];
  # };
}
