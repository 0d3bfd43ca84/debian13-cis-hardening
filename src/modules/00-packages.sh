#!/usr/bin/env bash

step_00_packages() {
  log_step "[00] Instalando paquetes base para CIS Hardening"

  # Lista de paquetes obligatorios siempre instalados
  local packages=(
    apparmor apparmor-utils
    auditd audispd-plugins
    chrony
    libpam-tmpdir
    libpam-pwquality
    nftables
    fail2ban
  )

  # Paquetes recomendados solo para bare-metal
  if [[ "${IS_VM:-0}" -eq 0 ]]; then
    packages+=(intel-microcode amd64-microcode)
    log_info "Modo bare-metal: microcode habilitado"
  else
    log_info "Modo VM: omitiendo paquetes de microcode"
  fi

  log_info "Paquetes a instalar: ${packages[*]}"

  DEBIAN_FRONTEND=noninteractive apt-get update -y >/dev/null

  # Instalación idempotente: solo instalar si faltan
  local missing=()
  for pkg in "${packages[@]}"; do
    if ! dpkg -s "$pkg" >/dev/null 2>&1; then
      missing+=("$pkg")
    fi
  done

  if [[ ${#missing[@]} -eq 0 ]]; then
    log_info "Todos los paquetes ya están instalados"
    return 0
  fi

  log_info "Instalando paquetes faltantes: ${missing[*]}"

  if ! DEBIAN_FRONTEND=noninteractive apt-get install -y "${missing[@]}" >/dev/null 2>&1; then
    log_error "Error instalando paquetes: ${missing[*]}"
    exit 1
  fi

  log_info "✓ Paquetes instalados correctamente"
}
