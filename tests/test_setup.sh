#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd -- "$(dirname -- "$(readlink -f "$0")")/.." && pwd)"

bash -n "$ROOT/setup.sh" "$ROOT/rollback.sh" "$ROOT/lib/common.sh" "$ROOT/lib/state.sh" "$ROOT/lib/mac.sh" "$ROOT/lib/privacy.sh"

grep -q '802-11-wireless.cloned-mac-address random' "$ROOT/lib/mac.sh"
! grep -q '802-3-ethernet' "$ROOT/lib/mac.sh"

grep -q 'wifi.scan-rand-mac-address=yes' "$ROOT/lib/privacy.sh"
grep -q 'dns=systemd-resolved' "$ROOT/lib/privacy.sh"
grep -q 'connection.dns-over-tls yes' "$ROOT/lib/privacy.sh"
grep -q 'connection.dnssec yes' "$ROOT/lib/privacy.sh"
grep -q '9.9.9.9#dns.quad9.net' "$ROOT/lib/privacy.sh"
grep -q '2620:fe::fe#dns.quad9.net' "$ROOT/lib/privacy.sh"

# No unrelated profile hardening or audit command should remain in setup.
! grep -Eq 'connection\.llmnr|connection\.mdns|dhcp-client-id|addr-gen-mode|802-3-ethernet|audit\.sh' "$ROOT/setup.sh" "$ROOT/lib/mac.sh" "$ROOT/lib/privacy.sh"
grep -q 'backup_property' "$ROOT/lib/mac.sh"
grep -q 'backup_property' "$ROOT/lib/privacy.sh"
grep -q 'base64 -d --strict' "$ROOT/rollback.sh"
grep -q 'State was preserved for another rollback attempt' "$ROOT/rollback.sh"
grep -q 'acquire_lock' "$ROOT/setup.sh"
grep -q 'acquire_lock' "$ROOT/rollback.sh"

if grep -REq 'macchanger|nft flush ruleset|systemctl restart NetworkManager' "$ROOT/setup.sh" "$ROOT/rollback.sh" "$ROOT/lib/"*.sh; then
    exit 1
fi

echo "Static validation passed."
