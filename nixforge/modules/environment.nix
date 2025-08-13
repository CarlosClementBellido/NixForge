{ ... }:

{
  environment.etc."systemd/nspawn/pterodactyl.nspawn".text = ''
    [Exec]
    # Permitir syscalls de keyring y bpf para Docker/Containerd
    SystemCallFilter=add_key keyctl bpf
  '';
}