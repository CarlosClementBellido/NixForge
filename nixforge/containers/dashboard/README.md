# Dashboard Container

Static site serving a real‑time system metrics dashboard (Chart.js).

## Features

- CPU, RAM, Swap, Disk usage
- Network throughput
- Temperature
- Historical charts and smoothing

## Access

- Reverse‑proxied as the host root `/`:
  - `https://server.clementbellido.es/`

## Files

- `configuration.nix` — Container definition.
- `site/` — Static assets (HTML/CSS/JS).

## Notes

- Keep assets small; enable caching headers in Nginx.
- For long history, consider storing samples in a ring buffer or TSDB.
