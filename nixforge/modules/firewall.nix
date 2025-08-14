{ ... }:

{
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 8096 9091 51413 80 443 25565 8080 2022 8081 ];
    allowedUDPPorts = [ 51413 25565 ];
    trustedInterfaces = [ "enp2s0f1" "enp4s0" ];
    extraCommands = ''
      iptables -C FORWARD -i ve-* -o enp2s0f0 -j ACCEPT || iptables -A FORWARD -i ve-* -o enp2s0f0 -j ACCEPT
      iptables -C FORWARD -i enp2s0f0 -o ve-* -m state --state RELATED,ESTABLISHED -j ACCEPT || iptables -A FORWARD -i enp2s0f0 -o ve-* -m state --state RELATED,ESTABLISHED -j ACCEPT

      for NET in 192.168.10.0/24 192.168.20.0/24 192.168.100.0/24 192.168.101.0/24 192.168.102.0/24 192.168.103.0/24 192.168.104.0/24 192.168.105.0/24; do
        iptables -t nat -C POSTROUTING -s $NET -o enp2s0f0 -j MASQUERADE || \
        iptables -t nat -A POSTROUTING -s $NET -o enp2s0f0 -j MASQUERADE
      done
    '';
  };
}
