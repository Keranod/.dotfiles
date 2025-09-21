{ pkgs, ... }:

let
  pgadminVersion = "4";
  pgadminPackage = pkgs."pgadmin${pgadminVersion}-desktopmode";

  librewolfProfileName = "default";
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
        "browser.toolbar.bookmarks.visibility" = "newtab";
        "browser.toolbars.bookmarks.visibility" = "newtab";
        "browser.urlbar.suggest.bookmark" = false;
        "browser.urlbar.suggest.engines" = false;
        "browser.urlbar.suggest.history" = false;
        "browser.urlbar.suggest.openpage" = false;
        "browser.urlbar.suggest.recentsearches" = false;
        "browser.urlbar.suggest.topsites" = false;
        "browser.warnOnQuit" = false;
        "browser.warnOnQuitShortcut" = false;
        "places.history.enabled" = "false";
        "privacy.resistFingerprinting" = true;
        "privacy.resistFingerprinting.autoDeclineNoUserInputCanvasPrompts" = true;
      };
    };
  };

  # Optional: Automatically enable extensions
  programs.librewolf.profiles.${librewolfProfileName}.

  # User services
  systemd.user.services.pgadmin4 =
    {
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

  # LibreWolf configuration
  home.file."~/.config/librewolf/user.js".text = ''
    // Privacy settings
    user_pref("privacy.trackingprotection.enabled", true);
    user_pref("privacy.trackingprotection.pbmode.enabled", true);
    user_pref("privacy.resistFingerprinting", true);
    user_pref("privacy.firstparty.isolate", true);
    user_pref("network.cookie.cookieBehavior", 1); // Only allow first-party cookies
    user_pref("browser.cache.offline.enable", false);
    user_pref("dom.webnotifications.enabled", false);
    user_pref("geo.enabled", false);
    user_pref("media.autoplay.default", 5); // Block autoplay
    user_pref("browser.safebrowsing.enabled", true);
    user_pref("browser.safebrowsing.malware.enabled", true);
    user_pref("browser.safebrowsing.phishing.enabled", true);
  '';

  # Install specific extensions
  home.file."~/.librewolf/extensions.json".text = ''
    {
      "schemaVersion": 1,
      "extensions": {
        "uBlockOrigin@raymondhill.net": {
          "version": "1.39.2",
          "update_url": "https://addons.mozilla.org/firefox/addon/ublock-origin/versions/"
        },
        "privacybadger@eff.org": {
          "version": "2025.9.1",
          "update_url": "https://addons.mozilla.org/firefox/addon/privacy-badger17/versions/"
        },
        "https-everywhere@eff.org": {
          "version": "2025.9.1",
          "update_url": "https://addons.mozilla.org/firefox/addon/https-everywhere/versions/"
        },
        "floccus@floccus.org": {
          "version": "4.4.0",
          "update_url": "https://addons.mozilla.org/firefox/addon/floccus/versions/"
        },
        "bitwarden-browser@bitwarden.com": {
          "version": "2025.9.1",
          "update_url": "https://addons.mozilla.org/firefox/addon/bitwarden-password-manager/versions/"
        }
      }
    }
  '';
}
