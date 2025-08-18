# DDNS IONOS Container

Keeps your public IP updated in IONOS DNS via their dynamic DNS endpoints.

## Features

- Periodic IP check and DNS update
- Minimal footprint, logs for diagnostics
- Optional alerting via SMTP if updates fail

## Adding domains/subdormains

Enter de ddns-ionos machine (`sudo machinectl shell ddns-ionos`), add the domain (`domain-connect-dyndns setup --domain subdomain2.subdomain1.domain.xx`), and then `domain-connect-dyndns update --all`.

## Files

- `configuration.nix` — Container definition
