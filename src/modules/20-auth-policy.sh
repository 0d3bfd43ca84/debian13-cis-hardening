#!/usr/bin/env bash

step_20_auth_policy() {
  log_step "[20] Configurando sudo logging y política de contraseñas..."

  local SUDO_CIS_FILE="/etc/sudoers.d/01-cis-sudo-log"
  local COMMON_PASSWORD="/etc/pam.d/common-password"
  local LOGIN_DEFS="/etc/login.defs"
  local UID_MIN

  # --- sudo logging -------------------------------------------------

  mkdir -p /etc/sudoers.d
  chown root:root /etc/sudoers.d
  chmod 750 /etc/sudoers.d

  # Backup si ya existía
  if [[ -f "$SUDO_CIS_FILE" ]]; then
    cp "$SUDO_CIS_FILE" "${SUDO_CIS_FILE}.bak.${timestamp}"
    echo "  -> Backup de ${SUDO_CIS_FILE} en ${SUDO_CIS_FILE}.bak.${timestamp}"
  fi

  cat >"$SUDO_CIS_FILE" <<'EOF'
Defaults logfile="/var/log/sudo.log"
EOF

  chmod 440 "$SUDO_CIS_FILE"
  chown root:root "$SUDO_CIS_FILE"

  # Validar sudoers; si falla, revertir y abortar
  if ! visudo -cf /etc/sudoers >/dev/null 2>&1; then
    echo "ERROR: Configuración sudoers inválida tras añadir $SUDO_CIS_FILE." >&2
    if [[ -f "${SUDO_CIS_FILE}.bak.${timestamp}" ]]; then
      mv "${SUDO_CIS_FILE}.bak.${timestamp}" "$SUDO_CIS_FILE"
      echo "  -> Restaurado ${SUDO_CIS_FILE} desde backup."
    else
      rm -f "$SUDO_CIS_FILE"
      echo "  -> Eliminado ${SUDO_CIS_FILE} para evitar dejar sudo roto."
    fi
    exit 1
  fi

  touch /var/log/sudo.log
  chown root:root /var/log/sudo.log
  chmod 600 /var/log/sudo.log

  echo "  -> Reforzando política de contraseñas (pwquality + aging + umask + hashing rounds)..."

  # --- pwquality + rounds -------------------------------------------

  if [[ -f "$COMMON_PASSWORD" ]]; then
    if ! grep -q "pam_pwquality.so" "$COMMON_PASSWORD"; then
      sed -i '/pam_unix\.so/i password   requisite   pam_pwquality.so retry=3 minlen=12 difok=3' "$COMMON_PASSWORD"
    fi

    if grep -q "pam_unix.so" "$COMMON_PASSWORD"; then
      if grep -q "sha512" "$COMMON_PASSWORD" && ! grep -q "rounds=" "$COMMON_PASSWORD"; then
        sed -i 's/\(pam_unix.so.*sha512\)/\1 rounds=100000/' "$COMMON_PASSWORD"
      fi
    fi
  fi

  # --- login.defs: PASS_* y UMASK -----------------------------------

  if [[ -f "$LOGIN_DEFS" ]]; then
    if grep -q "^PASS_MAX_DAYS" "$LOGIN_DEFS"; then
      sed -i 's/^PASS_MAX_DAYS.*/PASS_MAX_DAYS   180/' "$LOGIN_DEFS" || true
    else
      echo "PASS_MAX_DAYS   180" >> "$LOGIN_DEFS"
    fi

    if grep -q "^PASS_MIN_DAYS" "$LOGIN_DEFS"; then
      sed -i 's/^PASS_MIN_DAYS.*/PASS_MIN_DAYS   1/' "$LOGIN_DEFS" || true
    else
      echo "PASS_MIN_DAYS   1" >> "$LOGIN_DEFS"
    fi

    if grep -q "^PASS_WARN_AGE" "$LOGIN_DEFS"; then
      sed -i 's/^PASS_WARN_AGE.*/PASS_WARN_AGE   30/' "$LOGIN_DEFS" || true
    else
      echo "PASS_WARN_AGE   30" >> "$LOGIN_DEFS"
    fi

    if grep -q "^UMASK" "$LOGIN_DEFS"; then
      sed -i 's/^UMASK.*/UMASK 027/' "$LOGIN_DEFS" || true
    else
      echo "UMASK 027" >> "$LOGIN_DEFS"
    fi
  fi

  # --- aging real en cuentas de usuario -----------------------------

  UID_MIN=$(awk '/^UID_MIN/ {print $2}' /etc/login.defs 2>/dev/null || echo 1000)
  while IFS=: read -r name _ uid _ _ _ shell; do
    if (( uid >= UID_MIN )) && [[ "$shell" != "/usr/sbin/nologin" && "$shell" != "/bin/false" ]]; then
      chage --mindays 1 --maxdays 180 --warndays 30 "$name" 2>/dev/null || true
    fi
  done < /etc/passwd

  # --- umask global -------------------------------------------------

  mkdir -p /etc/profile.d
  cat >/etc/profile.d/01-umask.sh <<'EOF'
umask 027
EOF
  chmod 644 /etc/profile.d/01-umask.sh
}
