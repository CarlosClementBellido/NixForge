{ config, pkgs, lib, ... }:

let
  venvPath  = "/var/lib/tonto/venv";
  appDir    = "/etc/tonto";
  pythonEnv = pkgs.python3.withPackages (ps: [
    ps.fastapi ps.uvicorn ps.pydantic ps.pip
  ]);
in
{
  networking.hostName = "tonto";
  systemd.network.wait-online.enable = true;
  networking.defaultGateway = "192.168.105.1";

  # DNS estable
  networking.resolvconf.enable = false;

  networking.firewall.enable = true;
  networking.firewall.allowedTCPPorts = [ 8088 ];

  environment.systemPackages = with pkgs; [ pythonEnv cacert curl jq ];
  environment.etc."tonto/app.py".text = builtins.readFile ./app.py;

  systemd.tmpfiles.rules = [
    "d /etc/secrets 0755 root root -"
    "d /var/lib/tonto 0755 root root -"
  ];

  # 1) Preparar el venv en un oneshot con 'script'
  systemd.services.tonto-venv-setup = {
    description = "Prepare venv for Tonto (install deps)";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];

    # Herramientas que estarán en PATH del script
    path = [ pythonEnv pkgs.coreutils pkgs.findutils pkgs.gnugrep pkgs.bash ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };

    script = ''
      set -euo pipefail

      # crea venv si no existe
      if [ ! -x "${venvPath}/bin/python" ]; then
        echo "[tonto-venv] creando venv en ${venvPath}"
        ${pythonEnv}/bin/python -m venv "${venvPath}"
      fi

      echo "[tonto-venv] OK"
    '';
  };

  # 2) Servicio FastAPI
  systemd.services.tonto = {
    description = "Tonto (Gemini via Vertex AI + SA) FastAPI";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" "tonto-venv-setup.service" ];
    wants = [ "network-online.target" "tonto-venv-setup.service" ];

    serviceConfig = {
      Type = "simple";
      WorkingDirectory = appDir;
      Environment = [
        # Si no lo defines, app.py lo leerá del JSON:
        # "GCP_PROJECT_ID=TU_PROJECT_ID"
        "GCP_LOCATION=global"
        "GOOGLE_APPLICATION_CREDENTIALS=/etc/secrets/gcp-sa.json"
        "PYTHONUNBUFFERED=1"
      ];

      # Comprobaciones rápidas
      ExecStartPre = [
        "${pkgs.coreutils}/bin/test -r /etc/secrets/gcp-sa.json"
        "${pkgs.coreutils}/bin/test -x ${venvPath}/bin/uvicorn"
      ];

      ExecStart = "${venvPath}/bin/uvicorn app:app --host 0.0.0.0 --port 8088";
      Restart = "on-failure";
    };
  };

  systemd.services.tonto-pip = {
    description = "Install/upgrade Python deps (deferred)";
    after = [ "network-online.target" "tonto.service" ];
    wants = [ "network-online.target" ];
    serviceConfig = { Type = "oneshot"; WorkingDirectory = "/"; };
    path = [ pythonEnv pkgs.cacert ];
    script = ''
      set -euo pipefail
      "${venvPath}/bin/pip" install --no-cache-dir --upgrade pip wheel setuptools
      "${venvPath}/bin/pip" install --no-cache-dir google-genai fastapi uvicorn
    '';
  };

  systemd.timers.tonto-pip = {
    wantedBy = [ "timers.target" ];
    timerConfig = { OnBootSec = "1min"; Persistent = true; };
  };

  system.stateVersion = "24.05";
}
