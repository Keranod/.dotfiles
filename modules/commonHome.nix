{ pkgs,pkgsUnstable_, ... }:

let
  username = "keranod";
in
{
  # Infomration for home-manager which path to manage
  home.username = username;
  home.homeDirectory = "/home/${username}";

  # This value determines the Home Manager release that your configuration is
  # compatible with. This helps avoid breakage when a new Home Manager release
  # introduces backwards incompatible changes.
  #
  # You should not change this value, even if you update Home Manager. If you do
  # want to update the value, then make sure to first check the Home Manager
  # release notes.
  home.stateVersion = "24.05"; # Please read the comment before changing.

  # List packages installed in user profile.
  # To search, go https://search.nixos.org/packages?channel=24.11&
  # home.packages = with pkgs; [
  #
  # ];

  nix.nixPath = [ "nixpkgs=${pkgs.path}" ];

  # Home Manager can also manage your environment variables through
  # 'home.sessionVariables'. These will be explicitly sourced when using a
  # shell provided by Home Manager. If you don't want to manage your shell
  # through Home Manager then you have to manually source 'hm-session-vars.sh'
  # located at either
  #
  #  ~/.nix-profile/etc/profile.d/hm-session-vars.sh
  #
  # or
  #
  #  ~/.local/state/nix/profiles/profile/etc/profile.d/hm-session-vars.sh
  #
  # or
  #
  #  /etc/profiles/per-user/keranod/etc/profile.d/hm-session-vars.sh
  #
  home.sessionVariables = {
    # EDITOR = "emacs";
  };

  # User programs settings
  programs.git = {
    enable = true;
    userName = username;
    userEmail = "konrad.konkel@wp.pl";
    extraConfig = {
      init.defaultBranch = "main";
      color.ui = "auto";
      pull.rebase = "false";
      merge.tool = "code";
      mergetool.vscode.cmd = "code --wait $MERGED";
      core.editor = "code --wait";
    };
  };

  programs.ssh = {
    enable = true;
    extraConfig = ''
      Host github.com
        IdentityFile /home/keranod/.dotfiles/.ssh/id_rsa
        IdentitiesOnly yes
    '';
  };

  programs.bash = {
    enable = true;
    shellAliases = {
      # exec $SHELL to restart shell and apply new aliases
      home-switch = "home-manager switch --flake ~/.dotfiles --show-trace && exec $SHELL";
    };
    initExtra = ''
      nix-rebuild() {
          # Check if an argument is passed, otherwise fallback to hostname
          local config
          if [ -z "$1" ]; then
              config=$(hostname)
          else
              config="$1"
          fi
          
          echo "Rebuilding NixOS with configuration: $config"
          
          sudo nixos-rebuild switch --flake ~/.dotfiles#"$config" --show-trace && exec $SHELL
      }

      ssh-connect() {
          if [ $# -lt 1 ]; then
              echo "Usage: ssh-connect <IP>"
              return 1
          fi
          
          local ip="$1"
          
          echo "Connecting to $ip..."
          ssh -i ~/.dotfiles/.ssh/id_rsa "keranod@$ip"
      }

      vpnroute() {
        IP="$1"
        CONFIG="$2"

        if [[ -z "$IP" || -z "$CONFIG" ]]; then
          echo "Usage: $0 <IP_ADDRESS> <OPENVPN_CONFIG_PATH>"
          exit 1
        fi

        IFACE="tun-$IP"  # Create custom interface name (example: tun-192.168.8.50)
        TABLE_ID=$(echo "$IP" | awk -F'.' '{print $3$4}') # Example: 50 for 192.168.8.50 -> 850

        start_vpn() {
          echo "Starting OpenVPN for IP $IP with config $CONFIG..."

          # Launch OpenVPN (give it a specific dev tun name)
          openvpn --config "$CONFIG" --dev "$IFACE" --daemon --writepid "/run/vpn\\\${IP}.pid"

          # Wait for interface
          while ! ip link show "$IFACE" > /dev/null 2>&1; do
            echo "Waiting for interface $IFACE to come up..."
            sleep 1
          done

          # Setup routing
          echo "Setting up routing table $TABLE_ID for $IP over $IFACE"
          ip route add default dev "$IFACE" table "$TABLE_ID"
          ip rule add from "$IP" lookup "$TABLE_ID" priority 100
        }

        stop_vpn() {
          echo "Stopping OpenVPN and cleaning up routes for IP $IP..."

          # Remove rules
          ip rule del from "$IP" lookup "$TABLE_ID" priority 100 || true
          ip route del default dev "$IFACE" table "$TABLE_ID" || true

          # Kill OpenVPN
          if [ -f "/run/vpn-\\\${IP}.pid" ]; then
            kill "$(cat /run/vpn-\\\${IP}.pid)" || true
            rm -f "/run/vpn-\\\${IP}.pid"
          fi
        }

        case "$3" in
          start)
            start_vpn
            ;;
          stop)
            stop_vpn
            ;;
          restart)
            stop_vpn
            start_vpn
            ;;
          *)
            echo "Usage: $0 <IP_ADDRESS> <OPENVPN_CONFIG_PATH> {start|stop|restart}"
            exit 1
            ;;
        esac
      }
    '';
  };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
}
