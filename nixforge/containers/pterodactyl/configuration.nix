{ config, pkgs, lib, ... }:

let
  myPhp = pkgs.php.buildEnv {
    extensions = ({ enabled, all }: enabled ++ (with all; [ pdo pdo_mysql redis dom tokenizer zip bcmath intl ]));
  };
  nodejs = pkgs.nodejs_18;
  pteroDomain = "pterodactyl.server.clementbellido.es";
  webRoot     = "/var/www/pterodactyl";
  phpSock     = "/run/phpfpm-pterodactyl.sock";
  pteroInitSQL = pkgs.writeText "ptero-init.sql" ''
    CREATE DATABASE IF NOT EXISTS pterodactyl CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
    CREATE USER IF NOT EXISTS 'ptero'@'127.0.0.1' IDENTIFIED BY 'changeme';
    GRANT ALL PRIVILEGES ON pterodactyl.* TO 'ptero'@'127.0.0.1' WITH GRANT OPTION;
    FLUSH PRIVILEGES;
  '';

  runcWrapped = pkgs.writeShellScriptBin "runc-wrapped" ''
    #!/bin/sh
    subcmd="$1"
    case "$subcmd" in
      create|run|exec)
        exec ${pkgs.runc}/bin/runc --no-new-keyring "$@"
        ;;
      *)
        exec ${pkgs.runc}/bin/runc "$@"
        ;;
    esac
  '';
