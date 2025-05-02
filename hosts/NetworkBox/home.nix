{
  programs.bash = {
    enable = true;
    shellAliases = {
      add-tv-to-vpn = "sudo ip rule add from 192.168.9.60 table 100 && sudo ip route add default dev wg0 table 100";
      remove-tv-from-vpn = "sudo ip rule del from 192.168.9.60 table 100 && sudo ip route del default dev wg0 table 100";
    };
  };
}
