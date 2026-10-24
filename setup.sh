#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "$(readlink -f "$0")")" && pwd)"
[ "$(id -u)" -ne 0 ] || { echo "[X] Run as a normal user." >&2; exit 1; }

source "$ROOT/lib/common.sh"
source "$ROOT/lib/state.sh"
source "$ROOT/lib/mac.sh"
source "$ROOT/lib/privacy.sh"

require_command sudo
require_command nmcli
require_command systemctl
require_command base64
require_command tac
require_command flock
require_command awk
require_command paste

nmcli general status >/dev/null 2>&1 || die "NetworkManager is not available."
systemctl is-active --quiet systemd-resolved || die "systemd-resolved must be active for Quad9 DNS-over-TLS. No changes were made."

acquire_lock

if sudo test -e "$STATE_DIR"; then
    die "An existing rollback state was found. Run ./rollback.sh first; refusing to overwrite it."
fi

# Never replace an unrelated file at the path owned by this project.
if sudo test -e "$CONFIG_FILE" &&
   ! sudo grep -q '^# Managed by Arch Privacy Setup\.$' "$CONFIG_FILE"; then
    die "$CONFIG_FILE already exists and is not marked as managed by this project. No changes were made."
fi

# Record all state before the first system change.
state_init
state_backup_config

rollback_on_error() {
    warn "Setup failed. Starting automatic rollback..."
    ARCH_PRIVACY_SETUP_LOCK_HELD=1 "$ROOT/rollback.sh" || warn "Automatic rollback also failed. Use ./rollback.sh manually."
}
trap rollback_on_error ERR

on_interrupt() {
    warn "Setup interrupted. Rollback state was preserved in $STATE_DIR."
    exit 130
}
trap on_interrupt INT TERM

log "Enabling NetworkManager Wi-Fi MAC randomization..."
configure_mac_profiles

log "Configuring Quad9 DNS-over-TLS for Wi-Fi profiles..."
configure_scan_privacy
configure_connection_privacy

sudo nmcli general reload conf >/dev/null

# Verify saved profile configuration. This does not claim to prove live packet
# routing; reconnect to activate settings and use resolvectl/dig to test DNS.
while IFS=: read -r uuid type; do
    [ -n "$uuid" ] || continue
    [ "$type" = "802-11-wireless" ] || continue

    mac="$(nmcli -g 802-11-wireless.cloned-mac-address connection show "$uuid")"
    dns4="$(nmcli -g ipv4.dns connection show "$uuid" | awk 'NF' | paste -sd, -)"
    dns6="$(nmcli -g ipv6.dns connection show "$uuid" | awk 'NF' | paste -sd, -)"
    dot="$(nmcli -g connection.dns-over-tls connection show "$uuid")"
    dnssec="$(nmcli -g connection.dnssec connection show "$uuid")"

    if [ "$mac" != "random" ]; then
        warn "MAC setting verification failed for Wi-Fi profile $uuid."
        rollback_on_error
        trap - ERR
        exit 1
    fi
    if [[ "$dns4" != *"9.9.9.9#dns.quad9.net"* || "$dns4" != *"149.112.112.112#dns.quad9.net"* ]]; then
        warn "IPv4 Quad9 verification failed for Wi-Fi profile $uuid."
        rollback_on_error
        trap - ERR
        exit 1
    fi
    if [[ "$dns6" != *"2620:fe::fe#dns.quad9.net"* || "$dns6" != *"2620:fe::9#dns.quad9.net"* ]]; then
        warn "IPv6 Quad9 verification failed for Wi-Fi profile $uuid."
        rollback_on_error
        trap - ERR
        exit 1
    fi
    if [ "$dot" != "yes" ] || [ "$dnssec" != "yes" ]; then
        warn "DNS-over-TLS/DNSSEC verification failed for Wi-Fi profile $uuid."
        rollback_on_error
        trap - ERR
        exit 1
    fi
done < <(nmcli -t -f UUID,TYPE connection show)

log "Settings applied and profile configuration verified."
log "Reconnect to Wi-Fi for the connection MAC and DNS settings to take effect."
log "If connectivity breaks, run: ./rollback.sh"
log "Live DNS routing and hardware behavior still need to be checked on this machine."
