{ pkgs, ... }:

let
  serverHostName = "ABYSS";
in
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
    hostName = serverHostName;
    networkmanager.enable = false;

    wireguard = {
      enable = true;
      interfaces = {
        "vpn-network" = {
          ips = [ "10.0.0.1/24" ];
          listenPort = 51820;
          privateKeyFile = "/etc/wireguard/${serverHostName}.key";
          peers = [
            {
              name = "NetworkBox";
              publicKey = "bz6RDT3d0Ht0rnOLh3idAcc7H4Jf4CsNkJ3eE5wAC0g=";
              allowedIPs = [
                "10.0.0.2/32"
              ];
            }
            {
              name = "myAndroid";
              publicKey = "VzIT73Ifb+gnEoT8FNCBihAuOPYREXL6HdMwAjNCJmw=";
              allowedIPs = [
                "10.0.0.3/32"
              ];
            }
            {
              name = "TufNix";
              publicKey = "Pegp2QEADJjV/zDPCXxA4OKObSCSBOFm0dRJvEPRjzg=";
              allowedIPs = [
                "10.0.0.4/32"
              ];
            }
            {
              name = "babyIPhone";
              publicKey = "9aLtuWpRtk5qaQeEVSgQcu1Fgtej4gUauor19nVKnBA=";
              allowedIPs = [
                "10.0.0.5/32"
              ];
            }
          ];
        };
      };
    };

    firewall.enable = false;

    nftables = {
      enable = true;
      ruleset = ''
                table inet filter {
            chain input {
                type filter hook input priority 0; policy accept;
                # You can also use a "drop" policy and be more specific:
                # type filter hook input priority 0; policy drop;
                # iifname "lo" accept;
                # ct state { established, related } accept;
                # iifname { "vpn-network", "enp1s0" } accept; # This is just for testing!
            }

            chain forward {
                type filter hook forward priority 0; policy accept;
            }
        }


                table ip nat {
                    chain postrouting {
                        type nat hook postrouting priority 100; policy accept;

                        # Masquerade traffic from the VPN network as it exits to the internet via enp1s0
                        ip saddr 10.0.0.0/24 oifname "enp1s0" masquerade;
                    }
                }
      '';
    };
  };

  # List packages installed in system profile.
  # To search, go https://search.nixos.org/packages?channel=25.05&
  environment.systemPackages = with pkgs; [
    nodePackages_latest.nodejs
    home-manager
    wireguard-tools
    hysteria
  ];

  # Enable the OpenSSH service
  services.openssh = {
    enable = true;
    openFirewall = false;
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
