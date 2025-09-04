{ config, pkgs, lib, ... }:

let
  py = pkgs.python311;
  venvDir = "/var/lib/piper/venv";
  workDir = "/var/lib/piper";

normalizeBin = pkgs.writeShellScriptBin "piper-normalize" ''
  set -euo pipefail
  MODEL_DIR="$1"
  W="$MODEL_DIR/wav"
  mkdir -p "$W"
  shopt -s nullglob
  for f in "$MODEL_DIR"/*.wav "$MODEL_DIR"/*.WAV; do
    [ -e "$f" ] || continue
    mv "$f" "$W/$(basename "$f")"
  done
  TMP="$MODEL_DIR/.tmp_norm"; mkdir -p "$TMP"
  for f in "$W"/*.wav; do
    [ -e "$f" ] || continue
    ffmpeg -v error -y -i "$f" -ac 1 -ar 22050 -sample_fmt s16 "$TMP/$(basename "$f")"
  done
  rm -rf "$W"; mv "$TMP" "$W"
'';

autoMetaBin = pkgs.writeShellScriptBin "piper-auto-metadata" ''
  set -euo pipefail
  MODEL_DIR="$1"; VENV="\${2:-${venvDir}}"
  META="$MODEL_DIR/metadata.csv"; W="$MODEL_DIR/wav"
  [ -d "$W" ] || { echo "No existe $W"; exit 1; }
  if [ -s "$META" ]; then echo "metadata.csv ya existe, omito"; exit 0; fi
  . "$VENV/bin/activate"
  LANG="es"
  if [ -f "$MODEL_DIR/dataset.env" ]; then set -a; . "$MODEL_DIR/dataset.env"; set +a; fi
  : > "$META"
  shopt -s nullglob
  for f in "$W"/*.wav; do
    id="$(basename "\${f%.wav}")"
    text="$(whisper --model small --language "$LANG" --task transcribe --output_format txt "$f" 2>/dev/null \
            | tr -d '\r' | tr '\n' ' ' | sed 's/[[:space:]]\+/ /g; s/^ *//; s/ *$//')"
    echo "\${id}|\${text}" >> "$META"
  done
  echo "Generado $META"
'';

preprocessBin = pkgs.writeShellScriptBin "piper-preprocess" ''
  set -euo pipefail
  MODEL_DIR="$1"; OUT_BASE="\${2:-/var/lib/piper/work}"; VENV="\${3:-${venvDir}}"
  . "$VENV/bin/activate"
  LANG="es-es"; SR=22050; SINGLE="--single-speaker"
  if [ -f "$MODEL_DIR/dataset.env" ]; then set -a; . "$MODEL_DIR/dataset.env"; set +a; fi
  NAME="$(basename "$MODEL_DIR")"; OUT="$OUT_BASE/$NAME"; mkdir -p "$OUT"
  python -m piper_train.preprocess \
    --language "$LANG" --input-dir "$MODEL_DIR" --output-dir "$OUT" \
    --dataset-format ljspeech $SINGLE --sample-rate "$SR"
  echo "Preprocesado -> $OUT"
'';

trainBin = pkgs.writeShellScriptBin "piper-train" ''
  set -euo pipefail
  MODEL_DIR="$1"; OUT_BASE="\${2:-/var/lib/piper/work}"; VENV="\${3:-${venvDir}}"
  . "$VENV/bin/activate"
  NAME="$(basename "$MODEL_DIR")"; DATA_DIR="$OUT_BASE/$NAME"
  CKPT_BASE="/var/lib/piper/checkpoints/base.ckpt"
  BATCH=1; MAXPHN=150; PREC=32; DEV=1; ACCEL="gpu"; VALSPLIT=0.0; TESTN=0; EPOCHS=2000; GACC=16
  if [ -f "$MODEL_DIR/train.env" ]; then set -a; . "$MODEL_DIR/train.env"; set +a; fi
  ARGS=( --dataset-dir "$DATA_DIR" --accelerator "$ACCEL" --devices "$DEV"
         --batch-size "$BATCH" --validation-split "$VALSPLIT" --num-test-examples "$TESTN"
         --max_epochs "$EPOCHS" --checkpoint-epochs 1 --precision "$PREC"
         --max-phoneme-ids "$MAXPHN" --gradient-accumulation-steps "$GACC" )
  [ -f "$CKPT_BASE" ] && ARGS+=( --resume_from_checkpoint "$CKPT_BASE" )
  python -m piper_train "''${ARGS[@]}"
