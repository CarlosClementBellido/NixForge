# Cockpit Packages Overlay

Custom package definitions used inside the Cockpit container.

- `cockpit/` — Cockpit base package override or pin.
- `cockpit-machines/` — Machines/VM management plugin.
- `libvirt-dbus/` — DBus bridge for libvirt integration.

## Build Notes

Each subfolder includes a `default.nix` and (optionally) patches. Pin versions if stability matters.
