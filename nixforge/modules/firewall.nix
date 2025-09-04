{ ... }:

{
  networking.firewall = {
    enable = true;

    # Puertos expuestos en el propio host
    allowedTCPPorts = [ 8096 9091 51413 80 443 25565 8080 2022 8081 4713 ];
    allowedUDPPorts = [ 51413 25565 ];

    # Confía en las LAN (sin filtrar INPUT en esas ifaces)
    trustedInterfaces = [ "lan10g0" "lan1g0" ];

    # Reglas iptables adicionales (forward y NAT) apuntando a wan0
    extraCommands = ''
      # Forward para contenedores ve-* ↔ WAN
      iptables -C FORWARD -i ve-*   -o wan0 -j ACCEPT || iptables -A FORWARD -i ve-*   -o wan0 -j ACCEPT
      iptables -C FORWARD -i wan0   -o ve-* -m state --state RELATED,ESTABLISHED -j ACCEPT || iptables -A FORWARD -i wan0   -o ve-* -m state --state RELATED,ESTABLISHED -j ACCEPT

      # (Opcional) Forward explícito para LAN físicas ↔ WAN
      iptables -C FORWARD -i lan10g0 -o wan0 -j ACCEPT || iptables -A FORWARD -i lan10g0 -o wan0 -j ACCEPT
      iptables -C FORWARD -i wan0    -o lan10g0 -m state --state RELATED,ESTABLISHED -j ACCEPT || iptables -A FORWARD -i wan0 -o lan10g0 -m state --state RELATED,ESTABLISHED -j ACCEPT

      iptables -C FORWARD -i lan1g0  -o wan0 -j ACCEPT || iptables -A FORWARD -i lan1g0  -o wan0 -j ACCEPT
      iptables -C FORWARD -i wan0    -o lan1g0 -m state --state RELATED,ESTABLISHED -j ACCEPT || iptables -A FORWARD -i wan0 -o lan1g0 -m state --state RELATED,ESTABLISHED -j ACCEPT

      # NAT MASQUERADE para todas tus subredes saliendo por wan0
      for NET in 192.168.10.0/24 192.168.20.0/24 192.168.100.0/24 192.168.101.0/24 192.168.102.0/24 192.168.103.0/24 192.168.104.0/24 192.168.105.0/24 192.168.106.0/24; do
        iptables -t nat -C POSTROUTING -s $NET -o wan0 -j MASQUERADE || \
        iptables -t nat -A POSTROUTING -s $NET -o wan0 -j MASQUERADE
      done
    '';
  };
}
