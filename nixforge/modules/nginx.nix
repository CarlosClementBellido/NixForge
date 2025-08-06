{ ... }:

{
  services.nginx = {
    enable = true;
    recommendedTlsSettings = true;
    recommendedGzipSettings = true;
    recommendedOptimisation = true;

    virtualHosts = {
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
