{ config, pkgs, lib, ... }:


let
  credentials = builtins.fromJSON (builtins.readFile ../torrent/transmission.cred);
in
{
  systemd.services.transmission = {
    description = "Transmission BitTorrent Service";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    serviceConfig = {
      ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p /var/lib/transmission/.config/transmission-daemon";
      ExecStart = "${pkgs.transmission}/bin/transmission-daemon -f --log-info --config-dir /etc/transmission-daemon";
      Restart = "on-failure";
      User = "root";

      ProtectSystem = "no";
      ProtectHome = "no";
      PrivateTmp = false;
      ReadWritePaths = [ "/" ];
    };
  };

  networking.firewall.enable = true;
  networking.firewall.allowedTCPPorts = [ 9091 51413 8080 ];
  networking.firewall.allowedUDPPorts = [ 51413 ];
  networking.nameservers = [ "1.1.1.1" "8.8.8.8" ];

  # settings.json correcto desde el inicio
  environment.etc."transmission-daemon/settings.json".text = builtins.toJSON {
    "download-dir" = "/var/media/videos";
    "rpc-bind-address" = "0.0.0.0";
    "rpc-enabled" = true;
    "rpc-username" = credentials."rpc-username";
    "rpc-password" = credentials."rpc-password";
    "rpc-port" = 9091;
    "rpc-whitelist-enabled" = false;
    "rpc-authentication-required" = true;
    "peer-port" = 51413;
    "port-forwarding-enabled" = true;
    "dht-enabled" = true;
    "pex-enabled" = true;
    "lpd-enabled" = true;
  };

  environment.etc."transmission-daemon/settings.json".mode = "0644";

  environment.etc."transmission-daemon/settings.json".user = "root";

  environment.etc."transmission-daemon/settings.json".group = "root";

  environment.etc."transmission-daemon/settings.json".target = "transmission-daemon/settings.json";

  environment.etc."nginx/webdav.htpasswd".text = ''
    clement:$apr1$/yPsvsMj$eCbKYfGFk2A84JMFQH9/20
  '';

  services.nginx = {
    enable = true;

    # Vhost mínimo: listado de ficheros en /var/media/videos
    virtualHosts."_webdav_test" = {
      listen = [{ addr = "0.0.0.0"; port = 8080; }];
      serverName = "_";
      # Pon el root en la location (más seguro)
      locations."/" = {
        root = "/var/media/videos";
        extraConfig = ''
          # Necesario para clientes WebDAV de Android / Windows
          add_header DAV "1,2";
          add_header Allow "OPTIONS, GET, HEAD, PUT, DELETE, MKCOL, PROPFIND, COPY, MOVE";
          add_header MS-Author-Via "DAV";

          location / {
            client_max_body_size 0;
            client_body_temp_path /tmp/webdav;

            dav_methods PUT DELETE MKCOL COPY MOVE;
            dav_ext_methods PROPFIND OPTIONS;
            dav_access user:rw group:rw all:r;
            create_full_put_path on;
            autoindex on;
            autoindex_exact_size off;
            autoindex_localtime on;

            # Autenticación básica
            auth_basic "Restricted";
            auth_basic_user_file /etc/nginx/webdav.htpasswd;

            # Headers para compatibilidad WebDAV Android
            if ($request_method = OPTIONS) {
              add_header DAV "1,2";
              add_header Allow "OPTIONS, GET, HEAD, PUT, DELETE, MKCOL, PROPFIND, COPY, MOVE";
              add_header MS-Author-Via "DAV";
              return 204;
            }
          }
        '';

      };
    };
  };

  # Directorio temporal requerido por nginx si luego habilitas uploads
  systemd.tmpfiles.rules = [
    "d /etc/nginx 0755 root root -"
    "d /tmp/webdav 0770 nginx nginx -"
  ];

  # (Opcional) Asegurar permisos de escritura si luego activas WebDAV RW:
  # users.users.nginx.extraGroups = [ "media" ];
  # y en el host: chgrp -R media /var/media/videos && chmod -R g+rwX /var/media/videos


  system.stateVersion = "24.05";
}
