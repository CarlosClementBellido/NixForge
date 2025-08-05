{ config, pkgs, lib, ... }:

{
  # Instala las utilidades necesarias
  environment.systemPackages = with pkgs; [
    bash coreutils procps gawk iproute2 lm_sensors gnugrep bc
  ];

  # Directorio donde se escribe el JSON
  systemd.tmpfiles.rules = [
    "d /var/lib/metrics 0755 root root"
  ];

  # Servicio que genera métricas cada 3s
  systemd.services.generate-metrics = {
    description = "Generador de métricas del sistema para el dashboard";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.bash}/bin/bash /etc/nixos/nixforge/containers/dashboard/site/generate_metrics.sh";
      Restart = "always";
      RestartSec = 5;
    };
  };
}
