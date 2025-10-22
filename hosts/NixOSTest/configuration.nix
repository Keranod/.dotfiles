{
  pkgs,
  config,
  ...
}:

let
  serverHostName = "NixOSTest";

  # Check if the hardware configuration contains the LUKS device mapping
  isEncrypted = builtins.hasAttr "NIXROOT" config.boot.initrd.luks.devices;

  # --- TPM-LUKS Configuration Block ---
  # This block is only enabled if the hardware scan detected the LUKS volume,
  # but the services are always enabled for safety if the user decides to enable it later.
  tpmLuksConfig = {
    # 1. Enable TPM2 (Trusted Platform Module) services
    services.tpm2-setup.enable = true;

    # 2. Add the tpm2-luks utility and ensure it's in the initrd
    environment.systemPackages = with pkgs; [ tpm2-luks ];
    boot.initrd.extraUtils = [
      "tpm2-tools"
      "tpm2-luks"
    ];

    # 3. Configure the Initrd for LUKS if encryption is detected
    boot.initrd.luks = {
      enable = true; # Enables LUKS processing in the initrd

      # Configure the NIXROOT device for TPM unsealing.
      # This block will only be applied if the hardware scan found NIXROOT.
      devices =
        builtins.filterAttrs (name: device: name == "NIXROOT")
          # Use the existing device definition from hardware-configuration.nix
          config.boot.initrd.luks.devices
        // {
          # Overlay the existing NIXROOT device with the TPM specific settings
          NIXROOT = {
            keyFile = "/etc/tpm2-luks/keyfile";

            # This command is run to unseal the key file from the TPM
            preLuks = ''
              ${pkgs.tpm2-luks}/bin/tpm2-luks-unseal /etc/tpm2-luks/keyfile
            '';
            # Increase timeout to ensure the tpm2-unseal process has time to run
            timeout = 60;
          };
        };
    };
  };
in
{
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
  ];

  # Apply TPM-LUKS configuration if the hardware scan detected encryption
  # Otherwise, tpmLuksConfig will be an empty set, ensuring an unencrypted boot works.
  config = builtins.if isEncrypted then tpmLuksConfig else {};

  # Default settings for EFI
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  fileSystems."/boot" = {
    fsType = "vfat";
  };

  # Full Disk Encryption (FDE)
  # This enables LUKS decryption support in the initial ramdisk (initrd)
  boot.initrd.luks.enable = true;

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
