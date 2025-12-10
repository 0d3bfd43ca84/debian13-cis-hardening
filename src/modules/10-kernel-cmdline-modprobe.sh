#!/usr/bin/env bash

step_10_kernel_cmdline_and_modprobe() {
  log_step "[10] Configurando kernel cmdline y módulos"

  local GRUB_DEFAULT_FILE="/etc/default/grub"

  if [[ ! -f "$GRUB_DEFAULT_FILE" ]]; then
    log_error "No existe $GRUB_DEFAULT_FILE, abortando."
    exit 1
  fi

  # Backup antes de modificar
  cp "$GRUB_DEFAULT_FILE" "${GRUB_DEFAULT_FILE}.bak.${timestamp}"
  log_info "Backup de ${GRUB_DEFAULT_FILE} en ${GRUB_DEFAULT_FILE}.bak.${timestamp}"

  # Obtener valor actual de cmdline sin hacer source (más seguro)
  local CURRENT_CMDLINE
  CURRENT_CMDLINE=$(grep -E '^GRUB_CMDLINE_LINUX=' "$GRUB_DEFAULT_FILE" | cut -d'"' -f2)
  local NEW_CMDLINE="$CURRENT_CMDLINE"

  # Parámetros mínimos necesarios
  local REQUIRED_PARAMS=(
    "apparmor=1"
    "security=apparmor"
    "audit=1"
    "audit_backlog_limit=8192"
  )

  local p name
  for p in "${REQUIRED_PARAMS[@]}"; do
    name="${p%%=*}"

    # Eliminar valor previo (name=algo)
    NEW_CMDLINE="$(echo " ${NEW_CMDLINE} " | sed -E "s/ ${name}=[^ ]*//g")"

    # Asegurar que no está ya como "flag" sin valor
    NEW_CMDLINE="$(echo " ${NEW_CMDLINE} " | sed -E "s/ ${name}( |$)//g")"

    # Añadir el valor correcto
    NEW_CMDLINE="${NEW_CMDLINE} ${p}"
  done

  NEW_CMDLINE="$(echo "$NEW_CMDLINE" | xargs || true)"

  # Escribir nueva línea GRUB_CMDLINE_LINUX
  if grep -qE '^GRUB_CMDLINE_LINUX=' "$GRUB_DEFAULT_FILE"; then
    sed -i "s|^GRUB_CMDLINE_LINUX=.*|GRUB_CMDLINE_LINUX=\"${NEW_CMDLINE}\"|" "$GRUB_DEFAULT_FILE"
  else
    echo "GRUB_CMDLINE_LINUX=\"${NEW_CMDLINE}\"" >> "$GRUB_DEFAULT_FILE"
  fi

  log_info "GRUB_CMDLINE_LINUX=\"${NEW_CMDLINE}\""

  log_info "Actualizando configuración de GRUB..."
  if command -v update-grub >/dev/null 2>&1; then
    update-grub >/dev/null
  elif command -v grub-mkconfig >/dev/null 2>&1; then
    grub-mkconfig -o /boot/grub/grub.cfg >/dev/null
  else
    log_warn "Ni update-grub ni grub-mkconfig disponibles; revisa GRUB manualmente."
  fi

  # Permisos CIS
  if [[ -f /boot/grub/grub.cfg ]]; then
    log_info "Ajustando permisos de /boot/grub/grub.cfg"
    chown root:root /boot/grub/grub.cfg
    chmod 600 /boot/grub/grub.cfg
  fi

  log_info "Creando /etc/modprobe.d/cis-kernel-hardening.conf..."

  cat >/etc/modprobe.d/cis-kernel-hardening.conf <<'EOF'
########################################################################
# CIS KERNEL HARDENING — DEBIAN
...
EOF

  chown root:root /etc/modprobe.d/cis-kernel-hardening.conf
  chmod 600 /etc/modprobe.d/cis-kernel-hardening.conf

  log_info "Actualizando initramfs..."
  if command -v update-initramfs >/dev/null 2>&1; then
    update-initramfs -u >/dev/null
  else
    log_warn "update-initramfs no disponible; revisa initramfs manualmente."
  fi
}
