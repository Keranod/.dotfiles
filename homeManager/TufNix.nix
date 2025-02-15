{ pkgs, ... }:

let
  username = "keranod";
  pgadminVersion = "4";
  pgadminPackage = pkgs."pgadmin${pgadminVersion}-desktopmode";
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

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # List packages installed in user profile. 
  # To search, go https://search.nixos.org/packages?channel=24.11&
  home.packages = with pkgs; [
    vscode
    nixd # nix language server
    nixfmt-rfc-style
    pgadminPackage
    # hunderbird
    google-chrome
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
  home.sessionVariables = {
    # EDITOR = "emacs";
  };

  # GNOME settings


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

  programs.bash = {
    enable = true;
    shellAliases = {
      # exec $SHELL to restart shell and apply new aliases
      home-switch = "home-manager switch --flake ~/.dotfiles/#${username} && exec $SHELL";
    };
    initExtra = ''
      nix-rebuild() {
        if [ -z "$1" ]; then
          echo "Error: Missing configuration name in a flake!"
          echo "Usage: nix-rebuild <configurationname>"
          return 1
        fi
        
        sudo nixos-rebuild switch --flake ~/.dotfiles#"$1"
      }
    '';
  };

  # TODO
  # GNOME
  # Run `dconf watch /` and edit settings that you want to change and apply them below
  # notes taht sync with keep
  # dconf watch /
  dconf.settings = {
    # Does not work
    # "org/gnome/shell" = {
    #   last-selected-power-profile = "balanced";
    # };
    # "org/gnome/shell" = {
    #   disable-user-extensions = false;
    #   disabled-extensions = [];
    #   enabled-extensions = ["display-brightness-ddcutil@themightydeity.github.com"];
    # };
    "org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
      show-battery-percentage = true;
    };
    "org/gnome/desktop/peripherals/touchpad" = {
      natural-scroll = false;
    };
    "org/gnome/mutter" = { 
      edge-tiling = true;
      dynamic-workspaces = true;
    };
    "org/gnome/settings-daemon/plugins/power" = {
      power-button-action = "interactive";
      sleep-inactive-ac-type = "nothing";
      # Does not work
      # sleep-inactive-battery-timeout = "3600";
    };
  }; 

  # User services
  systemd.user.services.pgadmin4 = {
    Unit = {
      Description = "Pgadmin web interface";
      After = [ "default.target" "postgres.service" ];
    };

    Service = {
      ExecStart = "${pgadminPackage}/bin/pgadmin4";
      Restart = "always";
      WorkingDirectory = "%h";
    };

    Install = {
      WantedBy = [ "default.target" ];
    };
  };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
}
