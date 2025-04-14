{ pkgs, pkgsUnstable_, ... }:

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

  #For c# in vscode extension
  nixpkgs.config.permittedInsecurePackages = [
    "dotnet-sdk-6.0.428"
  ];

  # List packages installed in user profile.
  # To search, go https://search.nixos.org/packages?channel=24.11&
  home.packages = with pkgs; [
    (pkgs.buildFHSUserEnv {
      name = "vscode-fhs";
      targetPkgs = pkgs: [
        pkgsUnstable_.vscode
        pkgsUnstable_.icu
        pkgsUnstable_.openssl
      ];
      runScript = ''
        #!/usr/bin/env bash
        LD_LIBRARY_PATH="${pkgs.icu}/lib:${pkgs.openssl}/lib:$LD_LIBRARY_PATH"
        export LD_LIBRARY_PATH
        exec ${pkgsUnstable_.vscode}/bin/code
      '';
    })
    nixd # nix language server
    nixfmt-rfc-style
    pgadminPackage
    google-chrome
    vlc
    prismlauncher
    dotnet-sdk_9
    #godot_4-mono
    pkgsUnstable_.godot-mono
    pkgsUnstable_.vscode
    pkgsUnstable_.discord
    icu
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
      After = [
        "default.target"
        "postgres.service"
      ];
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
