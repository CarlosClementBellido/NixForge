{ config, pkgs, lib, ... }:

{
  environment.systemPackages = with pkgs; [ msmtp mailutils ];

  programs.msmtp = {
    enable = false;
    setSendmail = true;
  };

  # archivo de configuración para msmtp
  environment.etc."msmtprc".text = ''
    defaults
    auth           on
    tls            on
    tls_trust_file /etc/ssl/certs/ca-certificates.crt
    logfile        /var/log/msmtp.log

    account        ionos
    host           smtp.ionos.es
    port           587
    from           server@clementbellido.es
    user           server@clementbellido.es
    password       1234

    account default : ionos
  '';

  users.users.root = {
    isSystemUser = true;
    extraGroups = [ "wheel" ];
  };

  system.stateVersion = "24.05";
}
