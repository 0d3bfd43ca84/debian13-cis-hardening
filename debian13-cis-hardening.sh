#!/usr/bin/env bash
#
# cis_hardening_base.sh
# Hardening base CIS + Lynis para Debian 13:
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
#   chmod +x cis_hardening_base.sh
#   sudo ./cis_hardening_base.sh

set -euo pipefail

### ============================================================
### 0. Comprobaciones iniciales
### ============================================================

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Este script debe ejecutarse como root." >&2
  exit 1
fi

if ! command -v apt-get >/dev/null 2>&1; then
  echo "Este script está pensado para Debian/derivados con apt-get." >&2
  exit 1
fi

timestamp="$(date +%Y%m%d-%H%M%S)"

### ============================================================
### 1. Paquetería requerida
### ============================================================

echo "[1/11] Instalando paquetes necesarios (AppArmor, auditd, chrony, nftables, libpam-tmpdir, libpam-pwquality, fail2ban)..."
DEBIAN_FRONTEND=noninteractive apt-get update -y >/dev/null
DEBIAN_FRONTEND=noninteractive apt-get install -y \
  apparmor apparmor-utils \
  auditd audispd-plugins \
  chrony \
  libpam-tmpdir \
  libpam-pwquality \
  nftables >/dev/null

### ============================================================
### 2. Kernel cmdline: AppArmor + audit
### ============================================================

echo "[2/11] Configurando parámetros de kernel en /etc/default/grub..."

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

# Permisos de /boot/grub/grub.cfg según CIS
if [[ -f /boot/grub/grub.cfg ]]; then
  echo "[2b/12] Ajustando permisos de /boot/grub/grub.cfg..."
  chown root:root /boot/grub/grub.cfg
  chmod u=rw,go= /boot/grub/grub.cfg
fi

### ============================================================
### 3. Módulos de kernel: cis-kernel-hardening.conf
### ============================================================

echo "[3/11] Creando /etc/modprobe.d/cis-kernel-hardening.conf..."

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

### ============================================================
### 4. sudo: log dedicado (CIS 5.2.3)
### ============================================================

echo "[4/11] Configurando log dedicado de sudo..."

SUDO_CIS_FILE="/etc/sudoers.d/01-cis-sudo-log"

mkdir -p /etc/sudoers.d

cat >"$SUDO_CIS_FILE" <<'EOF'
Defaults logfile="/var/log/sudo.log"
EOF

chmod 440 "$SUDO_CIS_FILE"
chown root:root "$SUDO_CIS_FILE"

# Validar configuración sudoers
if ! visudo -cf /etc/sudoers >/dev/null 2>&1; then
  echo "ERROR: Configuración sudoers inválida tras añadir $SUDO_CIS_FILE." >&2
  exit 1
fi

touch /var/log/sudo.log
chown root:root /var/log/sudo.log
chmod 600 /var/log/sudo.log

### ============================================================
### 4b. Política de contraseñas (pwquality, aging, umask, rounds)
### ============================================================

echo "[4b/11] Reforzando política de contraseñas (pwquality + aging + umask + hashing rounds)..."

COMMON_PASSWORD="/etc/pam.d/common-password"
LOGIN_DEFS="/etc/login.defs"

# 4b.1 pwquality: complejidad de contraseñas
if [[ -f "$COMMON_PASSWORD" ]]; then
  if ! grep -q "pam_pwquality.so" "$COMMON_PASSWORD"; then
    sed -i '/pam_unix.so/i password   requisite   pam_pwquality.so retry=3 minlen=12 difok=3' "$COMMON_PASSWORD"
  fi

  # 4b.2 Hashing rounds (solo si se usa sha512 y no hay rounds definidos)
  if grep -q "pam_unix.so" "$COMMON_PASSWORD"; then
    if grep -q "sha512" "$COMMON_PASSWORD" && ! grep -q "rounds=" "$COMMON_PASSWORD"; then
      sed -i 's/\(pam_unix.so.*sha512\)/\1 rounds=100000/' "$COMMON_PASSWORD"
    fi
  fi
