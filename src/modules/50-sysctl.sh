#!/usr/bin/env bash

step_50_sysctl() {
  log_step "[8/12] Configurando sysctl hardening (Lynis + CIS + extra)..."

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
}
