#!/usr/bin/env bash
# netspeed.sh — Point this machine to Cloudflare DNS (IPv4+IPv6) via NetworkManager + systemd-resolved.
# Style: tabs, K&R-ish, minimal abstraction. Safe, idempotent, with clear checks & logs.

set -euo pipefail

CF_V4="1.1.1.1 1.0.0.1"
CF_V6="2606:4700:4700::1111 2606:4700:4700::1001"
NM_DNS_CONF="/etc/NetworkManager/conf.d/dns.conf"
STUB="/run/systemd/resolve/stub-resolv.conf"
RESOLV="/etc/resolv.conf"

log() { printf "[netspeed] %s\n" "$*"; }
die() { printf "[netspeed][ERROR] %s\n" "$*" >&2; exit 1; }
need() {
	for c in "$@"; do
		command -v "$c" >/dev/null 2>&1 || die "Missing command: $c"
	done
}

main() {
	# 0) root check
	[ "${EUID:-$(id -u)}" -eq 0 ] || die "Run as root (sudo)."

	# 1) prereqs
	need nmcli systemctl resolvectl ln sed awk grep date

	# 2) detect active ethernet connection name and device
	local conn dev
	conn="$(nmcli -t -f NAME,TYPE con show --active | awk -F: '$2=="ethernet"{print $1; exit}')"
	if [ -z "${conn}" ]; then
		conn="$(nmcli -t -f NAME,TYPE con show | awk -F: '$2=="ethernet"{print $1; exit}')"
	fi
	[ -n "${conn}" ] || die "No NetworkManager ethernet connection found."

	dev="$(nmcli -t -f DEVICE,STATE,TYPE dev status | awk -F: '$3=="ethernet" && $2=="connected"{print $1; exit}')"
	[ -n "${dev}" ] || dev="$(nmcli -t -f DEVICE,TYPE dev status | awk -F: '$2=="ethernet"{print $1; exit}')"
	[ -n "${dev}" ] || die "No ethernet device detected."

	log "Using connection: '${conn}', device: '${dev}'"

	# 3) enable systemd-resolved and wire resolv.conf to the stub
	log "Enabling systemd-resolved..."
	systemctl enable --now systemd-resolved >/dev/null

	if [ ! -L "${RESOLV}" ] || [ "$(readlink -f "${RESOLV}")" != "${STUB}" ]; then
		if [ -e "${RESOLV}" ] && [ ! -L "${RESOLV}" ]; then
			cp -a "${RESOLV}" "${RESOLV}.bak.$(date +%s)" || true
			log "Backed up ${RESOLV} to ${RESOLV}.bak.*"
		fi
		ln -sf "${STUB}" "${RESOLV}"
		log "Linked ${RESOLV} -> ${STUB}"
	fi

	# 4) ensure NetworkManager uses systemd-resolved (idempotent)
	mkdir -p "$(dirname "${NM_DNS_CONF}")"
	if [ ! -f "${NM_DNS_CONF}" ] || ! grep -q '^dns=systemd-resolved' "${NM_DNS_CONF}"; then
		cat > "${NM_DNS_CONF}" <<-EOF
		[main]
		dns=systemd-resolved
		EOF
		log "Wrote ${NM_DNS_CONF} (dns=systemd-resolved)."
	fi

	# 5) set Cloudflare DNS on the NM connection and ignore DHCP DNS
	log "Applying Cloudflare DNS to '${conn}'..."
	nmcli con mod "${conn}" ipv4.dns "${CF_V4}" ipv4.ignore-auto-dns yes
	nmcli con mod "${conn}" ipv6.dns "${CF_V6}" ipv6.ignore-auto-dns yes

	# 6) restart services and bounce the connection to apply changes immediately
	log "Restarting NetworkManager and bouncing connection..."
	systemctl restart NetworkManager
	nmcli -g GENERAL.STATE con show "${conn}" >/dev/null 2>&1 || die "Connection '${conn}' not found after restart."
	nmcli con down "${conn}" || true
	nmcli con up "${conn}"

	# 7) flush caches, show current DNS for the link
	resolvectl flush-caches || true

	log "Current DNS as seen by systemd-resolved:"
	if resolvectl status "${dev}" >/dev/null 2>&1; then
		resolvectl status "${dev}" | sed -n '/DNS Servers:/,/^$/p'
	else
		# Fallback: global view
		resolvectl status | sed -n '/Current DNS Server/,+3p'
	fi

	# 8) quick functional checks
	log "Testing DNS and connectivity..."
	resolvectl query archlinux.org || log "resolvectl query failed (non-fatal)"
	ping -c3 -W2 1.1.1.1 >/dev/null 2>&1 && log "Ping 1.1.1.1: OK" || log "Ping 1.1.1.1: FAIL (check link/ISP/MTU)"

	log "Done. Cloudflare DNS should now be active for ${conn} on ${dev}."
}

main "$@"
