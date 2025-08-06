{ config, pkgs, lib, ... }:

let
  cockpit-apps = pkgs.callPackage packages/cockpit/default.nix { inherit pkgs; };
  unstable = import (fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/nixos-unstable.tar.gz";
    sha256 = "09nmwsahc0zsylyk5vf6i62x4jfvwq4r2mk8j0lmr3zzk723dwj3";
  }) {};
  cockpit-machines = pkgs.callPackage packages/cockpit-machines/default.nix { inherit pkgs; };
  libvirt-dbus = pkgs.callPackage packages/libvirt-dbus/default.nix { inherit pkgs; };
  myPython3 = pkgs.python3.withPackages (ps: with ps; [
    pygobject3
  ]);
in
{
    imports = [
      <nixpkgs/nixos/modules/profiles/minimal.nix>
      ./users.cred
    ];

  networking.hostName = "cockpit";
  networking.firewall.allowedTCPPorts = [ 9090 ];
  networking.firewall.enable = true;

  services.cockpit.enable = true;

  environment.etc."cockpit/cockpit.conf".text = lib.mkForce ''
    [WebService]
    Origins = https://cockpit.server.clementbellido.es
    ProtocolHeader = X-Forwarded-Proto
    ForwardedForHeader = X-Forwarded-For
    AllowUnencrypted = true
  '';

  services.dbus.enable = true;
  systemd.enableUnifiedCgroupHierarchy = true;

  environment.systemPackages = with pkgs; [
    cockpit
    cockpit-machines
    cockpit-apps.virtual-machines
    libvirt
    libvirt-dbus
    ] ++ (with unstable; [
      virt-manager
    ]) ++ [
      myPython3
    ];

  system.stateVersion = "24.05";
}
