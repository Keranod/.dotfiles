{ pkgs, pkgsUnstable_, ... }:

let
  wrappedGodot = pkgs.buildFHSUserEnv {
    name = "godot-fhs";
    targetPkgs =
      pkgs: with pkgsUnstable_; [
        godot-mono
      ];
    multiPkgs = null;
    profile = ''
      export DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1
    '';
    runScript = ''
      #!/usr/bin/env bash

      # Run Godot with mono
      exec ${pkgsUnstable_.godot-mono}/bin/godot --editor "\$@"
    '';
  };

  wrappedGodotVM = pkgs.buildFHSUserEnv {
    name = "godot-fhsvm";
    targetPkgs =
      pkgs: with pkgsUnstable_; [
        godot-mono
      ];
    multiPkgs = null;
    profile = ''
      export DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1
    '';
    runScript = ''
      #!/usr/bin/env bash

      # Run Godot with mono
      exec ${pkgsUnstable_.godot-mono}/bin/godot --editor --rendering-driver opengl3 "\$@"
    '';
  };

in
{
  home.packages = [
    wrappedGodot
    wrappedGodotVM
  ];
}
