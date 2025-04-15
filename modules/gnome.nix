{ ... }:
{
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
}
