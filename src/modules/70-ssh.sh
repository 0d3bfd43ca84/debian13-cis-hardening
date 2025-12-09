#!/usr/bin/env bash

step_70_ssh() {
  log_step "[10/12] Endureciendo configuración de SSH (crypto moderna)..."

  SSHD_CONF="/etc/ssh/sshd_config"
  if [[ -f "$SSHD_CONF" ]]; then
    echo "  -> Backup de ${SSHD_CONF} en ${SSHD_CONF}.bak.${timestamp}"
    cp "$SSHD_CONF" "${SSHD_CONF}.bak.${timestamp}"

    sed -i '/^Ciphers /d;/^MACs /d;/^KexAlgorithms /d;/^Protocol /d' "$SSHD_CONF"

    cat >>"$SSHD_CONF" <<'EOF'

# ==== SSH CRYPTO HARDENED (debian13-cis-hardening.sh) ====
Protocol 2
KexAlgorithms sntrup761x25519-sha512@openssh.com,curve25519-sha256@libssh.org,curve25519-sha256
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes256-ctr
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com
EOF

    systemctl restart ssh || systemctl restart sshd || true
  else
    echo "WARN: No se encontró ${SSHD_CONF}, no se aplica hardening SSH." >&2
  fi
}
