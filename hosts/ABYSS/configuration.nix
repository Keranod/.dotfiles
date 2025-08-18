{ pkgs, ... }:

let
  domain = "keranod.dev";
  vaultDomain = "vault.keranod.dev";
  acmeRoot = "/var/lib/acme";
  acmeDomainDir = "${acmeRoot}/${domain}";
  acmeVaultDomainDir = "${acmeRoot}/${vaultDomain}";
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
      # "net.ipv6.conf.all.forwarding" = true;
      # "net.ipv4.conf.all.route_localnet" = 1;
      # "net.ipv4.conf.default.route_localnet" = 1;
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
    networkmanager.enable = false;

    wireguard = {
      enable = true;
      interfaces = {
        wg0 = {
          ips = [ "10.100.0.100/32" ];
          listenPort = 51820;
          privateKeyFile = "/etc/wireguard/server.key";
          mtu = 1340;
          peers = [
            # NetworkBox
            {
              publicKey = "rGShQxK1qfo6GCmgVBoan3KKxq0Z+ZkF1/WxLKvM030=";
              allowedIPs = [
                "10.100.0.1/32"
                "10.200.0.0/24"
              ];
            }
          ];
        };
        wg1 = {
          ips = [ "10.150.0.100/32" ];
          listenPort = 51822;
          privateKeyFile = "/etc/wireguard/server.key";
          mtu = 1340;
          peers = [
            # NetworkBox
            {
              publicKey = "rGShQxK1qfo6GCmgVBoan3KKxq0Z+ZkF1/WxLKvM030=";
              allowedIPs = [
                "10.150.0.1/32"
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
        table ip nat {
            chain prerouting {
                type nat hook prerouting priority -100;
                iifname "enp1s0" udp dport 51821 dnat to 10.200.0.1:51821;
            }

            chain postrouting {
                type nat hook postrouting priority 100; policy accept;

                ip saddr 10.150.0.0/24 oifname "enp1s0" masquerade;
                ip saddr 10.200.0.0/24 oifname "enp1s0" masquerade;
                
                # !!! DO NOT RMEOVE NEEDE FOR PROPER WORKING OF WG IN WG TUNNELS
                oifname "wg0" ip saddr 0.0.0.0/0 snat to 10.100.0.100;
            }
        }

        table inet filter {
            chain input {
                type filter hook input priority 0; policy drop;
                
                iif "lo" accept;
                ct state established,related accept;
                
                # Allow the outer WG tunnels to connect
                # Rate-limit new connections to the WireGuard tunnels on the public interface
                iifname "enp1s0" udp dport { 51820, 51821, 51822 } ct state new limit rate 5/second accept;

                # SSH is now only allowed from the wg0 interface
                iifname "wg0" tcp dport 22 ct state new limit rate 1/minute accept;

                # Accept DoH only from wg1
                iifname "wg1" tcp dport 853 accept;
                iifname "wg1" udp dport 853 accept;
            }

            chain forward {
                type filter hook forward priority 0; policy drop;
                
                iifname "wg1" oifname "enp1s0" ct state new,established,related accept;
                iifname "enp1s0" oifname "wg1" ct state established,related accept;
                
                iifname "enp1s0" oifname "wg0" ct state new,established,related accept;
                iifname "wg0" oifname "enp1s0" ct state established,related accept;
            }
        }
      '';
    };
  };

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

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

  systemd.services.hysteria-server = {
    enable = false;
    description = "Hysteria 2 Server";
    after = [
      "network.target"
      "acme-finished-${domain}.service"
    ];
    wantedBy = [ "multi-user.target" ];

    preStart = ''
            PASSWORD="$(cat /etc/secrets/hysteriav2)"
            cat > /run/hysteria/config.yaml <<EOF
      #disableUDP: true
      tls:
        cert: ${acmeDomainDir}/fullchain.pem
        key:  ${acmeDomainDir}/key.pem
      auth:
        type:     password
        password: "$PASSWORD"
      obfs:
        type: salamander
        salamander:
          password: "$PASSWORD"
      masquerade:
        type: proxy
        forceHTTPS: true
        proxy:
            url: "https://www.wechat.com"
            rewriteHost: true
      EOF
    '';

    serviceConfig = {
      Type = "simple";
      User = "root";
      AmbientCapabilities = "CAP_NET_BIND_SERVICE";
      StandardOutput = "journal";
      StandardError = "journal";
      RuntimeDirectory = "hysteria";

      ExecStart = "${pkgs.hysteria}/bin/hysteria server --config /run/hysteria/config.yaml";
      Restart = "always";
    };
  };
}
