{ config, pkgs, ... }:

let
  #hostname = builtins.getEnv "HOSTNAME";
in
{
  imports = [
    ./common.nix # Common settings
    (import ./homeManager/${builtins.getEnv "HOSTNAME"}.nix) # Load host-specific config
  ];
}
