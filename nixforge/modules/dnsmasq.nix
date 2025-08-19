{ ... }:

{
  services.dnsmasq = {
    enable = true;
    settings = {
      interface = [ "lan10g0" "lan1g0" ];
      bind-dynamic = true;
      listen-address = "192.168.10.1,192.168.20.1";
      no-dhcp-interface = "lo";

      domain-needed = true;
      bogus-priv = true;

      dhcp-range = [
        "192.168.10.50,192.168.10.150,12h"
        "192.168.20.50,192.168.20.150,12h"
      ];

      # dnsmasq **auto-etiqueta** clientes por interfaz con el nombre de la interfaz;
      # mantenemos el patrón que ya usabas, cambiando las etiquetas.
      dhcp-option = [
        "tag:lan10g0,3,192.168.10.1"         # gateway
        "tag:lan10g0,6,1.1.1.1,8.8.8.8"      # DNS
        "tag:lan1g0,3,192.168.20.1"
        "tag:lan1g0,6,1.1.1.1,8.8.8.8"
      ];

      # Si el A de tu dominio debe resolver a la IP LAN del servidor:
      address = [ "/server.clementbellido.es/192.168.1.129" ];

      log-dhcp = true;
      dhcp-broadcast = true;
    };
  };
}
