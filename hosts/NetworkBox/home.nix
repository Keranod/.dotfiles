{
  programs.bash = {
    enable = true;
    shellAliases = {
      add-tv-to-vpn = "sudo ip rule add from 192.168.9.50 table vpn && sudo ip route add default dev wg0 table vpn";
      remove-tv-from-vpn = "sudo ip rule del from 192.168.9.50 table vpn && sudo ip route del default dev wg0 table vpn";
    };
  };
}
