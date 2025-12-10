#!/usr/bin/env bash

step_90_services_and_finalize() {
  log_step "[90] Deshabilitando servicios innecesarios y finalizando hardening..."

  local SERVICES_TO_MASK=(
    "cups:Impresión local"
    "avahi-daemon:MDNS/Zeroconf"
    "bluetooth:Bluetooth"
    "rpcbind:RPC legacy"
    "systemd-resolved:Stub resolver (solo si no se usa)"
  )

  _mask_service() {
    local svc="$1"
    local desc="$2"

    if ! systemctl list-unit-files "${svc}.service" >/dev/null 2>&1; then
      log_info "Servicio ${svc}.service no existe en este sistema"
      return
    fi

    # Si modo interactivo está desactivado, se aplica siempre
    if [[ "${NON_INTERACTIVE:-0}" -eq 1 ]]; then
      log_info "Deshabilitando ${svc}.service (${desc}) [modo non-interactive]"
      systemctl disable --now "${svc}.service" >/dev/null 2>&1 || true
      systemctl mask "${svc}.service" >/dev/null 2>&1 || true
      return
    fi

    # Modo interactivo
    read -r -p "¿Maskear ${svc}.service (${desc})? [y/N]: " ans
    case "$ans" in
      [yY]*)
        systemctl disable --now "${svc}.service" >/dev/null 2>&1 || true
        systemctl mask "${svc}.service" >/dev/null 2>&1 || true
        log_info "${svc}.service deshabilitado y maskeado"
        ;;
      *)
        log_info "${svc}.service se mantiene activo"
        ;;
    esac
  }

  # Aplicar reglas sobre cada servicio
  for entry in "${SERVICES_TO_MASK[@]}"; do
    local svc="${entry%%:*}"
    local desc="${entry#*:}"
    _mask_service "$svc" "$desc"
  done

  # Cambiar target por defecto
  log_step "[Final] Estableciendo multi-user.target como objetivo por defecto"
  local CURRENT_TARGET
  CURRENT_TARGET=$(systemctl get-default 2>/dev/null || echo "unknown")
  log_info "Target actual: ${CURRENT_TARGET}"

  if systemctl set-default multi-user.target >/dev/null 2>&1; then
    log_info "✓ multi-user.target aplicado"
  else
    log_warn "No se pudo aplicar multi-user.target"
  fi

  # Reiniciar auditd
  log_step "Asegurando auditd"
  systemctl enable auditd >/dev/null 2>&1 || true
  systemctl restart auditd >/dev/null 2>&1 || log_warn "No se pudo reiniciar auditd"

  # Verificación rápida de activación
  if auditctl -s >/dev/null 2>&1; then
    log_info "✓ auditd activo y respondiendo"
  else
    log_warn "⚠ auditd NO está respondiendo (revisar reglas o conflictos)"
  fi

  # Resumen final ordenado
  log_step "Hardening finalizado — resumen:"
  cat <<EOF
  -----------------------------------------------
   HARDENING APLICADO (Debian 13 CIS + extras)
  -----------------------------------------------
   ✔ Kernel cmdline (AppArmor + audit)
   ✔ Módulos kernel bloqueados
   ✔ Logging sudo dedicado
   ✔ Política de contraseñas (pwquality, aging)
   ✔ auditd.conf + reglas CIS
   ✔ Permisos críticos (ssh, cron, sudoers)
   ✔ sysctl hardening (CIS + Lynis + extra)
   ✔ nftables endurecido (IPv6 DROP opcional)
   ✔ SSH crypto moderna
   ✔ Chrony NTS endurecido
   ✔ Default target: multi-user.target
   ✔ Servicios opcionales deshabilitados
  -----------------------------------------------
EOF

  # Preguntar reboot solo si interactivo
  if [[ "${NON_INTERACTIVE:-0}" -ne 1 ]]; then
    read -r -p "¿Reiniciar ahora para aplicar todos los cambios de kernel/grub/sysctl? [y/N]: " reboot_ans
    case "$reboot_ans" in
      [yY]*)
        reboot
        ;;
      *)
        log_info "Reinicio pendiente. Ejecuta 'reboot' cuando te convenga."
        ;;
    esac
  else
    log_info "Reinicio no realizado (modo non-interactive)."
  fi
}
