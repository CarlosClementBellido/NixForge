{ config, pkgs, lib, ... }:

{
  sound.enable = true;

  hardware.pulseaudio.enable = false;
  nixpkgs.config.pulseaudio = false;

  security.rtkit.enable = true;

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;

    systemWide = true;

    configPackages = [
      (pkgs.writeTextDir "share/pipewire/pipewire-pulse.conf.d/99-tcp.conf" ''
        pulse.properties = {
          server.address = [ "unix:native" "tcp:4713" ]
          auth-anonymous = true
        }
      '')
    ];
  };

  boot.kernelModules = [
    "snd_hda_intel"
    "snd_hda_codec_realtek"
    "snd_hda_codec_hdmi"
  ];
}
