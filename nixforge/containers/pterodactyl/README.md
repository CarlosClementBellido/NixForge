# Pterodactyl Container

Self‑contained deployment of the Pterodactyl panel with MariaDB and Redis.

## Features

- Automated install and DB bootstrap
- PHP‑FPM + Nginx reverse proxy on host
- Background queue workers and scheduler

## Files

- `configuration.nix` — Container definition

## Notes

- Ensure cron/queue workers are enabled for schedules.
- Expose only via the host Nginx with TLS.
