#!/usr/bin/env bash
set -euo pipefail

PRIVACY_PROPERTIES=(
    "connection.dns-over-tls"
    "connection.dnssec"
    "ipv4.dns"
    "ipv4.ignore-auto-dns"
    "ipv6.dns"
    "ipv6.ignore-auto-dns"
)

configure_scan_privacy() {
    local file="/etc/NetworkManager/conf.d/90-arch-privacy-setup.conf"
    local tmp
    tmp="$(mktemp)"

    sudo install -d -m 0755 /etc/NetworkManager/conf.d
    cat > "$tmp" <<'CONF'
# Managed by Arch Privacy Setup.
[main]
dns=systemd-resolved

[device]
wifi.scan-rand-mac-address=yes
CONF

    if ! sudo install -m 0644 "$tmp" "$file"; then
        rm -f "$tmp"
        die "Could not install NetworkManager Wi-Fi privacy configuration."
    fi
    rm -f "$tmp"
}

configure_connection_privacy() {
    local uuid type property
    while IFS=: read -r uuid type; do
        [ -n "$uuid" ] || continue
        [ "$type" = "802-11-wireless" ] || continue

        for property in "${PRIVACY_PROPERTIES[@]}"; do
            backup_property "$uuid" "$property"
        done

        sudo nmcli connection modify "$uuid" \
            connection.dns-over-tls yes \
            connection.dnssec yes \
            ipv4.dns "9.9.9.9#dns.quad9.net,149.112.112.112#dns.quad9.net" \
            ipv4.ignore-auto-dns yes \
            ipv6.dns "2620:fe::fe#dns.quad9.net,2620:fe::9#dns.quad9.net" \
            ipv6.ignore-auto-dns yes
    done < <(nmcli -t -f UUID,TYPE connection show)
}
