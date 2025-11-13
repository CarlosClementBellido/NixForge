{ pkgs, ... }:

{
  services.nginx = {
    enable = true;
    recommendedTlsSettings = true;
    recommendedGzipSettings = true;
    recommendedOptimisation = true;

    virtualHosts = {

      "vpn.server.clementbellido.es" = {
        enableACME = true;
        forceSSL = true;
        locations."/" = {
          proxyPass = "http://192.168.106.2:51821";
          proxyWebsockets = true;
        };
      };

      "pterodactyl.server.clementbellido.es" = {
        enableACME = true;
        forceSSL = true;
        locations."/" = {
          proxyPass = "http://192.168.104.2:8081";
          proxyWebsockets = true;
          extraConfig = ''
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header Host $host;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_set_header X-Forwarded-Host $host;
            proxy_set_header X-Forwarded-Port $server_port;

            proxy_redirect off;
            proxy_buffering off;
            proxy_request_buffering off;

            proxy_connect_timeout 300s;
            proxy_send_timeout    300s;
            proxy_read_timeout    300s;
          '';
        };
      };

      "wings.server.clementbellido.es" = {
        enableACME = true;
        forceSSL = true;

        locations."/" = {
          proxyPass = "http://192.168.104.2:8080";
          proxyWebsockets = true;
          extraConfig = ''
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_read_timeout 300s;
            proxy_send_timeout 300s;
          '';
        };
      };

      "transmission.server.clementbellido.es" = {
        enableACME = true;
        forceSSL = true;
        listen = [
          { addr = "0.0.0.0"; port = 80; ssl = false; }
          { addr = "0.0.0.0"; port = 443; ssl = true; }
        ];

        locations."/" = {
          proxyPass = "http://192.168.101.2:9091/";
          proxyWebsockets = true;
          extraConfig = ''
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
          '';
        };

        locations."/webdav/" = {
          proxyPass = "http://192.168.101.2:8080/";
          extraConfig = ''
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;

            client_max_body_size 0;
            proxy_request_buffering off;
          '';
        };
      };

      "jellyfin.server.clementbellido.es" = {
        enableACME = true;
        forceSSL = true;
        listen = [
          { addr = "0.0.0.0"; port = 80; ssl = false; }
          { addr = "0.0.0.0"; port = 443; ssl = true; }
        ];

        locations."/" = {
          proxyPass = "http://192.168.100.2:8096/";
          proxyWebsockets = true;
          extraConfig = ''
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;

            sub_filter_once off;
            sub_filter '="/' '="/jellyfin/';
            sub_filter '=/web/' '=/jellyfin/web/';
            sub_filter_types text/html;
          '';
        };
      };

      "cockpit.server.clementbellido.es" = {
        enableACME = true;
        forceSSL = true;

        locations."/" = {
          proxyPass = "http://192.168.103.2:9090";
          proxyWebsockets = true;
          extraConfig = ''
            proxy_set_header Host $host;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_set_header X-Real-IP $remote_addr;
          '';
        };
      };

      "server.clementbellido.es" = {
        enableACME = true;
        forceSSL = true;
        listen = [
          { addr = "0.0.0.0"; port = 443; ssl = true; }
          { addr = "0.0.0.0"; port = 80; ssl = false; }
        ];

        locations."/" = {
          proxyPass = "http://192.168.102.2";
          extraConfig = ''
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
          '';
        };

        locations."/metrics.json" = {
          proxyPass = "http://192.168.102.2/metrics.json";
          extraConfig = ''
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
          '';
        };
      };
    };
  };

  security.acme = {
    acceptTerms = true;
    defaults.email = "carlos.clement.bellido@gmail.com";
  };
}
