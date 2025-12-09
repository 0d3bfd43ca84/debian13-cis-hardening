#!/usr/bin/env bash
#
# debian13-cis-hardening.sh
# Hardening base CIS Level 2 + Lynis para Debian 13:
# - AppArmor + auditd + kernel cmdline
# - Blacklist módulos kernel no usados
# - sudo logging
# - pwquality + password aging + umask
# - auditd.conf + reglas CIS
# - permisos sshd/cron/sudoers.d
# - sysctl hardening (Lynis + extra PCI/ISO-like)
# - nftables firewall base (IPv6 DROP, solo SSH)
# - SSH crypto endurecido (Kex/Ciphers/MACs modernos)
# - chrony NTS endurecido
# - default target multi-user
# - opción de deshabilitar servicios innecesarios (cups, avahi, bluetooth, rpcbind, systemd-resolved)
#
# Uso:
#   chmod +x debian13-cis-hardening.sh
#   sudo ./debian13-cis-hardening.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Carga librería común
# shellcheck source=/dev/null
. "${SCRIPT_DIR}/lib/common.sh"

# Carga módulos en orden
# shellcheck source=/dev/null
. "${SCRIPT_DIR}/modules/00-packages.sh"
# shellcheck source=/dev/null
. "${SCRIPT_DIR}/modules/10-kernel-cmdline-modprobe.sh"
# shellcheck source=/dev/null
. "${SCRIPT_DIR}/modules/20-auth-policy.sh"
# shellcheck source=/dev/null
. "${SCRIPT_DIR}/modules/30-auditd.sh"
# shellcheck source=/dev/null
. "${SCRIPT_DIR}/modules/40-file-perms.sh"
# shellcheck source=/dev/null
. "${SCRIPT_DIR}/modules/50-sysctl.sh"
# shellcheck source=/dev/null
. "${SCRIPT_DIR}/modules/60-nftables.sh"
# shellcheck source=/dev/null
. "${SCRIPT_DIR}/modules/70-ssh.sh"
# shellcheck source=/dev/null
. "${SCRIPT_DIR}/modules/80-chrony.sh"
# shellcheck source=/dev/null
. "${SCRIPT_DIR}/modules/90-services-final.sh"

main() {
  require_root
  require_apt

  # Timestamp global para backups
  timestamp="$(date +%Y%m%d-%H%M%S)"
  export timestamp

  step_00_packages
  step_10_kernel_cmdline_and_modprobe
  step_20_auth_policy
  step_30_auditd
  step_40_file_perms
  step_50_sysctl
  step_60_nftables
  step_70_ssh
  step_80_chrony
  step_90_services_and_finalize
}

main "$@"
