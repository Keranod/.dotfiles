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
                type filter hook input priority 0; policy drop;

                # Allow loopback traffic
                iif "lo" accept;

                # Allow established and related connections
                ct state established,related accept;

                # Allow incoming WireGuard connections on the public interface
                iifname "enp1s0" udp dport 51820 ct state new accept;
                
                # Allow all VPN clients to send DNS queries to the NetworkBox
                iifname "vpn-network" ip daddr 10.0.0.2 tcp dport 53 accept;
                iifname "vpn-network" ip daddr 10.0.0.2 udp dport 53 accept;

                # Allow SSH connections from any VPN client
                iifname "vpn-network" tcp dport 22 ct state new limit rate 1/minute accept;

                # Allow incoming Hysteria connections on UDP port 443
                iifname "enp1s0" udp dport 443 ct state new accept;
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

  # This JSON file contains all the settings for the server.
  environment.etc."hysteria/server.json".text = ''
    {
      "listen": ":443",
      "acme": {
        "domains": [
          "keranod.dev"
        ],
        "email": "konrad.konkel@wp.pl"
      },
      "obfs": "your-secret-password",
      "masquerade": {
        "domain": "www.cloudflare.com"
      },
      "up_mbps": 100,
      "down_mbps": 100
    }
  '';

  # This service uses the configuration file
  systemd.services.hysteria-server = {
    description = "Hysteria Server";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    path = [ pkgs.hysteria ];
    serviceConfig = {
      ExecStart = "${pkgs.hysteria}/bin/hysteria server --config /etc/hysteria/server.json";
      Restart = "always";
      User = "root"; # It needs root to listen on port 443
    };
  };
}
