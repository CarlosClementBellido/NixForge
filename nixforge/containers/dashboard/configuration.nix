{ config, pkgs, lib, ... }:

{
  networking.firewall.allowedTCPPorts = [ 80 ];

  services.nginx = {
    enable = true;
    defaultHTTPListenPort = 80;

    virtualHosts."_" = {
      root = "/etc/nginx/html";
      locations."/" = {
        extraConfig = ''
          add_header Cache-Control "no-store";
        '';
      };
    };
  };

  environment.etc."nginx/html/index.html".source = ./site/index.html;
  environment.etc."nginx/html/css/style.css".source = ./site/css/style.css;
  environment.etc."nginx/html/js/main.js".source = ./site/js/main.js;

  environment.systemPackages = with pkgs; [ bash ];
}