in
{
  environment.systemPackages = [
    pkgs.git pkgs.curl pkgs.wget pkgs.unzip pkgs.bash pkgs.coreutils pkgs.shadow pkgs.iptables 
    pkgs.gnutar pkgs.gnugrep pkgs.gnused pkgs.gzip
    pkgs.mariadb pkgs.redis
    nodejs pkgs.yarn
    myPhp pkgs.phpPackages.composer
    pkgs.nginx pkgs.iproute2 pkgs.docker
  ];

  # Como montamos /etc/resolv.conf desde el host, que resolvconf no toque nada.
  networking.resolvconf.enable = false;

  services.mysql = {
    enable = true;
    package = pkgs.mariadb;
    settings.mysqld = { bind-address = "127.0.0.1"; skip-networking = false; };
    initialScript = pteroInitSQL;
  };

  services.redis.servers."".enable = true;
  services.redis.servers."".bind   = "127.0.0.1";
  services.redis.servers."".port   = 6379;

  services.nginx = {
    enable = true;
    virtualHosts."_" = {
      default = true;
      root = "${webRoot}/public";
      listen = [{ addr = "0.0.0.0"; port = 8081; }];
      extraConfig = ''
        index index.php;
        access_log /var/log/nginx/pterodactyl.access.log;
        error_log  /var/log/nginx/pterodactyl.error.log error;
        client_max_body_size 100m;
        client_body_timeout 120s;
        sendfile off;
      '';
      locations."/" = { tryFiles = "$uri $uri/ /index.php?$query_string"; };
      locations."~ \\.php$" = {
        extraConfig = ''
          fastcgi_split_path_info ^(.+\.php)(/.+)$;
          fastcgi_pass unix:${phpSock};
          fastcgi_index index.php;
          include ${pkgs.nginx}/conf/fastcgi_params;
          fastcgi_param PHP_VALUE "upload_max_filesize = 100M \n post_max_size=100M";
          fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
          fastcgi_param HTTP_PROXY "";
          fastcgi_intercept_errors off;
          fastcgi_buffer_size 16k;
          fastcgi_buffers 4 16k;
          fastcgi_connect_timeout 300;
          fastcgi_send_timeout 300;
          fastcgi_read_timeout 300;
        '';
      };
      locations."~ /\\." = { extraConfig = "deny all;"; };
    };
  };

  services.phpfpm.pools.pterodactyl = {
    user = "nginx";
    group = "nginx";
    phpPackage = myPhp;
    settings = {
      "listen" = phpSock;
      "listen.owner" = "nginx";
      "listen.group" = "nginx";
      "pm" = "dynamic";
      "pm.max_children" = 32;
      "pm.start_servers" = 2;
      "pm.min_spare_servers" = 1;
      "pm.max_spare_servers" = 5;
    };
  };

  systemd.services.ptero-bootstrap = {
    description = "Bootstrap de Pterodactyl (idempotente)";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" "mysql.service" "redis.service" "phpfpm-pterodactyl.service" "nginx.service" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      Environment = [
        "NODE_OPTIONS=--openssl-legacy-provider"
        "HOME=/root"
        "COMPOSER_HOME=/root/.composer"
        "PATH=${webRoot}/node_modules/.bin:/run/current-system/sw/bin"
      ];
      WorkingDirectory = webRoot;
    };
    path = [ pkgs.git pkgs.curl pkgs.gnutar pkgs.coreutils pkgs.gnused pkgs.gnugrep nodejs pkgs.yarn myPhp pkgs.phpPackages.composer pkgs.mariadb ];
    script = ''
      set -euo pipefail
      WEBROOT="${webRoot}"
      if [ ! -d "$WEBROOT" ]; then
        echo "[ptero] Clonando panel…"
        mkdir -p "$(dirname "$WEBROOT")"
        ${pkgs.git}/bin/git clone --depth=1 https://github.com/pterodactyl/panel.git "$WEBROOT"
        cd "$WEBROOT"
        echo "[ptero] Composer (prod)…"
        cp .env.example .env
        ${pkgs.phpPackages.composer}/bin/composer install --no-dev --optimize-autoloader
        echo "[ptero] Config .env…"
        ${myPhp}/bin/php artisan key:generate
        ${myPhp}/bin/php artisan p:environment:setup \
          --author="carlos.clement.bellido@gmail.com" \
          --url="https://${pteroDomain}" \
          --timezone="Europe/Madrid" \
          --cache="redis" --session="redis" --queue="redis"
        ${myPhp}/bin/php artisan p:environment:database \
          --host=127.0.0.1 --port=3306 \
          --database=pterodactyl --username=ptero --password=changeme
        ${myPhp}/bin/php artisan p:environment:mail --driver=log
        sed -i '/^APP_URL=/d' .env
        echo "APP_URL=https://${pteroDomain}" >> .env
        if ! grep -q '^TRUSTED_PROXIES=' .env; then
          echo "TRUSTED_PROXIES=127.0.0.1,192.168.104.1" >> .env
        fi
        echo "[ptero] Migraciones + seed…"
        ${myPhp}/bin/php artisan migrate --seed --force
      else
        echo "[ptero] Repo ya presente; comprobando vendor…"
        cd "$WEBROOT"
        if [ ! -d vendor ]; then
          ${pkgs.phpPackages.composer}/bin/composer install --no-dev --optimize-autoloader
        fi
      fi
      echo "[ptero] Build frontend…"
      ( ${pkgs.yarn}/bin/yarn install --frozen-lockfile || ${pkgs.yarn}/bin/yarn install )
      ${pkgs.yarn}/bin/yarn run build:production
      ls public/assets/bundle.*.js >/dev/null 2>&1 || { echo "No se generaron assets"; exit 1; }
      echo "[ptero] Permisos y cachés…"
      chown -R nginx:nginx "$WEBROOT"
      chmod -R 755 "$WEBROOT"/storage/* "$WEBROOT"/bootstrap/cache/ || true
      ${myPhp}/bin/php artisan view:clear  || true
      ${myPhp}/bin/php artisan route:clear || true
      ${myPhp}/bin/php artisan config:clear || true
      ${myPhp}/bin/php artisan config:cache
      echo "[ptero] Bootstrap OK."
    '';
  };

  systemd.services.pteroq = {
    description = "Pterodactyl Queue Worker";
    after = [ "redis.service" ];
    wantedBy = [ "multi-user.target" ];
    # Estas dos opciones deben ir en [Unit]
    unitConfig = {
      StartLimitIntervalSec = 180;
      StartLimitBurst = 30;
    };
    serviceConfig = {
      User = "nginx";
      Group = "nginx";
      Restart = "always";
      ExecStart = "${myPhp}/bin/php ${webRoot}/artisan queue:work --queue=high,standard,low --sleep=3 --tries=3 -vvv";
      RestartSec = 5;
      WorkingDirectory = webRoot;
      StandardOutput = "journal";
      StandardError  = "journal";
      Environment = "QUEUE_CONNECTION=redis";
    };
  };

  systemd.services.ptero-schedule = {
    description = "Run Laravel scheduler for Pterodactyl";
    serviceConfig = {
      Type = "oneshot";
      User = "nginx";
      Group = "nginx";
      ExecStart = "${myPhp}/bin/php ${webRoot}/artisan schedule:run";
      WorkingDirectory = webRoot;
    };
  };
  systemd.timers.ptero-schedule = {
    wantedBy = [ "timers.target" ];
    timerConfig = { OnCalendar = "*:0/1"; Persistent = true; };
  };

  # Docker dentro del contenedor
  virtualisation.docker.enable = true;
  virtualisation.docker.autoPrune.enable = true;

  systemd.services.docker.serviceConfig.CapabilityBoundingSet = [
    "CAP_CHOWN"
    "CAP_DAC_OVERRIDE"
    "CAP_DAC_READ_SEARCH"
    "CAP_FOWNER"
    "CAP_FSETID"
    "CAP_KILL"
    "CAP_SETGID"
    "CAP_SETUID"
    "CAP_SETPCAP"
    "CAP_LINUX_IMMUTABLE"
    "CAP_NET_BIND_SERVICE"
    "CAP_NET_BROADCAST"
    "CAP_NET_ADMIN"
    "CAP_NET_RAW"
    "CAP_IPC_OWNER"
    "CAP_SYS_CHROOT"
    "CAP_SYS_PTRACE"
    "CAP_SYS_ADMIN"
    "CAP_SYS_BOOT"
    "CAP_SYS_NICE"
    "CAP_SYS_RESOURCE"
    "CAP_SYS_TTY_CONFIG"
    "CAP_MKNOD"
    "CAP_LEASE"
    "CAP_AUDIT_WRITE"
    "CAP_AUDIT_CONTROL"
    "CAP_SETFCAP"
  ];

  systemd.services.docker.serviceConfig = {
    NoNewPrivileges = false;
    SystemCallFilter = "";
    AmbientCapabilities = [ "CAP_NET_ADMIN" "CAP_NET_RAW" "CAP_SYS_ADMIN" ];
    PrivateUsers = false;
    ProtectKernelTunables = false;
    ProtectKernelModules = false;
    ProtectControlGroups = false;
    RestrictNamespaces = "";
    KeyringMode = "inherit";
  };

  boot.kernelModules = [ "br_netfilter" ];
  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 1;
    "net.bridge.bridge-nf-call-iptables"  = 1;
    "net.bridge.bridge-nf-call-ip6tables" = 1;
  };

  networking.firewall.enable = true;
  networking.firewall.allowedTCPPorts = [ 8080 8081 2022 25565 ];
  networking.firewall.allowedUDPPorts = [ 25565 ];

  users.groups.wings = { };
  users.users.wings = {
    isSystemUser = true;
    group = "wings";
    home = "/var/lib/pterodactyl";
    createHome = true;
    extraGroups = [ "docker" ];
  };
  environment.etc."usr/sbin/nologin".source = "${pkgs.shadow}/bin/nologin";

  users.users.pterodactyl = {
    isSystemUser = true;
    home = "/var/lib/pterodactyl";
    createHome = false;
    group = "wings";
    shell = "${pkgs.shadow}/bin/nologin";
  };

  systemd.tmpfiles.rules = [
    "d /var/lib/pterodactyl 0750 wings wings - -"
    "d /var/lib/pterodactyl/logs 0750 wings wings - -"
    "d /etc/pterodactyl 0755 root root - -"
    "d /var/log/pterodactyl 0750 wings wings - -"
  ];

  systemd.services."wings-download" = {
    description = "Fetch Wings binary if missing";
    wantedBy = [ "multi-user.target" ];
    serviceConfig.Type = "oneshot";
    script = ''
      set -euo pipefail
      dst="/var/lib/pterodactyl/wings"
      if [ ! -x "$dst" ]; then
        ${pkgs.curl}/bin/curl -fL --retry 3 \
          -o "$dst" \
          https://github.com/pterodactyl/wings/releases/latest/download/wings_linux_amd64
        chmod +x "$dst"
        chown wings:wings "$dst"
      fi
    '';
  };

  systemd.services.wings = {
    description = "Pterodactyl Wings";
    after = [ "network-online.target" "docker.service" "wings-download.service" ];
    wants = [ "network-online.target" "docker.service" ];
    wantedBy = [ "multi-user.target" ];
    unitConfig.ConditionPathExists = "/etc/pterodactyl/config.yml";
    path = with pkgs; [ shadow coreutils iproute2 iptables e2fsprogs ];
    serviceConfig = {
      User = "root";
      Group = "root";
      KeyringMode = "inherit";
      SystemCallFilter = "";
      NoNewPrivileges = false;
      WorkingDirectory = "/var/lib/pterodactyl";
      ExecStart = "/var/lib/pterodactyl/wings --config /etc/pterodactyl/config.yml";
      Restart = "always";
      RestartSec = 5;
      LimitNOFILE = 1048576;
      TimeoutStartSec = 120;
      StandardOutput = "journal";
      StandardError  = "journal";
      Environment="TZ=Europe/Madrid";
    };
  };

  virtualisation.docker.daemon.settings = {
    storage-driver = "vfs";
    exec-opts = [ "native.cgroupdriver=systemd" ];
  };

  system.stateVersion = "24.05";
}