'';

exportBin = pkgs.writeShellScriptBin "piper-export" ''
  set -euo pipefail
  MODEL_DIR="$1"; OUT_BASE="\${2:-/var/lib/piper/work}"; VENV="\${3:-${venvDir}}"
  . "$VENV/bin/activate"
  NAME="$(basename "$MODEL_DIR")"; LOGDIR="$OUT_BASE/$NAME/lightning_logs"
  CKPT="$(ls -1 "$LOGDIR"/version_*/checkpoints/*.ckpt 2>/dev/null | tail -n1 || true)"
  [ -n "$CKPT" ] || { echo "Sin checkpoint para $NAME"; exit 1; }
  OUT_ONNX="$MODEL_DIR/\${NAME}.onnx"
  python -m piper_train.export_onnx "$CKPT" "$OUT_ONNX" && \
    cp "$OUT_BASE/$NAME/config.json" "$OUT_ONNX.json" || true
  if command -v onnxsim >/dev/null 2>&1; then
    python -m onnxsim "$OUT_ONNX" "$OUT_ONNX" || true
  fi
  echo "Exportado -> $OUT_ONNX (+ .json)"
'';

pipelineBin = pkgs.writeShellScriptBin "piper-pipeline" ''
  set -euo pipefail
  MODEL_DIR="$1"
  ${normalizeBin}/bin/piper-normalize "$MODEL_DIR"
  if [ "''${ENABLE_WHISPER:-1}" = "1" ]; then
    ${autoMetaBin}/bin/piper-auto-metadata "$MODEL_DIR" "${venvDir}"
  else
    echo "AUTO-WHISPER OFF: asegúrate de tener metadata.csv"
  fi
  ${preprocessBin}/bin/piper-preprocess "$MODEL_DIR" "/var/lib/piper/work" "${venvDir}"
  ${trainBin}/bin/piper-train "$MODEL_DIR" "/var/lib/piper/work" "${venvDir}"
  ${exportBin}/bin/piper-export "$MODEL_DIR" "/var/lib/piper/work" "${venvDir}"
'';

