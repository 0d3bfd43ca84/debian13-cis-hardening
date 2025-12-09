#!/usr/bin/env bash

step_10_kernel_cmdline_and_modprobe() {
  log_step "[2/12] Configurando parámetros de kernel en /etc/default/grub..."

  GRUB_DEFAULT_FILE="/etc/default/grub"
  if [[ ! -f "$GRUB_DEFAULT_FILE" ]]; then
    echo "No existe $GRUB_DEFAULT_FILE, abortando." >&2
    exit 1
  fi

  # shellcheck source=/etc/default/grub
  source "$GRUB_DEFAULT_FILE"

  CURRENT_CMDLINE="${GRUB_CMDLINE_LINUX:-}"

  REQUIRED_PARAMS=(
    "apparmor=1"
    "security=apparmor"
    "audit=1"
    "audit_backlog_limit=8192"
  )

  NEW_CMDLINE="$CURRENT_CMDLINE"

  for p in "${REQUIRED_PARAMS[@]}"; do
    if [[ " $NEW_CMDLINE " != *" $p "* ]]; then
      NEW_CMDLINE="${NEW_CMDLINE} ${p}"
    fi
  done

  NEW_CMDLINE="$(echo "$NEW_CMDLINE" | xargs || true)"

  if grep -qE '^GRUB_CMDLINE_LINUX=' "$GRUB_DEFAULT_FILE"; then
    sed -i "s|^GRUB_CMDLINE_LINUX=.*|GRUB_CMDLINE_LINUX=\"${NEW_CMDLINE}\"|" "$GRUB_DEFAULT_FILE"
  else
    echo "GRUB_CMDLINE_LINUX=\"${NEW_CMDLINE}\"" >> "$GRUB_DEFAULT_FILE"
  fi

  echo "  -> GRUB_CMDLINE_LINUX=\"${NEW_CMDLINE}\""
  echo "  -> Ejecutando update-grub..."
  update-grub >/dev/null

  if [[ -f /boot/grub/grub.cfg ]]; then
    echo "[2b/12] Ajustando permisos de /boot/grub/grub.cfg..."
    chown root:root /boot/grub/grub.cfg
    chmod u=rw,go= /boot/grub/grub.cfg
  fi

  log_step "[3/12] Creando /etc/modprobe.d/cis-kernel-hardening.conf..."

  cat >/etc/modprobe.d/cis-kernel-hardening.conf <<'EOF'
########################################################################
# CIS KERNEL HARDENING — DEBIAN
# Filesystems y protocolos de red no utilizados.
########################################################################

###############################
# 1.1.1 — Filesystem modules
###############################

# 1.1.1.1 cramfs
blacklist cramfs
install cramfs /bin/true

# 1.1.1.2 freevxfs
blacklist freevxfs
install freevxfs /bin/true

# 1.1.1.3 hfs
blacklist hfs
install hfs /bin/true

# 1.1.1.4 hfsplus
blacklist hfsplus
install hfsplus /bin/true

# 1.1.1.5 jffs2
blacklist jffs2
install jffs2 /bin/true

# 1.1.1.6 overlay
# Desbloquear si se usan contenedores (docker/podman).
blacklist overlay
install overlay /bin/true

# 1.1.1.7 squashfs
# Desbloquear si se usan snaps o imágenes squashfs.
blacklist squashfs
install squashfs /bin/true

# 1.1.1.8 udf
blacklist udf
install udf /bin/true

# 1.1.1.9 usb-storage
# Desbloquear si se requieren discos USB en este host.
blacklist usb-storage
install usb-storage /bin/true

#########################################
# 3.2.x — Uncommon network protocols
#########################################

# 3.2.1 dccp
blacklist dccp
install dccp /bin/true

# 3.2.2 tipc
blacklist tipc
install tipc /bin/true

# 3.2.3 rds
blacklist rds
install rds /bin/true

# 3.2.4 sctp
blacklist sctp
install sctp /bin/true
EOF

  echo "  -> Actualizando initramfs..."
  update-initramfs -u >/dev/null
}
