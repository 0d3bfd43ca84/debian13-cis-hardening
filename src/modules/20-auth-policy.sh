#!/usr/bin/env bash

step_20_auth_policy() {
  log_step "[4/12] Configurando log dedicado de sudo..."

  SUDO_CIS_FILE="/etc/sudoers.d/01-cis-sudo-log"

  mkdir -p /etc/sudoers.d

  cat >"$SUDO_CIS_FILE" <<'EOF'
Defaults logfile="/var/log/sudo.log"
EOF

  chmod 440 "$SUDO_CIS_FILE"
  chown root:root "$SUDO_CIS_FILE"

  if ! visudo -cf /etc/sudoers >/dev/null 2>&1; then
    echo "ERROR: Configuración sudoers inválida tras añadir $SUDO_CIS_FILE." >&2
    exit 1
  fi

  touch /var/log/sudo.log
  chown root:root /var/log/sudo.log
  chmod 600 /var/log/sudo.log

  log_step "[4b/12] Reforzando política de contraseñas (pwquality + aging + umask + hashing rounds)..."

  COMMON_PASSWORD="/etc/pam.d/common-password"
  LOGIN_DEFS="/etc/login.defs"

  if [[ -f "$COMMON_PASSWORD" ]]; then
    if ! grep -q "pam_pwquality.so" "$COMMON_PASSWORD"; then
      sed -i '/pam_unix.so/i password   requisite   pam_pwquality.so retry=3 minlen=12 difok=3' "$COMMON_PASSWORD"
    fi

    if grep -q "pam_unix.so" "$COMMON_PASSWORD"; then
      if grep -q "sha512" "$COMMON_PASSWORD" && ! grep -q "rounds=" "$COMMON_PASSWORD"; then
        sed -i 's/\(pam_unix.so.*sha512\)/\1 rounds=100000/' "$COMMON_PASSWORD"
      fi
    fi
  fi

  if [[ -f "$LOGIN_DEFS" ]]; then
    sed -i 's/^PASS_MAX_DAYS.*/PASS_MAX_DAYS   180/' "$LOGIN_DEFS" || true
    sed -i 's/^PASS_MIN_DAYS.*/PASS_MIN_DAYS   1/'   "$LOGIN_DEFS" || true
    sed -i 's/^PASS_WARN_AGE.*/PASS_WARN_AGE   30/'  "$LOGIN_DEFS" || true
  fi

  UID_MIN=$(awk '/^UID_MIN/ {print $2}' /etc/login.defs 2>/dev/null || echo 1000)
  while IFS=: read -r name _ uid _ _ _ shell; do
    if (( uid >= UID_MIN )) && [[ "$shell" != "/usr/sbin/nologin" && "$shell" != "/bin/false" ]]; then
      chage --mindays 1 --maxdays 180 --warndays 30 "$name" 2>/dev/null || true
    fi
  done < /etc/passwd

  if [[ -f "$LOGIN_DEFS" ]]; then
    sed -i 's/^UMASK.*/UMASK 027/' "$LOGIN_DEFS" || true
  fi

  mkdir -p /etc/profile.d
  cat >/etc/profile.d/01-umask.sh <<'EOF'
umask 027
EOF
  chmod 644 /etc/profile.d/01-umask.sh
}
