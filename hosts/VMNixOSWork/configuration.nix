{
  pkgs,
  lib,
  ...
}:

let
  tvIp = "192.168.8.50"; # your TV’s static IP
  vpnInterface = "tun0"; # OpenVPN interface
  tableNum = 100; # custom routing table
  tvVpnConf = "/etc/vpn/AirVPN_Taiwan_UDP-443-Entry3.conf";
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

  # Only add if the local file exists
  environment.etc = lib.optionalAttrs (builtins.pathExists tvVpnConf) {
    "openvpn/tvVpn.ovpn".source = tvVpnConf;
    "openvpn/tvVpn.ovpn".mode   = "0600";
  };

  # Print a message to debug
systemd.services.tvVpnDebug = {
  description = "Debug TV VPN";
  wantedBy = [ "multi-user.target" ];
  serviceConfig.ExecStart = ''
    /run/current-system/sw/bin/bash -c 'echo "tvVpnConf variable: ${tvVpnConf}" > /var/log/tvVpnConf.log'
    /run/current-system/sw/bin/bash -c 'echo "tvVpnConf exists: ${toString (builtins.pathExists tvVpnConf)}" >> /var/log/tvVpnConf.log'
    /run/current-system/sw/bin/bash -c 'echo "tvVpnConf path: ${tvVpnConf}" >> /var/log/tvVpnConf.log'
  '';
};

  # Only start the OpenVPN service if the config exists
  # services.openvpn.servers.tvVpn = lib.optionalAttrs (builtins.pathExists tvVpnConf) {
  #   config    = ''config ${tvVpnConf}'';  # Corrected syntax
  #   autoStart = true;
  # };

  # Enable the OpenSSH daemon.
  # services.openssh.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [
  # ];
  # networking.firewall.allowedUDPPorts = [
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
