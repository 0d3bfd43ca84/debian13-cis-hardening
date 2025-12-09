#!/usr/bin/env bash

step_90_services_and_finalize() {
  echo
  echo "[Extra] Opcional: deshabilitar y maskear servicios poco deseables en servidor..."

  mask_service() {
    local svc="$1"
    local desc="$2"

    if systemctl list-unit-files "${svc}.service" >/dev/null 2>&1; then
      read -r -p "¿Maskear ${svc}.service (${desc})? [y/N]: " ans
      case "$ans" in
        [yY]*)
          systemctl disable --now "${svc}.service" >/dev/null 2>&1 || true
          systemctl mask "${svc}.service" >/dev/null 2>&1 || true
          echo "  -> ${svc}.service deshabilitado y maskeado."
          ;;
        *)
          echo "  -> ${svc}.service se mantiene activo."
          ;;
      esac
    fi
  }

  mask_service "cups"             "impresión local"
  mask_service "avahi-daemon"     "mDNS/zeroconf (descubrimiento en LAN)"
  mask_service "bluetooth"        "Bluetooth"
  mask_service "rpcbind"          "RPC legacy (NFS antiguo, etc.)"
  mask_service "systemd-resolved" "stub DNS local (solo si NO lo usas como resolver)"

  echo
  echo "[Final] Estableciendo multi-user.target como objetivo por defecto (runlevel 3)..."
  if command -v systemctl >/dev/null 2>&1; then
    systemctl set-default multi-user.target >/dev/null
  fi

  echo "[Final] Reiniciando/asegurando auditd..."
  systemctl enable auditd >/dev/null 2>&1 || true
  systemctl restart auditd || true

  echo
  echo "==========================================="
  echo " Hardening base CIS + Lynis aplicado."
  echo " - Kernel cmdline: AppArmor + audit"
  echo " - Módulos kernel bloqueados (cis-kernel-hardening.conf)"
  echo " - sudo: log en /var/log/sudo.log"
  echo " - pwquality + password aging + umask + hashing rounds"
  echo " - auditd.conf + reglas CIS en /etc/audit/rules.d/"
  echo " - Permisos sshd_config, cron*, sudoers.d"
  echo " - sysctl hardening aplicado (Lynis + extra PCI/ISO-like)"
  echo " - nftables base aplicado (IPv6 DROP, solo SSH abierto)"
  echo " - SSH crypto endurecido (Kex/Ciphers/MACs modernos)"
  echo " - Chrony NTS endurecido"
  echo " - Default target: multi-user.target"
  echo " - Servicios opcionales deshabilitados según respuestas"
  echo "==========================================="
  echo

  read -r -p "¿Reiniciar ahora para aplicar todos los cambios de kernel/grub/sysctl? [y/N]: " reboot_ans
  case "$reboot_ans" in
    [yY]*)
      reboot
      ;;
    *)
      echo "Reinicio pendiente. Ejecuta 'reboot' manualmente cuando te convenga."
      ;;
  esac
}
