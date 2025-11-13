{ config, pkgs, lib, ... }:
let domain = "vpn.server.clementbellido.es"; 
in {
  environment.systemPackages = with pkgs; [ wireguard-tools iproute2 wg-portal jq ];

  systemd.tmpfiles.rules = [
    "d /etc/wireguard 0750 root root -"
    "d /var/lib/wg-portal 0750 root root -"
    "d /dev/net 0755 root root -"
    "c /dev/net/tun 0666 root root 10:200"
  ];

  systemd.services.wg-portal = {
    description = "WireGuard Portal";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      ExecStart = ''
        ${pkgs.wg-portal}/bin/wg-portal \
          --listen 0.0.0.0:51821 \
          --data-dir /var/lib/wg-portal \
          --wg-bin ${pkgs.wireguard-tools}/bin/wg \
          --wg-quick-bin ${pkgs.wireguard-tools}/bin/wg-quick \
          --config-dir /etc/wireguard \
          --external-url https://${domain} \
          --session-secret $(cat /var/lib/wg-portal/session.key || (head -c 32 /dev/urandom | base64 | tee /var/lib/wg-portal/session.key)) \
          --enable-registration=false
      '';
      AmbientCapabilities = "CAP_NET_ADMIN CAP_SYS_ADMIN";
      CapabilityBoundingSet = "CAP_NET_ADMIN CAP_SYS_ADMIN";
      ReadWritePaths = [ "/var/lib/wg-portal" "/etc/wireguard" "/dev/net/tun" ];
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = "read-only";
    };
  };
}