fi

# 4b.3 Password aging por defecto
if [[ -f "$LOGIN_DEFS" ]]; then
  sed -i 's/^PASS_MAX_DAYS.*/PASS_MAX_DAYS   180/' "$LOGIN_DEFS" || true
  sed -i 's/^PASS_MIN_DAYS.*/PASS_MIN_DAYS   1/'   "$LOGIN_DEFS" || true
  sed -i 's/^PASS_WARN_AGE.*/PASS_WARN_AGE   30/'  "$LOGIN_DEFS" || true
fi

# Ajustar aging en usuarios “reales” (UID >= UID_MIN y shell de login)
UID_MIN=$(awk '/^UID_MIN/ {print $2}' /etc/login.defs 2>/dev/null || echo 1000)
while IFS=: read -r name _ uid _ _ _ shell; do
  if (( uid >= UID_MIN )) && [[ "$shell" != "/usr/sbin/nologin" && "$shell" != "/bin/false" ]]; then
    chage --mindays 1 --maxdays 180 --warndays 30 "$name" 2>/dev/null || true
  fi
done < /etc/passwd

# 4b.4 Default umask
if [[ -f "$LOGIN_DEFS" ]]; then
  sed -i 's/^UMASK.*/UMASK 027/' "$LOGIN_DEFS" || true
fi

mkdir -p /etc/profile.d
cat >/etc/profile.d/01-umask.sh <<'EOF'
umask 027
EOF
chmod 644 /etc/profile.d/01-umask.sh

### ============================================================
### 5. auditd.conf — parámetros principales
### ============================================================

echo "[5/11] Ajustando /etc/audit/auditd.conf..."

AUDIT_CONF="/etc/audit/auditd.conf"

if [[ -f "$AUDIT_CONF" ]]; then
  sed -i -E 's/^\s*max_log_file\s*=.*/max_log_file = 16/' "$AUDIT_CONF"
  sed -i -E 's/^\s*max_log_file_action\s*=.*/max_log_file_action = keep_logs/' "$AUDIT_CONF"
  sed -i -E 's/^\s*disk_full_action\s*=.*/disk_full_action = single/' "$AUDIT_CONF"
  sed -i -E 's/^\s*disk_error_action\s*=.*/disk_error_action = single/' "$AUDIT_CONF"
  sed -i -E 's/^\s*space_left_action\s*=.*/space_left_action = email/' "$AUDIT_CONF"
  sed -i -E 's/^\s*admin_space_left_action\s*=.*/admin_space_left_action = single/' "$AUDIT_CONF"
else
  echo "WARN: No se encontró $AUDIT_CONF; auditd podría no estar configurado correctamente." >&2
fi

### ============================================================
### 6. Reglas de auditd (CIS 4.1.x)
### ============================================================

echo "[6/12] Creando reglas auditd en /etc/audit/rules.d/..."

RULES_DIR="/etc/audit/rules.d"
mkdir -p "$RULES_DIR"

UID_MIN=$(awk '/^UID_MIN/ {print $2}' /etc/login.defs 2>/dev/null || echo 1000)

# 50-scope.rules
cat >"$RULES_DIR/50-scope.rules" <<'EOF'
-w /etc/sudoers -p wa -k scope
-w /etc/sudoers.d -p wa -k scope
EOF

# 50-user_emulation.rules
cat >"$RULES_DIR/50-user_emulation.rules" <<EOF
-a always,exit -F arch=b64 -C euid!=uid -F auid!=unset -S execve -k user_emulation
-a always,exit -F arch=b32 -C euid!=uid -F auid!=unset -S execve -k user_emulation
EOF

# 50-sudo.rules
cat >"$RULES_DIR/50-sudo.rules" <<'EOF'
-w /var/log/sudo.log -p wa -k sudo_log_file
EOF

