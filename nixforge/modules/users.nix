{ ... }:

{
  users.users.clement = {
    isNormalUser = true;
    description = "Clement";
    extraGroups = [ "wheel" ];
    initialPassword = "1234";
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGkOzjRJ+C1RqylmB8PbyrV0d8UCz09+3Ss4V0KRaIKL clembell-server"
    ];
  };
}
