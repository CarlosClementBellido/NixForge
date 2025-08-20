{ config, pkgs, lib, ... }:

let
  venvPath  = "/var/lib/tonto/venv";
  appDir    = "/etc/tonto";

  piperModelFile = pkgs.fetchurl {
    url = "https://huggingface.co/rhasspy/piper-voices/resolve/main/es/es_ES/carlfm/x_low/es_ES-carlfm-x_low.onnx";
    sha256 = "09fi0066br0mk4rxyr1ygzx6npcbm4h9rcj27ybd8z4h78r7g5nn";
  };
  piperModelMeta = pkgs.fetchurl {
    url = "https://huggingface.co/rhasspy/piper-voices/resolve/main/es/es_ES/carlfm/x_low/es_ES-carlfm-x_low.onnx.json";
    sha256 = "0rlr7499slri4ybmzxvwxgcc9r6i74wmklp7cagbrchyy2gzmgfr";
  };

  pythonEnv = pkgs.python3.withPackages (ps: [
    ps.fastapi ps.uvicorn ps.pydantic ps.requests ps.google-auth ps.grpcio ps.protobuf
  ]);
in
{
  imports = [
    ./hotword.nix
  ];

  networking.useHostResolvConf = true;

  networking.hostName = "tonto";
  systemd.network.wait-online.enable = true;
  networking.defaultGateway = "192.168.105.1";
  #networking.resolvconf.enable = false;

  networking.firewall.enable = true;
  networking.firewall.allowedTCPPorts = [ 8088 ];


  environment.systemPackages = with pkgs; [
    pythonEnv cacert curl jq
    piper-tts pulseaudio alsa-utils espeak-ng
    coreutils findutils gnugrep gnused bash
  ];

  environment.etc."tonto/app.py".text = builtins.readFile ./app.py;

  environment.etc."piper/models/es_ES-carlfm-x_low.onnx".source = piperModelFile;
  environment.etc."piper/models/es_ES-carlfm-x_low.onnx.json".source = piperModelMeta;

  environment.etc."pulse/client.conf".text = ''
    default-server = tcp:192.168.105.1:4713
    autospawn = no
  '';

  systemd.services.tonto-venv-setup = {
    description = "Prepare venv for Tonto (no network)";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    path = [ pythonEnv pkgs.coreutils pkgs.bash ];
    serviceConfig = { Type = "oneshot"; RemainAfterExit = true; };
    script = ''
      set -euo pipefail
      if [ ! -x "${venvPath}/bin/python" ]; then
        ${pythonEnv}/bin/python -m venv "${venvPath}"
        ln -sf ${pythonEnv}/bin/* "${venvPath}/bin/" || true
      fi
      echo "[tonto-venv] OK (sin pip)"
    '';
  };

  systemd.services.tonto = {
    description = "Tonto (Gemini via Vertex AI + Piper TTS) FastAPI";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" "tonto-venv-setup.service" ];
    wants = [ "network-online.target" "tonto-venv-setup.service" ];

    path = with pkgs; [ piper-tts pulseaudio alsa-utils coreutils ];

    serviceConfig = {
      Type = "simple";
      WorkingDirectory = appDir;

      Environment = [
        "GOOGLE_APPLICATION_CREDENTIALS=/etc/secrets/gcp-sa.json"
        "GCP_LOCATION=europe-southwest1"
        "GEMINI_MODEL=gemini-2.0-flash"
        "PYTHONUNBUFFERED=1"

        "PIPER_MODEL=/etc/piper/models/es_ES-carlfm-x_low.onnx"
        "PIPER_BIN=/run/current-system/sw/bin/piper"
        "PREFER_PIPER=true"

        "PULSE_SERVER=tcp:192.168.105.1:4713"
      ];

      ExecStartPre = [
        "${pkgs.coreutils}/bin/test -r /etc/secrets/gcp-sa.json"
        "${pkgs.coreutils}/bin/test -x ${venvPath}/bin/uvicorn"
        "${pkgs.coreutils}/bin/test -x /run/current-system/sw/bin/piper"
        "${pkgs.coreutils}/bin/test -r /etc/piper/models/es_ES-carlfm-x_low.onnx"
      ];

      ExecStart = "${venvPath}/bin/uvicorn app:app --host 0.0.0.0 --port 8088 --timeout_keep_alive 120";
      Restart = "on-failure";
    };
  };

  system.stateVersion = "24.05";
}