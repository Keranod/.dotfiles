{ pkgs, ... }:

{
  home.packages = with pkgs; [
    vlc
  ];

  programs.bash = {
    enable = true;
    initExtra = ''
      proxyWork() {
          # Proxy address
          PROXY_URL="http://192.9.253.50:80"

          # Export for current shell session
          export http_proxy="$PROXY_URL"
          export https_proxy="$PROXY_URL"
          export all_proxy="$PROXY_URL"
          export no_proxy="localhost,127.0.0.1"

          # Apply to systemd environment (used by nix-daemon)
          sudo systemctl set-environment \
            http_proxy="$PROXY_URL" \
            https_proxy="$PROXY_URL" \
            all_proxy="$PROXY_URL" \
            no_proxy="localhost,127.0.0.1"

          # Restart nix-daemon so it picks up the environment changes
          sudo systemctl restart nix-daemon

          echo "Proxy temporarily set for this shell and nix-daemon."
      }
    '';
  };
}
