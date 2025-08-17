{ ... }:

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
  };

  boot.kernelModules = [
    "snd_hda_intel"
    "snd_hda_codec_realtek"
    "snd_hda_codec_hdmi"
  ];
}