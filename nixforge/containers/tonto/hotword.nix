{ config, pkgs, lib, ... }:

let
  appDir    = "/etc/tonto";
  venvDir   = "/var/lib/tonto/hotword-venv";
  modelsDir = "/var/lib/tonto/models";   # cache HF/Whisper
  owwCache  = "/var/lib/tonto/oww";      # cache OWW

  py = pkgs.python3;

  runtimeTools = with pkgs; [
    bash coreutils findutils gnugrep gnused curl which
    pulseaudio alsa-utils libsndfile glibc
  ];

  runtimeLibs = with pkgs; [
    zlib                 # libz.so.1
    stdenv.cc.cc.lib     # libstdc++.so.6
    libsndfile           # libsndfile.so.*
  ];

  venvSetupScript = pkgs.writeShellScript "tonto-hotword-venv-setup.sh" ''
    set -euo pipefail
    VENV="${venvDir}"

    echo "[venv] creando/actualizando entorno en $VENV"
    if [ ! -x "$VENV/bin/python" ]; then
      "${py}/bin/python" -m venv "$VENV"
    fi

    export SSL_CERT_FILE="${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
    export PIP_INDEX_URL="https://pypi.org/simple"
    export PIP_DEFAULT_TIMEOUT=60
    export PIP_RETRIES=5

    "$VENV/bin/python" -m pip install --upgrade pip wheel setuptools

    echo "[venv] instalando numpy<2.0 …"
    "$VENV/bin/pip" install --no-cache-dir --prefer-binary "numpy<2.0"

    base_pkgs="soundfile tqdm scipy resampy requests faster-whisper"
    for p in $base_pkgs; do
      echo "[venv] instalando $p …"
      "$VENV/bin/pip" install --no-cache-dir --prefer-binary "$p"
    done

    echo "[venv] instalando openwakeword==0.4.0 …"
    "$VENV/bin/pip" install --no-cache-dir --prefer-binary "openwakeword==0.4.0"

    echo "[venv] instalando (opcional) webrtcvad …"
    if ! "$VENV/bin/pip" install --no-cache-dir --prefer-binary webrtcvad; then
      echo "[venv] WARNING: webrtcvad no disponible (seguimos sin VAD)"
    fi

    set +e
    TFL_OK=0
    for ver in 2.14.0 2.12.0; do
      echo "[venv] intentando tflite-runtime==$ver …"
      if "$VENV/bin/pip" install --no-cache-dir --prefer-binary "tflite-runtime==$ver"; then
        TFL_OK=1; break
      fi
    done
    set -e
    if [ "$TFL_OK" != "1" ]; then
      echo "[venv] WARNING: no se pudo instalar tflite-runtime; OWW puede no funcionar."
    fi

    mkdir -p "${owwCache}" "${modelsDir}"
    echo "[venv] listo."
  '';
in
{
  # Unfree (NVIDIA/CUDA, etc.)
  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = runtimeTools;

  # Coloca tu script en el sistema leyendo tu fichero local:
  # (ajusta la ruta si no está junto a este .nix)
  environment.etc."tonto/hotword.py".text = builtins.readFile ./hotword.py;

  # Directorios de estado
  systemd.tmpfiles.rules = [
    "d ${modelsDir} 0755 root root - -"
    "d ${owwCache}  0755 root root - -"
    "d ${venvDir}   0755 root root - -"
  ];

  # VENV (pip)
  systemd.services."tonto-hotword-venv" = {
    description = "Preparar venv para Tonto Hotword (OWW 0.4 + Whisper)";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];

    path = runtimeTools ++ [ pkgs.gcc pkgs.pkg-config pkgs.which ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;

      ExecStartPre = "${pkgs.curl}/bin/curl -sSfI --connect-timeout 10 https://pypi.org/simple/";
      ExecStart = venvSetupScript;

      Environment = [
        "OPENWAKEWORD_CACHE_DIR=${owwCache}"
        "XDG_CACHE_HOME=${owwCache}"
        "PIP_INDEX_URL=https://pypi.org/simple"
        "PIP_DEFAULT_TIMEOUT=60"
        "PIP_RETRIES=5"
        "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
        "LD_LIBRARY_PATH=${lib.makeLibraryPath runtimeLibs}"
        "CC=${pkgs.gcc}/bin/gcc"
      ];
    };
  };

  # Servicio principal
  systemd.services."tonto-hotword" = {
    description = "Tonto Hotword + ASR (Whisper) con VAD; fallback si OWW no está";
    wantedBy = [ "multi-user.target" ];
    after  = [ "network-online.target" "tonto-hotword-venv.service" ];
    wants  = [ "network-online.target" "tonto-hotword-venv.service" ];

    path = runtimeTools;

    serviceConfig = {
      Type = "simple";
      WorkingDirectory = appDir;
      ExecStart = "${venvDir}/bin/python ${appDir}/hotword.py";
      Restart = "always";
      RestartSec = "2s";

      Environment = [
        # Hotwords / sensibilidad
        "HOTWORDS=tonto,oye tonto,ok tonto"
        "WAKE_SENSITIVITY=0.55"

        # VAD / ventanas
        "VAD_AGGRESSIVENESS=1"
        "SILENCE_TIMEOUT=0.8"
        "MAX_LISTEN_SECONDS=7"
        "MIN_SPEECH_MS=350"
        "COOLDOWN_AFTER_TRIGGER=2"
        "COOLDOWN_AFTER_EMPTY=1"

        # Whisper / caché
        "ASR_MODEL=tiny"
        "ASR_LANGUAGE=es"
        "HF_HOME=${modelsDir}"

        # Intenta CUDA; el Python hace fallback a CPU si falla
        "FW_DEVICE=cuda"
        "FW_COMPUTE_TYPE=int8_float16"

        # OWW 0.4 por defecto (TFLite embebido en la wheel)
        "OWW_BACKEND=tflite"
        "OWW_ALLOW="
        "OPENWAKEWORD_CACHE_DIR=${owwCache}"
        "XDG_CACHE_HOME=${owwCache}"
        "TFLITE_DISABLE_XNNPACK=1"

        # Audio
        "PULSE_SERVER=tcp:192.168.105.1:4713"

        # Tu endpoint; cambia a TONTO_FIELD=text si tu API lo espera así
        "TONTO_URL=http://127.0.0.1:8088/speak"
        "TONTO_FIELD=question"

        # Bibliotecas nativas necesarias (CUDA + libz/libstdc++/libsndfile)
        "LD_LIBRARY_PATH=/run/opengl-driver/lib:${lib.makeLibraryPath runtimeLibs}"
      ];
    };
  };
}
