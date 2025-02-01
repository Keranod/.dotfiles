{ config, pkgs, ... }: 

{
  boot.kernelParams = [ "nvidia.NVreg_EnableGpuFirmware=0" ];
# "nouveau.modeset=0" "i915.modeset=0" 
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

  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = false;
    powerManagement.finegrained = false;
    open = false;
    nvidiaSettings = true;
    
    prime = {
      # offload = {
      #   enable = true;
      #   enableOffloadCmd = true;
      # };
      sync.enable = true;
      intelBusId = "PCI:00:02:0";
      nvidiaBusId = "PCI:01:00:0";
    };

    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };
}