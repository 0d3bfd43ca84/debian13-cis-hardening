#!/usr/bin/env bash
#
# debian13-cis-hardening.sh
# Launcher / orquestador del framework de hardening CIS + extras para Debian 13.
#
# Uso básico:
#   sudo ./debian13-cis-hardening.sh
#
# Opciones:
#   --non-interactive, -y   Ejecuta sin preguntas (asume "yes" donde aplique)
#   --dry-run               No ejecuta cambios, solo muestra qué pasos se lanzarían
#   --only STEP             Ejecuta solo un paso (ej: --only step_60_nftables)
#   --list-steps            Lista los pasos disponibles y sale
#
# Requiere:
#   - Debian 13 (Trixie) o derivado
#   - Ejecución como root

set -euo pipefail

#######################################
# Utilidades de logging
#######################################
log_step() {
  echo
  echo "[+] $1"
}

log_info() {
  echo "    [*] $1"
}

log_warn() {
  echo "    [!] $1" >&2
}

log_error() {
  echo "    [ERROR] $1" >&2
}

#######################################
# Manejo de errores global
#######################################
trap 'log_error "Fallo en la línea $LINENO. Revisa la salida anterior."; exit 1' ERR

#######################################
# Variables globales
#######################################
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULES_DIR="${SCRIPT_DIR}/src/modules"

timestamp="$(date +%Y%m%d-%H%M%S)"
NON_INTERACTIVE=0
DRY_RUN=0
ONLY_STEP=""

IS_VM=0   # Se rellena más abajo

#######################################
# Comprobaciones iniciales
#######################################
check_root() {
  if [[ "$(id -u)" -ne 0 ]]; then
    log_error "Este script debe ejecutarse como root."
    exit 1
  fi
}

check_debian_version() {
  if [[ -f /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    local name="${NAME:-}"
    local version_id="${VERSION_ID:-}"

    if [[ "$name" != "Debian GNU/Linux" && "$name" != "Debian" ]]; then
      log_warn "Sistema no identificado como Debian. NAME=${name:-desconocido}."
    fi

    if [[ "${version_id}" != "13" ]]; then
      log_warn "Este hardening está pensado para Debian 13. VERSION_ID=${version_id:-desconocida}."
    fi
  else
    log_warn "/etc/os-release no encontrado; no se puede verificar versión de Debian."
  fi
}

detect_virtualization() {
  if command -v systemd-detect-virt >/dev/null 2>&1 && systemd-detect-virt -q; then
    IS_VM=1
    log_info "Entorno detectado: Máquina virtual (IS_VM=1)"
  else
    IS_VM=0
    log_info "Entorno detectado: Bare metal o sin virtualización detectable (IS_VM=0)"
  fi
}

#######################################
# Argument parsing
#######################################
print_usage() {
  cat <<EOF
Uso: sudo $(basename "$0") [opciones]

Opciones:
  --non-interactive, -y   Ejecuta sin preguntas (asume "yes" donde aplique)
  --dry-run               No ejecuta cambios, solo muestra qué pasos se lanzarían
  --only STEP             Ejecuta solo el paso indicado (ej: --only step_60_nftables)
  --list-steps            Lista los pasos disponibles y sale
  -h, --help              Muestra esta ayuda

Ejemplos:
  sudo $(basename "$0")
  sudo $(basename "$0") --non-interactive
  sudo $(basename "$0") --dry-run
  sudo $(basename "$0") --only step_60_nftables
EOF
}

LIST_STEPS_ONLY=0

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --non-interactive|-y)
        NON_INTERACTIVE=1
        shift
        ;;
      --dry-run)
        DRY_RUN=1
        shift
        ;;
      --only)
        shift
        if [[ $# -eq 0 ]]; then
          log_error "--only requiere un nombre de step (ej: step_60_nftables)."
          exit 1
        fi
        ONLY_STEP="$1"
        shift
        ;;
      --only=*)
        ONLY_STEP="${1#*=}"
        shift
        ;;
      --list-steps)
        LIST_STEPS_ONLY=1
        shift
        ;;
      -h|--help)
        print_usage
        exit 0
        ;;
      *)
        log_warn "Opción desconocida: $1"
        print_usage
        exit 1
        ;;
    esac
  done
}

#######################################
# Carga de módulos
#######################################
load_modules() {
  if [[ ! -d "$MODULES_DIR" ]]; then
    log_error "Directorio de módulos no encontrado: ${MODULES_DIR}"
    exit 1
  fi

  log_step "Cargando módulos desde ${MODULES_DIR}..."

  # Cargamos en orden numérico: 00-, 10-, 20-, ...
  local f
  shopt -s nullglob
  for f in "${MODULES_DIR}"/[0-9][0-9]-*.sh; do
    # shellcheck source=/dev/null
    source "$f"
    log_info "Módulo cargado: $(basename "$f")"
  done
  shopt -u nullglob
}

#######################################
# Definición del pipeline de pasos
#######################################
# Asegúrate de que estos nombres coinciden con las funciones definidas
# en tus módulos (step_00_packages, step_10_kernel_cmdline_and_modprobe, etc.)
STEPS=(
  "step_00_packages"
  "step_10_kernel_cmdline_and_modprobe"
  "step_20_auth_policy"
  "step_30_auditd"
  "step_40_file_perms"
  "step_50_sysctl"
  "step_60_nftables"
  "step_65_fail2ban"
  "step_70_ssh"
  "step_80_chrony"
  "step_90_services_and_finalize"
)

list_steps() {
  echo "Pasos disponibles (en orden de ejecución):"
  for s in "${STEPS[@]}"; do
    echo "  - $s"
  done
}

#######################################
# Ejecución de pasos
#######################################
run_steps() {
  log_step "Iniciando pipeline de hardening CIS para Debian 13..."

  for step in "${STEPS[@]}"; do
    # Si se especificó --only, saltar el resto
    if [[ -n "$ONLY_STEP" && "$step" != "$ONLY_STEP" ]]; then
      continue
    fi

    # Verificar que la función existe
    if ! declare -F "$step" >/dev/null 2>&1; then
      log_warn "Step definido en pipeline pero no encontrado como función: $step"
      continue
    fi

    if [[ "$DRY_RUN" -eq 1 ]]; then
      log_info "[DRY-RUN] Se omite ejecución de: $step"
      continue
    fi

    log_step "Ejecutando: $step"
    "$step"
  done

  log_step "Pipeline de hardening completado."
}

#######################################
# Banner
#######################################
print_banner() {
  cat <<'EOF'
==========================================================
  Debian 13 Hardening – CIS Level 2 + Extras (Server)
  Production-grade baseline (Lynis-friendly, NTS, nftables)
==========================================================
EOF
}

#######################################
# MAIN
#######################################
main() {
  print_banner
  parse_args "$@"
  check_root
  check_debian_version
  detect_virtualization
  load_modules

  if [[ "$LIST_STEPS_ONLY" -eq 1 ]]; then
    list_steps
    exit 0
  fi

  if [[ "$DRY_RUN" -eq 1 ]]; then
    log_warn "Modo DRY-RUN activo: no se aplicarán cambios, solo se mostrarán los pasos."
  fi

  if [[ "$NON_INTERACTIVE" -eq 1 ]]; then
    log_info "Modo NON-INTERACTIVE activo: se minimizarán las preguntas."
  fi

  run_steps

  if [[ "$DRY_RUN" -eq 1 ]]; then
    log_info "DRY-RUN finalizado. No se han aplicado cambios reales."
  fi
}

main "$@"
