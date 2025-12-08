#!/usr/bin/env bash
#
# harden_fail2ban_nft.sh
# Deb 12/13: Fail2Ban + nftables blacklist sets (IPv4/IPv6) para proteger SSH.
# Ejecutar como root.

set -euo pipefail

if [[ "$(id -u)" -ne 0 ]]; then
  echo "[!] Debes ejecutar este script como root." >&2
  exit 1
fi

TS="$(date +%Y%m%d-%H%M%S)"

echo "[+] Instalando paquetes necesarios (fail2ban, nftables)..."
apt-get update -y
DEBIAN_FRONTEND=noninteractive apt-get install -y fail2ban nftables

echo "[+] Habilitando y arrancando nftables..."
systemctl enable --now nftables

# --------------------------------------------------------
# 1) nftables: tabla inet f2b + sets IPv4/IPv6 + include
# --------------------------------------------------------
NFT_MAIN_CONF="/etc/nftables.conf"
NFT_F2B_CONF="/etc/nftables-f2b.conf"

if [[ -f "${NFT_MAIN_CONF}" ]]; then
  cp "${NFT_MAIN_CONF}" "${NFT_MAIN_CONF}.bak.${TS}"
  echo "[+] Backup de ${NFT_MAIN_CONF} -> ${NFT_MAIN_CONF}.bak.${TS}"
fi

cat > "${NFT_F2B_CONF}" << 'EOF'
table inet f2b {
    # IPs baneadas por Fail2Ban (IPv4)
    set blacklist_v4 {
        type ipv4_addr
        flags timeout
        # Los elementos tendrán timeout individual desde Fail2Ban
    }

    # IPs baneadas por Fail2Ban (IPv6)
    set blacklist_v6 {
        type ipv6_addr
        flags timeout
    }

    # Filtro de entrada: DROP temprano a IPs baneadas
    chain input {
        type filter hook input priority -5; policy accept;

        ip  saddr @blacklist_v4 drop
        ip6 saddr @blacklist_v6 drop
    }
}
EOF

# Asegurar include en nftables.conf (solo si no existe)
if ! grep -q 'nftables-f2b.conf' "${NFT_MAIN_CONF}"; then
  echo '' >> "${NFT_MAIN_CONF}"
  echo '# Fail2Ban blacklist (SSH, etc.)' >> "${NFT_MAIN_CONF}"
  echo 'include "/etc/nftables-f2b.conf"' >> "${NFT_MAIN_CONF}"
fi

echo "[+] Recargando nftables con la nueva tabla inet f2b..."
nft -f "${NFT_MAIN_CONF}"

echo "[+] Estado de la tabla inet f2b:"
nft list table inet f2b || echo "[!] Ojo: no se pudo listar inet f2b (revisa errores de nft)."

# --------------------------------------------------------
# 2) Fail2Ban: acción personalizada nftables-f2b (usa los sets anteriores)
# --------------------------------------------------------
F2B_ACTION_DIR="/etc/fail2ban/action.d"
F2B_ACTION_FILE="${F2B_ACTION_DIR}/nftables-f2b.local"

mkdir -p "${F2B_ACTION_DIR}"

if [[ -f "${F2B_ACTION_FILE}" ]]; then
  cp "${F2B_ACTION_FILE}" "${F2B_ACTION_FILE}.bak.${TS}"
  echo "[+] Backup de ${F2B_ACTION_FILE} -> ${F2B_ACTION_FILE}.bak.${TS}"
fi

cat > "${F2B_ACTION_FILE}" << 'EOF'
# acción fail2ban → nftables
# Añade / borra IPs en los sets:
#   - inet f2b blacklist_v4 (IPv4)
#   - inet f2b blacklist_v6 (IPv6)

[Definition]

# Se ejecuta al iniciar el jail
actionstart = nft list table inet f2b >/dev/null 2>&1 || nft add table inet f2b
              nft list set inet f2b blacklist_v4 >/dev/null 2>&1 || nft 'add set inet f2b blacklist_v4 { type ipv4_addr; flags timeout; }'
              nft list set inet f2b blacklist_v6 >/dev/null 2>&1 || nft 'add set inet f2b blacklist_v6 { type ipv6_addr; flags timeout; }'

# Se ejecuta al parar el jail
actionstop  = nft 'flush set inet f2b blacklist_v4' 2>/dev/null || true
              nft 'flush set inet f2b blacklist_v6' 2>/dev/null || true

# Check de existencia
actioncheck = nft list table inet f2b >/dev/null 2>&1

# Ban: añade la IP al set con timeout
# Nota: <ip6> puede venir vacío en jails solo-IPv4; ignoramos errores.
actionban   = nft 'add element inet f2b blacklist_v4 { <ip> timeout <bantime>s }' 2>/dev/null || true
              nft 'add element inet f2b blacklist_v6 { <ip6> timeout <bantime>s }' 2>/dev/null || true

# Unban: elimina la IP de los sets (si existe)
actionunban = nft 'delete element inet f2b blacklist_v4 { <ip> }' 2>/dev/null || true
              nft 'delete element inet f2b blacklist_v6 { <ip6> }' 2>/dev/null || true

[Init]
name = default
EOF

# --------------------------------------------------------
# 3) Fail2Ban: jail.local endurecido para SSH + backend systemd
# --------------------------------------------------------
F2B_JAIL_LOCAL="/etc/fail2ban/jail.local"

if [[ -f "${F2B_JAIL_LOCAL}" ]]; then
  cp "${F2B_JAIL_LOCAL}" "${F2B_JAIL_LOCAL}.bak.${TS}"
  echo "[+] Backup de ${F2B_JAIL_LOCAL} -> ${F2B_JAIL_LOCAL}.bak.${TS}"
fi

cat > "${F2B_JAIL_LOCAL}" << 'EOF'
# jail.local – configuración endurecida mínima para SSH con nftables
# backend = systemd → usa journald (sin parsear ficheros de log)
# banaction = nftables-f2b → acción definida en action.d/nftables-f2b.local

[DEFAULT]
backend  = systemd
banaction = nftables-f2b

# Parámetros genéricos de hardening
bantime  = 3600       ; 1 hora
findtime = 600        ; ventana de 10 minutos
maxretry = 5
destemail = root@localhost
sender   = fail2ban@localhost
mta      = sendmail

ignoreself = true
ignoreip   = 127.0.0.1/8 ::1

[sshd]
enabled  = true
port     = ssh
filter   = sshd
backend  = systemd
logpath  = auto
maxretry = 5
EOF

# --------------------------------------------------------
# 4) Reiniciar Fail2Ban y mostrar estado
# --------------------------------------------------------
echo "[+] Probando configuración de Fail2Ban..."
fail2ban-client -t

echo "[+] Reiniciando Fail2Ban..."
systemctl restart fail2ban

sleep 2

echo "[+] Estado de fail2ban:"
systemctl --no-pager status fail2ban || true

echo "[+] Estado del jail sshd:"
fail2ban-client status sshd || true

echo
echo "[OK] Fail2Ban + nftables (tabla inet f2b) configurados para proteger SSH."
echo "    - Comprueba IPs baneadas:   fail2ban-client status sshd"
echo "    - Comprueba sets en nft:    nft list table inet f2b"
