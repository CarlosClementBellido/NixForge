# Cockpit Container

Web admin interface for the host and virtual machines.

## Features

- System overview: CPU, memory, storage, services.
- Libvirt integration via `cockpit-machines`.
- Reverse proxy via host Nginx with TLS (ACME).

## Access

Recommended path (via host Nginx):

- `https://server.clementbellido.es/cockpit`

## Files

- `configuration.nix` — Container definition.
- `users.cred.example` — Example for local users.
- `packages/` — Custom overlays for cockpit components.

## Security Notes

- Restrict `Origins` to trusted domains in Cockpit config.
- Always use HTTPS via reverse proxy.
- Regularly update Cockpit and plugins.
