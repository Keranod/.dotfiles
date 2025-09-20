{ pkgs, ... }:

let
  pgadminVersion = "4";
  pgadminPackage = pkgs."pgadmin${pgadminVersion}-desktopmode";
in
{
  home.packages = with pkgs; [
    pgadminPackage
    google-chrome
    vlc
    prismlauncher
    deskreen
    blender
    qbittorrent
    handbrake
    wechat-uos
    unar
    tor-browser-bundle-bin
    evolution
  ];

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
}
