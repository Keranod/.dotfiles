{ pkgs, ... }:

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
  home.packages = with pkgs; [
    vlc
  ];

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

  # GNOME
  dconf.settings = {
    "system/proxy" = {
      mode = "manual";
    };
    "system/proxy/http" = {
      port = 80;
      host = "192.9.253.10";
    };
    "system/proxy/https" = {
      port = 80;
      host = "192.9.253.10";
    };
  };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
}
