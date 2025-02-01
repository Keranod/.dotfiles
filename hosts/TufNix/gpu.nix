{ config, pkgs, ... }: 

{
  boot.kernelParams = [ "nouveau.modeset=0" "i915.modeset=0" "nvidia.NVreg_EnableGpuFirmware=0" ];
}