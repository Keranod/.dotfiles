{ pkgs, ... }:

let
  pgadminVersion = "4";
  pgadminPackage = pkgs."pgadmin${pgadminVersion}-desktopmode";
in
{
  home.packages = with pkgs; [
    pgadminPackage
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

  programs.firefox = {
    enable = true;
    package = pkgs.librewolf;
    policies = {
      DisableTelemetry = true;
      DisableFirefoxStudies = true;
      # https://mozilla.github.io/policy-templates/#extensionsettings
      ExtensionSettings = {
        "uBlock0@raymondhill.net" = {
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi";
          installation_mode = "force_installed";
        };
        "floccus@handmadeideas.org" = {
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/floccus/latest.xpi";
          installation_mode = "force_installed";
        };
        "{446900e4-71c2-419f-a6a7-df9c091e268b}" = {
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/bitwarden-password-manager/latest.xpi";
          installation_mode = "force_installed";
        };
      };
      FirefoxHome = {
        "Search" = false;
      };
      HardwareAcceleration = true;
      Preferences = {
        "browser.preferences.defaultPerformanceSettings.enabled" = false;
        "browser.startup.homepage" = "about:home";
        "browser.toolbar.bookmarks.visibility" = "alwyas";
        "browser.toolbars.bookmarks.visibility" = "alwyas";
        "browser.urlbar.suggest.bookmark" = false;
        "browser.urlbar.suggest.engines" = false;
        "browser.urlbar.suggest.history" = false;
        "browser.urlbar.suggest.openpage" = false;
        "browser.urlbar.suggest.recentsearches" = false;
        "browser.urlbar.suggest.topsites" = false;
        "browser.warnOnQuit" = true;
        "browser.warnOnQuitShortcut" = true;
        "places.history.enabled" = true;
        "privacy.resistFingerprinting" = true;
        "privacy.resistFingerprinting.autoDeclineNoUserInputCanvasPrompts" = true;
        "privacy.clearOnShutdown.cache" = false;
        "privacy.clearOnShutdown.cookies" = false;
        "privacy.clearOnShutdown.downloads" = false;
        "privacy.clearOnShutdown.formdata" = false;
        "privacy.clearOnShutdown.history" = false;
        "privacy.clearOnShutdown.offlineApps" = false;
        "privacy.clearOnShutdown.openWindows" = false;
        "privacy.clearOnShutdown.sessions" = false;
        "privacy.clearOnShutdown.siteSettings" = false;
        "browser.theme.content-theme" = "dark";
      };
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
}