# 50-time-change.rules
cat >"$RULES_DIR/50-time-change.rules" <<'EOF'
-a always,exit -F arch=b64 -S adjtimex,settimeofday -k time-change
-a always,exit -F arch=b32 -S adjtimex,settimeofday -k time-change
-a always,exit -F arch=b64 -S clock_settime -F a0=0x0 -k time-change
-a always,exit -F arch=b32 -S clock_settime -F a0=0x0 -k time-change
-w /etc/localtime -p wa -k time-change
EOF

# 50-system_locale.rules
cat >"$RULES_DIR/50-system_locale.rules" <<'EOF'
-a always,exit -F arch=b64 -S sethostname,setdomainname -k system-locale
-a always,exit -F arch=b32 -S sethostname,setdomainname -k system-locale
-w /etc/issue -p wa -k system-locale
-w /etc/issue.net -p wa -k system-locale
-w /etc/hosts -p wa -k system-locale
-w /etc/networks -p wa -k system-locale
-w /etc/network/ -p wa -k system-locale
-w /etc/netplan/ -p wa -k system-locale
EOF

# 50-access.rules
cat >"$RULES_DIR/50-access.rules" <<EOF
-a always,exit -F arch=b64 -S creat,open,openat,truncate,ftruncate -F exit=-EACCES -F auid>=$UID_MIN -F auid!=unset -k access
-a always,exit -F arch=b64 -S creat,open,openat,truncate,ftruncate -F exit=-EPERM  -F auid>=$UID_MIN -F auid!=unset -k access
EOF

# 50-identity.rules
cat >"$RULES_DIR/50-identity.rules" <<'EOF'
-w /etc/group -p wa -k identity
-w /etc/passwd -p wa -k identity
-w /etc/gshadow -p wa -k identity
-w /etc/shadow -p wa -k identity
-w /etc/security/opasswd -p wa -k identity
-w /etc/nsswitch.conf -p wa -k identity
-w /etc/pam.conf -p wa -k identity
-w /etc/pam.d/ -p wa -k identity
EOF

# 50-perm_mod.rules
cat >"$RULES_DIR/50-perm_mod.rules" <<EOF
-a always,exit -F arch=b64 -S chmod,fchmod,fchmodat -F auid>=$UID_MIN -F auid!=unset -k perm_mod
-a always,exit -F arch=b64 -S chown,lchown,fchown,fchownat -F auid>=$UID_MIN -F auid!=unset -k perm_mod
-a always,exit -F arch=b64 -S setxattr,lsetxattr,fsetxattr,removexattr,lremovexattr,fremovexattr -F auid>=$UID_MIN -F auid!=unset -k perm_mod
EOF

# 50-mounts.rules
cat >"$RULES_DIR/50-mounts.rules" <<EOF
-a always,exit -F arch=b64 -S mount -F auid>=$UID_MIN -F auid!=unset -k mounts
EOF

# 50-session.rules
cat >"$RULES_DIR/50-session.rules" <<'EOF'
-w /var/run/utmp -p wa -k session
-w /var/log/wtmp -p wa -k session
-w /var/log/btmp -p wa -k session
EOF

# 50-login.rules
cat >"$RULES_DIR/50-login.rules" <<'EOF'
-w /var/log/lastlog -p wa -k logins
-w /var/run/faillock -p wa -k logins
EOF

# 50-delete.rules
cat >"$RULES_DIR/50-delete.rules" <<EOF
-a always,exit -F arch=b64 -S rename,unlink,unlinkat,renameat -F auid>=$UID_MIN -F auid!=unset -k delete
EOF

# 50-MAC-policy.rules
cat >"$RULES_DIR/50-MAC-policy.rules" <<'EOF'
-w /etc/apparmor/ -p wa -k MAC-policy
-w /etc/apparmor.d/ -p wa -k MAC-policy
EOF

# 50-perm_chng.rules
cat >"$RULES_DIR/50-perm_chng.rules" <<EOF
-a always,exit -F path=/usr/bin/setfacl -F perm=x -F auid>=$UID_MIN -F auid!=unset -k perm_chng
-a always,exit -F path=/usr/bin/chacl   -F perm=x -F auid>=$UID_MIN -F auid!=unset -k perm_chng
EOF

