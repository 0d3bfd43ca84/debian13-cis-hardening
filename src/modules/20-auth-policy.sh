#!/usr/bin/env bash

step_20_auth_policy() {
  log_step "[20] Configurando política de autenticación (sudo, PAM, aging, umask)"

  local SUDO_CIS_FILE="/etc/sudoers.d/01-cis-sudo-log"
  local COMMON_PASSWORD="/etc/pam.d/common-password"
  local LOGIN_DEFS="/etc/login.defs"

  ############################################################
  # 1) Log dedicado para sudo
  ############################################################
  log_info "Configurando log dedicado de sudo en /var/log/sudo.log"

  mkdir -p /etc/sudoers.d

  cat >"$SUDO_CIS_FILE" <<'EOF'
Defaults logfile="/var/log/sudo.log"
EOF

  chmod 440 "$SUDO_CIS_FILE"
  chown root:root "$SUDO_CIS_FILE"

  if ! visudo -cf /etc/sudoers >/dev/null 2>&1; then
    log_error "Configuración sudoers inválida tras añadir $SUDO_CIS_FILE"
    exit 1
  fi

  touch /var/log/sudo.log
  chown root:root /var/log/sudo.log
  chmod 600 /var/log/sudo.log

  ############################################################
  # 2) PAM: pwquality + hashing
  ############################################################
  if [[ -f "$COMMON_PASSWORD" ]]; then
    log_info "Endureciendo /etc/pam.d/common-password"

    # 2.1 pwquality: forzamos línea con retry=3 minlen=12 difok=3
    if grep -q "pam_pwquality.so" "$COMMON_PASSWORD"; then
      # Reemplaza la línea completa (Debian 13 default encaja bien aquí)
      sed -i -E 's|^password[[:space:]]+requisite[[:space:]]+pam_pwquality\.so.*|password        requisite                       pam_pwquality.so retry=3 minlen=12 difok=3|' "$COMMON_PASSWORD"
      log_info "Línea pam_pwquality.so ajustada (retry=3 minlen=12 difok=3)"
    else
      sed -i '/pam_unix.so/i password        requisite                       pam_pwquality.so retry=3 minlen=12 difok=3' "$COMMON_PASSWORD"
      log_info "Línea pam_pwquality.so insertada antes de pam_unix.so"
    fi

    # 2.2 Hashing: gestionar sha512 vs yescrypt
    if grep -q "pam_unix.so" "$COMMON_PASSWORD"; then
      if grep -q "pam_unix.so.*sha512" "$COMMON_PASSWORD"; then
        # Solo si usa sha512 y no hay rounds
        if ! grep -q "pam_unix.so.*rounds=" "$COMMON_PASSWORD"; then
          sed -i 's/\(pam_unix\.so.*sha512\)/\1 rounds=100000/' "$COMMON_PASSWORD"
          log_info "Añadido rounds=100000 a pam_unix.so (sha512)"
        else
          log_info "pam_unix.so (sha512) ya tiene parámetro rounds, no se toca"
        fi
      elif grep -q "pam_unix.so.*yescrypt" "$COMMON_PASSWORD"; then
        # Debian 13: yescrypt por defecto → no aplican rounds
        log_info "Detectado yescrypt en pam_unix.so; no se aplican rounds (no aplica a yescrypt)"
      else
        log_warn "pam_unix.so usa un esquema de hash no esperado (ni sha512 ni yescrypt). Revisa manualmente."
      fi
    fi
  else
    log_warn "No se encontró $COMMON_PASSWORD; no se aplica hardening PAM."
  fi

  ############################################################
  # 3) Password aging por defecto
  ############################################################
  if [[ -f "$LOGIN_DEFS" ]]; then
    log_info "Ajustando PASS_MAX_DAYS / PASS_MIN_DAYS / PASS_WARN_AGE en $LOGIN_DEFS"

    sed -i 's/^PASS_MAX_DAYS.*/PASS_MAX_DAYS   180/' "$LOGIN_DEFS" || true
    sed -i 's/^PASS_MIN_DAYS.*/PASS_MIN_DAYS   1/'   "$LOGIN_DEFS" || true
    sed -i 's/^PASS_WARN_AGE.*/PASS_WARN_AGE   30/'  "$LOGIN_DEFS" || true
  else
    log_warn "No se encontró $LOGIN_DEFS; no se ajusta password aging global."
  fi

  # Ajustar aging en usuarios reales (UID >= UID_MIN, shell de login)
  local UID_MIN
  UID_MIN=$(awk '/^UID_MIN/ {print $2}' /etc/login.defs 2>/dev/null || echo 1000)

  while IFS=: read -r name _ uid _ _ _ shell; do
    if (( uid >= UID_MIN )) && [[ "$shell" != "/usr/sbin/nologin" && "$shell" != "/bin/false" ]]; then
      chage --mindays 1 --maxdays 180 --warndays 30 "$name" 2>/dev/null || true
    fi
  done < /etc/passwd

  ############################################################
  # 4) Default umask
  ############################################################
  if [[ -f "$LOGIN_DEFS" ]]; then
    sed -i 's/^UMASK.*/UMASK 027/' "$LOGIN_DEFS" || true
  fi

  mkdir -p /etc/profile.d
  cat >/etc/profile.d/01-umask.sh <<'EOF'
umask 027
EOF
  chmod 644 /etc/profile.d/01-umask.sh

  log_info "Política de autenticación aplicada (sudo log, pwquality, aging, umask)"
}
