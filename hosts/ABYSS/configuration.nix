{ pkgs, lib, ... }:

{
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
  ];

  # Disable EFI bootloader and use GRUB for Legacy BIOS
  boot = {
    # IP forwarding & NAT so clients can access internet
    kernel.sysctl = {
      "net.ipv4.ip_forward" = true;
      "net.ipv6.conf.all.forwarding" = true;
    };

    loader.grub = {
      enable = true;
      device = "/dev/sda"; # or the appropriate disk, replace /dev/sda with your disk name

      # Set boot partition label for GRUB to use
      useOSProber = true;
    };
  };

  # Networking
  networking = {
    hostName = "ABYSS";
    networkmanager.enable = true;

    wireguard = {
      enable = true;
      # wg0 = {
      #   ips = [ "10.100.0.1/24" ];
      #   listenPort = 51820;
      #   privateKeyFile = "/etc/wireguard/server.key";

      #   peers = [
      #     {
      #       publicKey = "CLIENT_PUBLIC_KEY_HERE";
      #       allowedIPs = [ "10.100.0.2/32" ];
      #     }
      #   ];
      # };
    };

    firewall = {
      enable = false;
      allowedUDPPorts = [ 51820 ]; # Default WireGuard port
    };

    nat = {
      enable = true;
      internalInterfaces = [ "wg0" ];
      externalInterface = "enp1s0"; # 🠖 Replace with your real NIC, use `ip a` to check
    };
  };

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # List packages installed in system profile.
  # To search, go https://search.nixos.org/packages?channel=25.05&
  environment.systemPackages = with pkgs; [
    vim
    git
    nodePackages_latest.nodejs
    home-manager
    unzip
    htop
  ];

  # Enable the OpenSSH service
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false; # Disable password login
      PermitRootLogin = "no"; # Root login disabled
      PubkeyAuthentication = true; # Ensure pubkey authentication is enabled
      KexAlgorithms = [ "curve25519-sha256" ];
      Ciphers = [ "chacha20-poly1305@openssh.com" ];
      Macs = [ "hmac-sha2-512-etm@openssh.com" ];
    };
  };
}
