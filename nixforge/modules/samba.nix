{ ... }:

{
  services.samba = {
    enable = true;
    openFirewall = true;
    shares = {
      server = {
        path = "/";
        browseable = "yes";
        "read only" = "no";
        "guest ok" = "yes";
      };
    };
  };

  services.samba-wsdd = {
    enable = true;
    openFirewall = true;
  };
}
