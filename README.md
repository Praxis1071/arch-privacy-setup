# Arch Privacy Setup

A small, reversible NetworkManager setup for Arch Linux and CachyOS. It does only two things:

- Enables randomized MAC addresses for saved Wi-Fi profiles and random MAC addresses during Wi-Fi scanning.
- Configures Quad9 DNS over TLS for saved Wi-Fi profiles.

It does not change Ethernet profiles, VPN profiles, firewall rules, or unrelated privacy settings.

## Requirements

NetworkManager, an active `systemd-resolved` service, `sudo`, and standard command-line utilities.

## Apply

```bash
chmod +x setup.sh rollback.sh
./setup.sh
```

The script saves the original Wi-Fi profile properties and its NetworkManager configuration before changing anything. It refuses to overwrite an existing rollback state or an unrelated file at its configuration path. It does not forcibly disconnect active connections; reconnect to Wi-Fi after setup.

## Undo

```bash
./rollback.sh
```

Rollback restores the saved values and keeps its state if restoration or verification fails. It works locally and does not require internet access.

## Manual checks

After reconnecting to Wi-Fi:

```bash
nmcli -f GENERAL.CONNECTION,GENERAL.HWADDR,GENERAL.PERMANENT-HWADDR device show
resolvectl status
resolvectl query example.com
```

A successful DNS query alone does not prove that Quad9 handled it. Check the active resolver configuration as well. These scripts have not been validated against every Wi-Fi router, hotspot, captive portal, or system configuration.

## Scope and limitations

MAC randomization reduces exposure of the hardware MAC address to Wi-Fi networks; it does not make internet activity anonymous. Quad9 DNS does not encrypt all traffic or bypass DNS-independent blocks.