# 50-usermod.rules
cat >"$RULES_DIR/50-usermod.rules" <<EOF
-a always,exit -F path=/usr/sbin/usermod -F perm=x -F auid>=$UID_MIN -F auid!=unset -k usermod
EOF

# 50-kernel_modules.rules
cat >"$RULES_DIR/50-kernel_modules.rules" <<EOF
-a always,exit -F arch=b64 -S init_module,delete_module,finit_module -F auid>=$UID_MIN -F auid!=unset -k kernel_modules
-a always,exit -F path=/usr/bin/kmod -F perm=x -F auid>=$UID_MIN -F auid!=unset -k kernel_modules
EOF

# 99-finalize.rules
cat >"$RULES_DIR/99-finalize.rules" <<'EOF'
-e 2
EOF

chmod 640 "$RULES_DIR"/*.rules

### ============================================================
### 7. Permisos de ficheros críticos (sshd, cron, sudoers.d)
### ============================================================

echo "[7/11] Ajustando permisos de sshd_config, cron y sudoers.d..."

# /etc/ssh/sshd_config
if [[ -f /etc/ssh/sshd_config ]]; then
  chown root:root /etc/ssh/sshd_config
  chmod u=rw,go= /etc/ssh/sshd_config     # 600
fi

# /etc/crontab
if [[ -f /etc/crontab ]]; then
  chown root:root /etc/crontab
  chmod u=rw,go= /etc/crontab             # 600
fi

# cron.* directories
for d in /etc/cron.hourly /etc/cron.daily /etc/cron.weekly /etc/cron.monthly /etc/cron.d; do
  if [[ -d "$d" ]]; then
    chown root:root "$d"
    chmod 700 "$d"
  fi
done

# /etc/sudoers.d directory (Lynis)
if [[ -d /etc/sudoers.d ]]; then
  chown root:root /etc/sudoers.d
  chmod 750 /etc/sudoers.d
fi

### ============================================================
### 8. sysctl hardening (Lynis / CIS + extra)
### ============================================================

echo "[8/11] Configurando sysctl hardening (Lynis + CIS + extra)..."

cat >/etc/sysctl.d/99-hardening.conf <<'EOF'
###########################################
# LYNIS / CIS HARDENING — RED + KERNEL
###########################################

# Ocultar direcciones del kernel incluso a root
kernel.kptr_restrict = 2

# Desactivar SysRq
kernel.sysrq = 0

# ptrace limitado
kernel.yama.ptrace_scope = 1

# BPF no privilegiado desactivado
kernel.unprivileged_bpf_disabled = 1

# BPF JIT hardened
net.core.bpf_jit_harden = 2

# Anti-spoofing IPv4
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

# ICMP redirect protection
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0

# No enviar redirects
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0

# Log de paquetes anómalos
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1

###########################################
# EXTRA HARDENING (PCI/ISO-like)
###########################################

# ASLR siempre activo
kernel.randomize_va_space = 2

# Restringir dmesg a root
kernel.dmesg_restrict = 1

# Proteger mmap de null deref
vm.mmap_min_addr = 65536

# Proteger contra core dumps de SUID
fs.suid_dumpable = 0

# Protecciones de enlaces simbólicos/duros
fs.protected_hardlinks = 1
fs.protected_symlinks = 1
fs.protected_fifos = 1
fs.protected_regular = 2

# TCP stack hardening
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_rfc1337   = 1
net.ipv4.tcp_timestamps = 0
net.ipv4.tcp_sack       = 0

# No actuar como router
net.ipv4.ip_forward = 0
net.ipv6.conf.all.forwarding = 0

# ARP hardening
net.ipv4.conf.all.arp_ignore   = 2
net.ipv4.conf.all.arp_announce = 2

# Desactivar IPv6 si no se usa (firewall lo bloquea igualmente)
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
EOF

echo "  -> Aplicando sysctl --system..."
sysctl --system >/dev/null

### ============================================================
### 9. nftables: firewall base + conntrack + IPv6 DROP
### ============================================================

echo "[9/11] Configurando nftables (firewall base + conntrack + IPv6 DROP)..."

cat >/etc/nftables.conf <<'EOF'
flush ruleset

table inet firewall {

  chain input {
    type filter hook input priority 0;
    policy drop;

    # 0) IPv6 completamente deshabilitado (también está en sysctl)
    meta nfproto ipv6 drop

    # 1) Loopback siempre permitido
    iif "lo" accept

    # 2) Conntrack básico
    ct state invalid limit rate 5/minute burst 5 packets \
      log prefix "NFT INVALID: " counter drop
    ct state established,related accept

    # 3) ICMPv4 básico (necesario para que IPv4 funcione bien)
    ip protocol icmp icmp type {
      echo-request, echo-reply,
      destination-unreachable,
      time-exceeded,
      parameter-problem
    } accept

    # 4) Fragmentos raros
    ip frag-off & 0x1FFF != 0x0 limit rate 5/minute burst 5 packets \
      log prefix "NFT FRAG BLOQ: " counter drop

    # 5) Scans TCP típicos
    tcp flags == 0x0  limit rate 5/minute burst 5 packets \
      log prefix "NFT NULL SCAN: " counter drop

    tcp flags == 0xFF limit rate 5/minute burst 5 packets \
      log prefix "NFT XMAS SCAN: " counter drop

    tcp flags & (fin | syn) == fin | syn limit rate 5/minute burst 5 packets \
      log prefix "NFT SYN-FIN: " counter drop

    tcp flags & (syn | rst) == syn | rst limit rate 5/minute burst 5 packets \
      log prefix "NFT SYN-RST: " counter drop

    # 6) SSH (único puerto abierto por defecto)
    #    Limit más alto para no romper orquestación (Ansible, etc.)
    tcp dport 22 ct state new \
      limit rate 100/second burst 200 packets \
      counter accept

    # 7) Todo lo demás: drop (silencioso, con contador)
    counter drop
  }

  chain forward {
    type filter hook forward priority 0;
    policy drop;
  }

  chain output {
    type filter hook output priority 0;
    policy accept;
  }
}
EOF

systemctl enable nftables.service >/dev/null 2>&1 || true
systemctl restart nftables.service

echo "  -> nftables activo:"
nft list ruleset || true

### ============================================================
### 10. SSH hardening (Kex/Ciphers/MACs modernos)
### ============================================================

echo "[10/11] Endureciendo configuración de SSH (crypto moderna)..."

SSHD_CONF="/etc/ssh/sshd_config"
if [[ -f "$SSHD_CONF" ]]; then
  echo "  -> Backup de ${SSHD_CONF} en ${SSHD_CONF}.bak.${timestamp}"
  cp "$SSHD_CONF" "${SSHD_CONF}.bak.${timestamp}"

  # Eliminar líneas previas de crypto si existen
  sed -i '/^Ciphers /d;/^MACs /d;/^KexAlgorithms /d;/^Protocol /d' "$SSHD_CONF"

  cat >>"$SSHD_CONF" <<'EOF'

# ==== SSH CRYPTO HARDENED (cis_hardening_base.sh) ====
Protocol 2
KexAlgorithms sntrup761x25519-sha512@openssh.com,curve25519-sha256@libssh.org,curve25519-sha256
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes256-ctr
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com
EOF

  systemctl restart ssh || systemctl restart sshd || true
else
  echo "WARN: No se encontró ${SSHD_CONF}, no se aplica hardening SSH." >&2
fi

### ============================================================
### 11. Configuración de Chrony (NTS + hardening)
### ============================================================

echo "[11/11] Configurando Chrony (NTS + hardening)..."

CHRONY_CONF="/etc/chrony/chrony.conf"

if [[ -f "${CHRONY_CONF}" ]]; then
  echo "  -> Backup de ${CHRONY_CONF} en ${CHRONY_CONF}.bak.${timestamp}"
  cp "${CHRONY_CONF}" "${CHRONY_CONF}.bak.${timestamp}"
fi

mkdir -p /etc/chrony

# Determinar usuario/grupo de chrony
CH_USER="$(stat -c '%U' /var/lib/chrony 2>/dev/null || echo '_chrony')"
CH_GROUP="$(stat -c '%G' /var/lib/chrony 2>/dev/null || echo '_chrony')"

echo "  -> Usando usuario/grupo de Chrony: ${CH_USER}:${CH_GROUP}"

cat > "${CHRONY_CONF}" << 'EOF'
# ================================================
#  Network Time Security (NTS) – Debian 13
#  Perfil: Máxima Resiliencia (Hardening Completo)
# ================================================

# Estado del reloj
driftfile /var/lib/chrony/chrony.drift
makestep 1.0 3
rtcsync

# Servidores NTS oficiales (Netnod)
server gbg1.nts.netnod.se  iburst nts maxdelay 0.3
server sth1.nts.netnod.se  iburst nts maxdelay 0.3
server svl1.nts.netnod.se  iburst nts maxdelay 0.3

# Pool global Netnod
server nts.netnod.se       iburst nts maxdelay 0.3

# Cloudflare global
server time.cloudflare.com iburst nts maxdelay 0.1

# Política ANTI-DOWNGRADE
authselectmode require
minsources 2
ntsdumpdir /var/lib/chrony

# Filtros de calidad (Hardening)
maxjitter 0.03
maxdistance 0.5
minsamples 8
maxsamples 32
maxslewrate 1000

# Defensa contra flood
ratelimit interval 3 burst 3

# Rendimiento y estabilidad
maxupdateskew 100
bindcmdaddress /run/chrony/chronyd.sock
leapseclist /usr/share/zoneinfo/leap-seconds.list
keyfile /etc/chrony/chrony.keys

# Logging
log tracking measurements statistics
logdir /var/log/chrony

# Includes controlado
confdir /etc/chrony/conf.d
EOF

echo "  -> Preparando /var/lib/chrony..."
mkdir -p /var/lib/chrony
chown "${CH_USER}:${CH_GROUP}" /var/lib/chrony
chmod 0750 /var/lib/chrony

echo "  -> Preparando /var/log/chrony..."
mkdir -p /var/log/chrony
chown "${CH_USER}:${CH_GROUP}" /var/log/chrony
chmod 0750 /var/log/chrony

echo "  -> Preparando /etc/chrony/conf.d..."
mkdir -p /etc/chrony/conf.d
chown root:root /etc/chrony/conf.d
chmod 0755 /etc/chrony/conf.d

CHRONY_KEYS="/etc/chrony/chrony.keys"
if [[ ! -f "${CHRONY_KEYS}" ]]; then
  echo "  -> Creando fichero de claves ${CHRONY_KEYS}..."
  touch "${CHRONY_KEYS}"
fi

# Fichero de claves legible por chrony (usuario de chrony, grupo root)
chown "${CH_USER}:root" "${CHRONY_KEYS}"
chmod 0600 "${CHRONY_KEYS}"

echo "  -> Habilitando y reiniciando chrony.service..."
systemctl enable chrony.service >/dev/null 2>&1 || true
systemctl restart chrony.service

echo "  -> Estado de chrony:"
systemctl --no-pager --full status chrony.service || true

echo "  -> Esperando muestras NTS..."
sleep 8
chronyc tracking || true
chronyc sources -v || true

### ============================================================
### Servicios innecesarios (mask opcional)
### ============================================================

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

mask_service "cups"            "impresión local"
mask_service "avahi-daemon"    "mDNS/zeroconf (descubrimiento en LAN)"
mask_service "bluetooth"       "Bluetooth"
mask_service "rpcbind"         "RPC legacy (NFS antiguo, etc.)"
mask_service "systemd-resolved" "stub DNS local (solo si NO lo usas como resolver)"

### ============================================================
### Default target + auditd + resumen + reboot
### ============================================================

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
