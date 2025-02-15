{
  # Common configurations
  programs.ssh = {
    enable = true;
    keyFiles = [
      "./.ssh/id_rsa"
    ];
  };
}
