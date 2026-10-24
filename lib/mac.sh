#!/usr/bin/env bash
set -euo pipefail

configure_mac_profiles() {
    local uuid type
    while IFS=: read -r uuid type; do
        [ -n "$uuid" ] || continue
        [ "$type" = "802-11-wireless" ] || continue

        backup_property "$uuid" 802-11-wireless.cloned-mac-address
        sudo nmcli connection modify "$uuid" 802-11-wireless.cloned-mac-address random
    done < <(nmcli -t -f UUID,TYPE connection show)
}
