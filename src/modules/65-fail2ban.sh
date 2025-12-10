#!/usr/bin/env bash

step_65_fail2ban() {
  log_step "[65] Configurando Fail2Ban + nftables (protección SSH)..."

  local NFT_MAIN_CONF="/etc/nftables.conf"
  local NFT_F2B_CONF="/etc/nftables-f2b.conf"
  local F2B_ACTION_DIR="/etc/fail2ban/action.d"
  local F2B_ACTION_FILE="${F2B_ACTION_DIR}/nftables-f2b.local"
  local F2B_JAIL_LOCAL="/etc/fail2ban/jail.local"

  # ------------------------------------------------------------------
  # 1) Integración nftables: tabla inet f2b + include
  # ------------------------------------------------------------------
  if [[ ! -f "$NFT_MAIN_CONF" ]]; then
    echo "WARN: $NFT_MAIN_CONF no existe; ejecuta primero el módulo 60-nftables." >&2
  else
    # Backup de nftables.conf
    cp "${NFT_MAIN_CONF}" "${NFT_MAIN_CONF}.bak.${timestamp}"
    echo "  -> Backup de ${NFT_MAIN_CONF} -> ${NFT_MAIN_CONF}.bak.${timestamp}"

    # Tabla inet f2b con sets de blacklist
    cat > "${NFT_F2B_CONF}" << 'EOF'
table inet f2b {
    # IPs baneadas por Fail2Ban (IPv4)
    set blacklist_v4 {
        type ipv4_addr
        flags timeout
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

    chown root:root "$NFT_F2B_CONF"
    chmod 600 "$NFT_F2B_CONF"

    # Asegurar include en nftables.conf (una sola vez)
    if ! grep -q 'nftables-f2b.conf' "${NFT_MAIN_CONF}"; then
      {
        echo ''
        echo '# Fail2Ban blacklist (SSH, etc.)'
        echo 'include "/etc/nftables-f2b.conf"'
      } >> "${NFT_MAIN_CONF}"
    fi

    echo "  -> Validando configuración de nftables (con inet f2b)..."
    if ! nft -c -f "${NFT_MAIN_CONF}" >/dev/null 2>&1; then
      echo "ERROR: Configuración de nftables inválida tras añadir inet f2b. Restaurando backup..." >&2
      mv "${NFT_MAIN_CONF}.bak.${timestamp}" "${NFT_MAIN_CONF}"
      rm -f "${NFT_F2B_CONF}"
      return 1
    fi

    echo "  -> Recargando nftables con la nueva tabla inet f2b..."
    if ! nft -f "${NFT_MAIN_CONF}" >/dev/null 2>&1; then
      echo "WARN: No se pudo recargar nftables; revisa 'journalctl -u nftables'." >&2
    fi

    echo "  -> Estado de la tabla inet f2b:"
    nft list table inet f2b || echo "  [!] No se pudo listar inet f2b (revisa errores de nft)."
  fi

  # ------------------------------------------------------------------
  # 2) Fail2Ban: acción personalizada nftables-f2b
  # ------------------------------------------------------------------
  mkdir -p "${F2B_ACTION_DIR}"
  chown root:root "${F2B_ACTION_DIR}"
  chmod 750 "${F2B_ACTION_DIR}"

  if [[ -f "${F2B_ACTION_FILE}" ]]; then
    cp "${F2B_ACTION_FILE}" "${F2B_ACTION_FILE}.bak.${timestamp}"
    echo "  -> Backup de ${F2B_ACTION_FILE} -> ${F2B_ACTION_FILE}.bak.${timestamp}"
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

  chown root:root "${F2B_ACTION_FILE}"
  chmod 640 "${F2B_ACTION_FILE}"

  # ------------------------------------------------------------------
  # 3) Fail2Ban: jail.local endurecido para SSH
  # ------------------------------------------------------------------
  mkdir -p /etc/fail2ban
  chown root:root /etc/fail2ban
  chmod 755 /etc/fail2ban

  if [[ -f "${F2B_JAIL_LOCAL}" ]]; then
    cp "${F2B_JAIL_LOCAL}" "${F2B_JAIL_LOCAL}.bak.${timestamp}"
    echo "  -> Backup de ${F2B_JAIL_LOCAL} -> ${F2B_JAIL_LOCAL}.bak.${timestamp}"
  fi

  cat > "${F2B_JAIL_LOCAL}" << 'EOF'
# jail.local – configuración endurecida mínima para SSH con nftables
# backend = systemd → usa journald (sin parsear ficheros de log)
# banaction = nftables-f2b → acción definida en action.d/nftables-f2b.local

[DEFAULT]
backend   = systemd
banaction = nftables-f2b

# Parámetros genéricos de hardening
bantime   = 3600       ; 1 hora
findtime  = 600        ; ventana de 10 minutos
maxretry  = 5
destemail = root@localhost
sender    = fail2ban@localhost
mta       = sendmail

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

  chown root:root "${F2B_JAIL_LOCAL}"
  chmod 640 "${F2B_JAIL_LOCAL}"

  # ------------------------------------------------------------------
  # 4) Validar y arrancar Fail2Ban
  # ------------------------------------------------------------------
  if ! command -v fail2ban-client >/dev/null 2>&1; then
    echo "WARN: fail2ban-client no está disponible; ¿está instalado Fail2Ban?" >&2
    return 1
  fi

  echo "  -> Probando configuración de Fail2Ban..."
  if ! fail2ban-client -t; then
    echo "ERROR: Configuración de Fail2Ban inválida. Restaurando backups..." >&2

    if [[ -f "${F2B_ACTION_FILE}.bak.${timestamp}" ]]; then
      mv "${F2B_ACTION_FILE}.bak.${timestamp}" "${F2B_ACTION_FILE}"
      echo "  -> Restaurado ${F2B_ACTION_FILE} desde backup."
    fi

    if [[ -f "${F2B_JAIL_LOCAL}.bak.${timestamp}" ]]; then
      mv "${F2B_JAIL_LOCAL}.bak.${timestamp}" "${F2B_JAIL_LOCAL}"
      echo "  -> Restaurado ${F2B_JAIL_LOCAL} desde backup."
    fi

    return 1
  fi

  echo "  -> Habilitando y reiniciando Fail2Ban..."
  systemctl enable fail2ban >/dev/null 2>&1 || true
  systemctl restart fail2ban || true

  sleep 2

  echo "  -> Estado de fail2ban:"
  systemctl --no-pager status fail2ban || true

  echo "  -> Estado del jail sshd:"
  fail2ban-client status sshd || true

  echo
  echo "  [OK] Fail2Ban + nftables (tabla inet f2b) configurados para proteger SSH."
  echo "       - IPs baneadas:   fail2ban-client status sshd"
  echo "       - Sets en nft:    nft list table inet f2b"
}
