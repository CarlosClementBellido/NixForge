{ config, pkgs, lib, ... }:

let
  venvPath = "/var/lib/hotword/venv";
  appDir   = "/etc/hotword";
in
{
  environment.systemPackages = with pkgs; [
    alsa-utils
    alsa-plugins
    pulseaudio
    portaudio
    ffmpeg
    cacert
  ];

  environment.etc."hotword/hotword.py".text = builtins.readFile ./hotword.py;

  environment.etc."openwakeword/.keep".text = "";

  environment.etc."asound.conf".text = ''
    pcm.!default {
      type pulse
      fallback "sysdefault"
      hint.description "PulseAudio Sound Server"
    }
    ctl.!default {
      type pulse
      fallback "sysdefault"
    }
  '';

  environment.etc."pulse/client.conf".text = ''
    default-server = tcp:192.168.105.1:4713
    autospawn = no
  '';

  systemd.services.hotword-venv-setup = {
    description = "Prepare venv for Hotword (RealtimeSTT + optional OpenWakeWord models)";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];

    path = [
      pkgs.coreutils pkgs.bash pkgs.python3 pkgs.pkg-config
      pkgs.portaudio pkgs.alsa-lib pkgs.alsa-plugins pkgs.pulseaudio
      pkgs.gcc pkgs.stdenv.cc.cc.lib pkgs.zlib pkgs.libffi
      pkgs.python3Packages.virtualenv
    ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      Environment = [
        "HOME=/root"
        "PIP_DISABLE_PIP_VERSION_CHECK=1"
        "PIP_NO_CACHE_DIR=1"
        "CFLAGS=-I${pkgs.portaudio}/include -I${pkgs.alsa-lib}/include"
        "LDFLAGS=-L${pkgs.portaudio}/lib -L${pkgs.alsa-lib}/lib"
        "PKG_CONFIG_PATH=${pkgs.portaudio}/lib/pkgconfig:${pkgs.alsa-lib}/lib/pkgconfig"
        "ALSA_PLUGIN_DIR=${pkgs.alsa-plugins}/lib/alsa-lib"
        "ALSA_CONFIG_PATH=/etc/asound.conf"
        "LD_LIBRARY_PATH=${pkgs.stdenv.cc.cc.lib}/lib:${pkgs.zlib}/lib:${pkgs.libffi}/lib:${pkgs.pulseaudio}/lib"
      ];
    };

    script = ''
      set -euo pipefail

      # Si existe pero sin pip, rehacer
      if [ -x "${venvPath}/bin/python" ] && ! "${venvPath}/bin/python" -c "import pip" >/dev/null 2>&1; then
        echo "[hotword-venv] venv sin pip; recreando…"
        rm -rf "${venvPath}"
      fi

      if [ ! -x "${venvPath}/bin/python" ]; then
        echo "[hotword-venv] creando venv con virtualenv en ${venvPath}"
        virtualenv -p ${pkgs.python3}/bin/python "${venvPath}"
      fi

      if [ ! -f "${venvPath}/.realtimestt_ok" ]; then
        echo "[hotword-venv] instalando RealtimeSTT + backends"
        "${venvPath}/bin/pip" install --upgrade pip
        # Nota: torch/torchaudio CPU/GPU se ajustan más tarde si quieres CUDA.
        "${venvPath}/bin/pip" install RealtimeSTT openwakeword onnxruntime numpy requests pyaudio
        touch "${venvPath}/.realtimestt_ok"
      fi

      echo "[hotword-venv] descargando modelos OpenWakeWord (opcional)…"
      "${venvPath}/bin/python" - <<'PYCODE'
import os, shutil, pathlib
print("[oww] download_models()…", flush=True)
try:
    import openwakeword
    openwakeword.utils.download_models()
except Exception as e:
    print(f"[oww] WARNING: fallo al descargar modelos OWW: {e}")

home = os.environ.get("HOME") or "/root"
cache = pathlib.Path(home) / ".cache" / "openwakeword"
dst   = pathlib.Path("/etc/openwakeword")
dst.mkdir(parents=True, exist_ok=True)

# Si alguna vez guardas un modelo custom 'tonto.onnx' en la caché, se copiará:
for p in cache.rglob("*.onnx"):
    name = p.name.lower()
    if "tonto" in name and not (dst / "tonto.onnx").exists():
        print(f"[oww] copiando modelo custom: {p}", flush=True)
        shutil.copy2(p, dst / "tonto.onnx")
# No hay jarvis oficial en OWW; no es error si no aparece.
PYCODE

      echo "[hotword-venv] listo."
    '';
  };

  systemd.services.hotword = {
    description = "Hotword Listener (Porcupine 'jarvis' by default; OWW optional)";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" "hotword-venv-setup.service" "sound.target" ];
    wants = [ "network-online.target" "hotword-venv-setup.service" ];

    path = [
      pkgs.coreutils pkgs.bash pkgs.alsa-utils
      pkgs.alsa-plugins pkgs.pulseaudio
      pkgs.stdenv.cc.cc.lib pkgs.zlib pkgs.libffi
    ];

    environment = {
      PULSE_SERVER       = "tcp:192.168.105.1:4713";
      PULSE_SOURCE       = "alsa_input.pci-0000_00_1b.0.analog-stereo";
      USE_PORCUPINE_PIPE = "1";
      WAKEWORDS          = "jarvis,computer,alexa";
      WAKEWORD_SENS      = "0.8";
      WAKEWORD_GAIN      = "1.0";
      ASSISTANT_URL      = "http://localhost:8088/speak";
      WHISPER_MODEL      = "small";
      WHISPER_DEVICE     = "cuda";
      ALSA_PLUGIN_DIR    = "${pkgs.alsa-plugins}/lib/alsa-lib";
      ALSA_CONFIG_PATH   = "/etc/asound.conf";
      LD_LIBRARY_PATH    = "${pkgs.stdenv.cc.cc.lib}/lib:${pkgs.zlib}/lib:${pkgs.libffi}/lib:${pkgs.pulseaudio}/lib";
    };


    serviceConfig = {
      Type = "simple";
      WorkingDirectory = appDir;
      ExecStart = "${venvPath}/bin/python ${appDir}/hotword.py";
      Restart = "on-failure";
      RestartSec = 3;
    };
  };
}