in
{
  system.stateVersion = "24.05";
  nixpkgs.config.allowUnfree = true;

  networking.hostName = "piper-train";
  time.timeZone = "Europe/Madrid";

  environment.systemPackages = with pkgs; [
    git wget curl unzip gnumake cmake pkg-config
    ffmpeg sox espeak-ng inotify-tools
    python311Full python311Packages.pip python311Packages.setuptools python311Packages.wheel
    nano vim tree jq
    normalizeBin autoMetaBin preprocessBin trainBin exportBin pipelineBin
  ];

  environment.variables = {
    LD_LIBRARY_PATH = lib.mkForce "/run/opengl-driver/lib:/run/opengl-driver-32/lib";
    NUMBA_CACHE_DIR = "${workDir}/.numba_cache";
    ENABLE_WHISPER = "1"; # auto-transcribir (1=on, 0=off)
  };

  users.users.piper = {
    isSystemUser = true;
    home = workDir;
    createHome = false;
    group = "piper";
  };
  users.groups.piper = {};

  systemd.tmpfiles.rules = [
    "d ${workDir} 0755 root root - -"
    "d ${workDir}/work 0755 root root - -"
    "d ${workDir}/checkpoints 0755 root root - -"
    "d ${workDir}/output 0755 root root - -"
    "d ${workDir}/scripts 0755 root root - -"
    "d ${workDir}/.cache 0755 piper piper - -"
    "d ${workDir}/.numba_cache 0755 piper piper - -"
    "d ${venvDir} 0755 piper piper - -"
  ];

  # Venv + dependencias (Torch CUDA por pip, Whisper, Piper en modo editable)
  systemd.services.piper-venv-setup = {
    description = "Prepare venv for Piper (install deps)";
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      User = "piper";
      Group = "piper";
      WorkingDirectory = workDir;
      Environment = [
        "LD_LIBRARY_PATH=/run/opengl-driver/lib:/run/opengl-driver-32/lib"
        "NUMBA_CACHE_DIR=${workDir}/.numba_cache"
      ];
      ExecStart = pkgs.writeShellScript "piper-setup.sh" ''
        set -euo pipefail
        if [ ! -d "${venvDir}/bin" ]; then
          ${py}/bin/python3 -m venv "${venvDir}"
        fi
        . "${venvDir}/bin/activate"
        pip install --upgrade pip setuptools wheel
        # Torch + CUDA runtime por pip (cu121 funciona bien en la mayoría de drivers recientes)
        pip install --index-url https://download.pytorch.org/whl/cu121 torch torchvision torchaudio
        pip install "pytorch-lightning<2.4" onnx onnxsim piper-phonemize openai-whisper

        if [ ! -d "${workDir}/piper" ]; then
          git clone https://github.com/rhasspy/piper.git "${workDir}/piper"
        fi
        cd "${workDir}/piper/src/python"
        pip install -e .
        bash build_monotonic_align.sh || true

        python - <<'PY'
import torch
print("Torch:", torch.__version__, "CUDA available:", torch.cuda.is_available())
PY
        echo "venv listo."
      '';
    };
  };

  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 6006 ];
  };

  systemd.services.piper-tensorboard = {
    description = "TensorBoard for Piper training";
    wants = [ "network-online.target" ];
    after = [ "network-online.target" "piper-venv-setup.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      User = "piper";
      Group = "piper";
      WorkingDirectory = workDir;
      ExecStart = "${venvDir}/bin/tensorboard --logdir ${workDir}/work/lightning_logs --bind_all --port 6006";
      Restart = "on-failure";
      RestartSec = 5;
      Environment = [
        "NUMBA_CACHE_DIR=${workDir}/.numba_cache"
        "LD_LIBRARY_PATH=/run/opengl-driver/lib:/run/opengl-driver-32/lib"
      ];
    };
  };

  programs.bash.enableCompletion = true;

  # --------- Automatización plug & play ----------
  # Servicio por modelo (pipeline completo)
  systemd.services."piper-pipeline@" = {
    description = "Piper pipeline for %i";
    after = [ "piper-venv-setup.service" ];
    serviceConfig = {
      User = "piper";
      Group = "piper";
      WorkingDirectory = workDir;
      Environment = [
        "LD_LIBRARY_PATH=/run/opengl-driver/lib:/run/opengl-driver-32/lib"
        "NUMBA_CACHE_DIR=${workDir}/.numba_cache"
      ];
      ExecStart = "${pipelineBin}/bin/piper-pipeline /var/lib/piper/models/%i";
      Restart = "on-failure";
      RestartSec = 10;
    };
  };

  # Path unit: dispara cuando hay cambios en el modelo
  systemd.paths."piper-pipeline@" = {
    description = "Watch model dir for %i";
    wantedBy = [ "multi-user.target" ];
    pathConfig = {
      PathChanged = [
        "/var/lib/piper/models/%i"
        "/var/lib/piper/models/%i/wav"
        "/var/lib/piper/models/%i/metadata.csv"
      ];
      Unit = "piper-pipeline@%i.service";
    };
  };
}
