{ pkgs, pkgsUnstable_, ... }:

let
  username = "keranod";
  wrappedGodot = pkgs.writeShellScriptBin "godot" ''
    export LD_LIBRARY_PATH=${pkgsUnstable_.icu}/lib:$LD_LIBRARY_PATH
    exec ${pkgsUnstable_.godot-mono}/bin/godot "$@"
  '';
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
  # nixpkgs.config.permittedInsecurePackages = [
  #   "dotnet-sdk-6.0.428"
  # ];

  # List packages installed in user profile.
  # To search, go https://search.nixos.org/packages?channel=24.11&
  home.packages = with pkgs; [
    (buildFHSUserEnv {
      name = "vscode-fhs";
      targetPkgs = pkgs: [
        pkgsUnstable_.vscode
        pkgsUnstable_.icu
        pkgsUnstable_.openssl
        pkgsUnstable_.dotnet-sdk_8
      ];
      runScript = ''
        #!/usr/bin/env bash
        export LD_LIBRARY_PATH="${pkgsUnstable_.icu}/lib:${pkgsUnstable_.openssl}/lib:$LD_LIBRARY_PATH"
        export PATH="${pkgsUnstable_.dotnet-sdk_8}/bin:$PATH"
        export DOTNET_ROOT="${pkgsUnstable_.dotnet-sdk_8}/share/dotnet"
        exec ${pkgsUnstable_.vscode}/bin/code
      '';
    })
    nixd # nix language server
    nixfmt-rfc-style
    vlc
    #dotnet-sdk_8
    #pkgsUnstable_.godot-mono # To run use in termial `godot --rendering-driver opengl3` otherwise running project crashes
    #pkgsUnstable_.vscode
    #pkgsUnstable_.icu
    wrappedGodot
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
    };
    "system/proxy" = {
      mode = "manual";
      # http-host = "192.9.253.10";
      # http-port = 80;
      # https-host = "192.9.253.10";
      # https-port = 80;
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
