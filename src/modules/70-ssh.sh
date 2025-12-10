#!/usr/bin/env bash

step_70_ssh() {
  log_step "[70] Endureciendo configuración de SSH (crypto moderna)..."

  local SSHD_CONF="/etc/ssh/sshd_config"
  local BACKUP_FILE="${SSHD_CONF}.bak.${timestamp}"

  if [[ ! -f "$SSHD_CONF" ]]; then
    echo "WARN: No se encontró ${SSHD_CONF}, no se aplica hardening SSH." >&2
    return 0
  fi

  echo "  -> Backup de ${SSHD_CONF} en ${BACKUP_FILE}"
  cp "$SSHD_CONF" "$BACKUP_FILE"

  # Asegurar permisos mínimos (CIS)
  chown root:root "$SSHD_CONF"
  chmod 600 "$SSHD_CONF"

  # Limpiar bloque anterior (idempotencia)
  sed -i '/^# ==== SSH CRYPTO HARDENED (debian13-cis-hardening.sh) ====/{:a;N;/^$/!ba;d}' "$SSHD_CONF" || true

  # Eliminar posibles líneas legacy
  sed -i '/^Ciphers /d;/^MACs /d;/^KexAlgorithms /d;/^Protocol /d' "$SSHD_CONF"

  # Añadir bloque endurecido
  cat >> "$SSHD_CONF" <<'EOF'

# ==== SSH CRYPTO HARDENED (debian13-cis-hardening.sh) ====
Protocol 2
KexAlgorithms sntrup761x25519-sha512@openssh.com,curve25519-sha256@libssh.org,curve25519-sha256
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes256-ctr
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com

EOF

  # Validar la configuración ANTES de reiniciar
  echo "  -> Validando configuración con sshd -t..."
  if ! sshd -t -f "$SSHD_CONF" >/dev/null 2>&1; then
    echo "ERROR: La configuración SSH no es válida. Restaurando backup..." >&2
    mv "$BACKUP_FILE" "$SSHD_CONF"
    return 1
  fi

  # Reiniciar servicio
  echo "  -> Reiniciando SSH..."
  if ! systemctl restart ssh >/dev/null 2>&1; then
    systemctl restart sshd >/dev/null 2>&1 || echo "WARN: No se pudo reiniciar ssh/sshd" >&2
  fi
}
