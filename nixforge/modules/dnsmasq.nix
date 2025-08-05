{ ... }:

{
  services.dnsmasq = {
    enable = true;
    settings = {
      interface = [ "enp2s0f1" "enp4s0" ];
      bind-dynamic = true;
      listen-address = "192.168.10.1,192.168.20.1";
      no-dhcp-interface = "lo";

      domain-needed = true;
      bogus-priv = true;

      dhcp-range = [
        "192.168.10.50,192.168.10.150,12h"
        "192.168.20.50,192.168.20.150,12h"
      ];

      dhcp-option = [
        "tag:enp2s0f1,3,192.168.10.1"
        "tag:enp2s0f1,6,1.1.1.1,8.8.8.8"
        "tag:enp4s0,3,192.168.20.1"
        "tag:enp4s0,6,1.1.1.1,8.8.8.8"
      ];

      address = [ "/server.clementbellido.es/192.168.1.129" ];
      log-dhcp = true;
      dhcp-broadcast = true;
    };
  };
}
