{
  pkgs,
  config,
  ...
}:

let
  serverHostName = "NixOSTest";
in
{
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
  ];

  # --- FDE & TPM Configuration ---
  
  # Enable systemd services in the initrd for advanced decryption methods
  boot.initrd.systemd.enable = true; 
  
  # Enable LUKS decryption support in the initial ramdisk (initrd)
  boot.initrd.luks.enable = true;

  # Default settings for EFI
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  fileSystems."/boot" = {
    fsType = "vfat";
  };

  boot.kernel.sysctl = {
    # IPv4
    # Enable IPv4 forwarding for the host to act as a router
    "net.ipv4.ip_forward" = 1;

    # Allows routing to local net ranges (helps with WireGuard/VETH interactions)
    "net.ipv4.conf.all.route_localnet" = 1;
    "net.ipv4.conf.default.route_localnet" = 1;

    # IPv6 (Optional if networking.enableIPv6 = false is used, but good redundancy)
    "net.ipv6.conf.all.disable_ipv6" = 1;
    "net.ipv6.conf.default.disable_ipv6" = 1;
  };

  nixpkgs.config.allowUnfree = true;

  # Virtualbox guest additions
  systemd.services.virtualbox.unitConfig.ConditionVirtualization = "oracle";
  # Enable VirtualBox guest additions
  virtualisation.virtualbox.guest = {
    enable = true;
    seamless = true;
    clipboard = true;
  };

  environment.systemPackages = with pkgs; [
    home-manager
    wireguard-tools
    restic
    nginx
  ];

  # Networking
  networking = {
    hostName = "${serverHostName}";
    firewall.enable = false;
    enableIPv6 = false;

    interfaces.enp3s0 = {
      useDHCP = false;
      ipv4.addresses = [
        {
          address = "10.0.2.20";
          prefixLength = 24;
        }
      ];
    };
    defaultGateway = "10.0.2.255";
  };

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false; # Disable password login
      PermitRootLogin = "no"; # Root login disabled
      PubkeyAuthentication = true; # Ensure pubkey authentication is enabled
    };
  };

  services.tlp = {
    enable = true;
    settings = {
      # Control whether TLP is enabled (1) or disabled (0)
      TLP_ENABLE = 1;

      # Disable Bluetooth and Wi-Fi when TLP starts up on boot.
      # This is often done to save power or ensure the radios are off
      # until explicitly enabled by the user or a service.
      DEVICES_TO_DISABLE_ON_STARTUP = "bluetooth wifi";

      # Optionally, you can also ensure they stay off when TLP shuts down
      # (e.g., during system halt/reboot).
      DEVICES_TO_DISABLE_ON_SHUTDOWN = "bluetooth wifi";

      # If you want TLP to manage the power state of the radios when the
      # power source changes (e.g., unplugged from AC to battery), you can set:
      # DEVICES_TO_DISABLE_ON_BAT = "bluetooth wifi";
    };
  };
}
