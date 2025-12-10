#!/usr/bin/env bash

step_00_packages() {
  log_step "[00] Instalando paquetes base para CIS Hardening"

  ########################################
  # 1) Paquetes base obligatorios
  ########################################
  local base_packages=(
    apparmor apparmor-utils
    auditd audispd-plugins
    chrony
    libpam-tmpdir
    libpam-pwquality
    nftables
    fail2ban
  )

  ########################################
  # 2) Detectar tipo de máquina y CPU
  ########################################
  local cpu_vendor="desconocido"
  if [[ -r /proc/cpuinfo ]]; then
    cpu_vendor=$(grep -m1 -i 'vendor_id' /proc/cpuinfo | awk '{print $3}')
  fi

  log_info "Vendor CPU detectado: ${cpu_vendor:-desconocido}"
  if [[ "${IS_VM:-0}" -eq 1 ]]; then
    log_info "Entorno detectado: VM (IS_VM=1), microcode NO se instalará automáticamente"
  else
    log_info "Entorno detectado: bare metal / sin virtualización (IS_VM=0)"
  fi

  ########################################
  # 3) Microcode (opcional, solo bare metal)
  ########################################
  local microcode_pkg=""
  if [[ "${IS_VM:-0}" -eq 0 ]]; then
    case "$cpu_vendor" in
      GenuineIntel)
        microcode_pkg="intel-microcode"
        ;;
      AuthenticAMD)
        microcode_pkg="amd64-microcode"
        ;;
      *)
        microcode_pkg=""
        ;;
    esac

    if [[ -n "$microcode_pkg" ]]; then
      if [[ "${NON_INTERACTIVE:-0}" -eq 1 ]]; then
        log_info "Modo non-interactive: NO se forzará instalación de microcode (${microcode_pkg})"
      else
        echo
        read -r -p "¿Instalar paquete de microcódigo ${microcode_pkg} (mitigaciones CPU, requiere non-free)? [y/N]: " ans
        case "$ans" in
          [yY]*)
            base_packages+=("$microcode_pkg")
            log_info "Microcode habilitado: ${microcode_pkg}"
            ;;
          *)
            log_info "Microcode omitido a petición del usuario."
            ;;
        esac
      fi
    else
      log_info "No se ha identificado un paquete de microcódigo compatible para vendor=${cpu_vendor}"
    fi
  fi

  ########################################
  # 4) Actualizar índice y calcular faltantes
  ########################################
  log_info "Actualizando índice de paquetes (apt-get update)..."
  DEBIAN_FRONTEND=noninteractive apt-get update -y >/dev/null

  local missing=()
  for pkg in "${base_packages[@]}"; do
    if ! dpkg -s "$pkg" >/dev/null 2>&1; then
      missing+=("$pkg")
    fi
  done

  if [[ ${#missing[@]} -eq 0 ]]; then
    log_info "Todos los paquetes requeridos ya están instalados."
    return 0
  fi

  log_info "Paquetes faltantes a instalar: ${missing[*]}"

  ########################################
  # 5) Instalación con manejo de errores
  ########################################
  if ! DEBIAN_FRONTEND=noninteractive apt-get install -y "${missing[@]}" >/dev/null 2>&1; then
    log_error "Error instalando paquetes: ${missing[*]}"
    log_error "Revisa /etc/apt/sources.list y los repositorios (especialmente 'non-free' para microcode)."
    exit 1
  fi

  log_info "✓ Paquetes instalados correctamente."
}
