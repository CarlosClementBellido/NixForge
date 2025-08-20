{ pkgs, ... }:

{
  nixpkgs.config.allowUnfree = true;
  virtualisation.libvirtd.enable = true;
  
  environment.systemPackages = with pkgs; [
    vim
    wget
    git
    pulseaudio
    nvtopPackages.full
    cudatoolkit
    glxinfo
  ];
}
