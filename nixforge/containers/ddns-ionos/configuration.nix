{ config, pkgs, lib, ... }:

{
  environment.systemPackages = with pkgs; [
    python3
    python3Packages.pip
    util-linux
    curl
    git
    vim
    gnupg
  ];

  services.cron.enable = true;

  systemd.services.install-dyndns-client = {
    enable = true;
    description = "Instalar domain-connect-dyndns vía pip";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.python3Packages.pip}/bin/pip install domain-connect-dyndns";
    };
  };

  users.users.root = {
    isSystemUser = true;
    extraGroups = [ "wheel" ];
  };

  system.stateVersion = "24.05";

  environment.variables.PATH = "/root/.local/bin:${pkgs.coreutils}/bin";
}
