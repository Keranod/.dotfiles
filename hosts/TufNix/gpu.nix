{ config, pkgs, ... }: 

let
  nvidiaPackage = config.boot.kernelPackages.nvidiaPackages.stable;
in
{
  # TODO: is internal 60hz only when not plugged in? fix regardless to be full fps
  # Force usage of nvidia gpu for rendering/ Disable Intel gpu?
  # Better colors
  boot.kernelParams = [ "i915.modeset=0" "nvidia.NVreg_EnableGpuFirmware=0" ];
  #   "nouveau.modeset=0" 
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      libvdpau
      vaapiVdpau
      libva
      vulkan-loader
      vulkan-validation-layers
      nvidia-vaapi-driver
    ];
  };

  services.xserver.videoDrivers = [ "nvidia" ];

  # Does not work
  # Disable Nvidia power management services for suspen/hibernate issues
  # services.nvidia-suspend.enable = false;
  # services.nvidia-hibernate.enable = false;
  # services.nvidia-resume.enable = false;

  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = true;
    powerManagement.finegrained = false;
    open = false;
    nvidiaSettings = true;
    nvidiaPersistenced = true;
    dynamicBoost.enable = true;
    
    # prime = {
    #   sync.enable = true;
    #   intelBusId = "PCI:00:02:0";
    #   nvidiaBusId = "PCI:01:00:0";
    # };

    package = nvidiaPackage;
  };

  # Service that on each boot changes min and max clock values to reduce lag when GPU idle
  # nvidia-smi --query-supported-clocks=graphics --format=cs -> get avilable clock speeds
  # nvidia-smi -rgc -> reset nvidia clocks
  # nvidia-smi -lgs <minvalue>,<maxvalue> -> specyfi nvidia cloc values
  # nvidia-smi --query-gpu=clocks.gr --format=csv,noheader,nounits -> to check min value
  systemd.services.nvidia-gpu-boost = {
    description = "Set NVIDIA GPU Clock Speed";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${nvidiaPackage.bin}/bin/nvidia-smi -lgc 1500,2100";
      RemainAfterExit = true;
    };
  };
}