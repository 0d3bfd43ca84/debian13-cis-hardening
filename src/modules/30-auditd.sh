#!/usr/bin/env bash

step_30_auditd() {
  log_step "[5/12] Ajustando /etc/audit/auditd.conf..."

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

  log_step "[6/12] Creando reglas auditd en /etc/audit/rules.d/..."

  RULES_DIR="/etc/audit/rules.d"
  mkdir -p "$RULES_DIR"

  UID_MIN=$(awk '/^UID_MIN/ {print $2}' /etc/login.defs 2>/dev/null || echo 1000)

  cat >"$RULES_DIR/50-scope.rules" <<'EOF'
-w /etc/sudoers -p wa -k scope
-w /etc/sudoers.d -p wa -k scope
EOF

  cat >"$RULES_DIR/50-user_emulation.rules" <<EOF
-a always,exit -F arch=b64 -C euid!=uid -F auid!=unset -S execve -k user_emulation
-a always,exit -F arch=b32 -C euid!=uid -F auid!=unset -S execve -k user_emulation
EOF

  cat >"$RULES_DIR/50-sudo.rules" <<'EOF'
-w /var/log/sudo.log -p wa -k sudo_log_file
EOF

  cat >"$RULES_DIR/50-time-change.rules" <<'EOF'
-a always,exit -F arch=b64 -S adjtimex,settimeofday -k time-change
-a always,exit -F arch=b32 -S adjtimex,settimeofday -k time-change
-a always,exit -F arch=b64 -S clock_settime -F a0=0x0 -k time-change
-a always,exit -F arch=b32 -S clock_settime -F a0=0x0 -k time-change
-w /etc/localtime -p wa -k time-change
EOF

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

  cat >"$RULES_DIR/50-access.rules" <<EOF
-a always,exit -F arch=b64 -S creat,open,openat,truncate,ftruncate -F exit=-EACCES -F auid>=$UID_MIN -F auid!=unset -k access
-a always,exit -F arch=b64 -S creat,open,openat,truncate,ftruncate -F exit=-EPERM  -F auid>=$UID_MIN -F auid!=unset -k access
EOF

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

  cat >"$RULES_DIR/50-perm_mod.rules" <<EOF
-a always,exit -F arch=b64 -S chmod,fchmod,fchmodat -F auid>=$UID_MIN -F auid!=unset -k perm_mod
-a always,exit -F arch=b64 -S chown,lchown,fchown,fchownat -F auid>=$UID_MIN -F auid!=unset -k perm_mod
-a always,exit -F arch=b64 -S setxattr,lsetxattr,fsetxattr,removexattr,lremovexattr,fremovexattr -F auid>=$UID_MIN -F auid!=unset -k perm_mod
EOF

  cat >"$RULES_DIR/50-mounts.rules" <<EOF
-a always,exit -F arch=b64 -S mount -F auid>=$UID_MIN -F auid!=unset -k mounts
EOF

  cat >"$RULES_DIR/50-session.rules" <<'EOF'
-w /var/run/utmp -p wa -k session
-w /var/log/wtmp -p wa -k session
-w /var/log/btmp -p wa -k session
EOF

  cat >"$RULES_DIR/50-login.rules" <<'EOF'
-w /var/log/lastlog -p wa -k logins
-w /var/run/faillock -p wa -k logins
EOF

  cat >"$RULES_DIR/50-delete.rules" <<EOF
-a always,exit -F arch=b64 -S rename,unlink,unlinkat,renameat -F auid>=$UID_MIN -F auid!=unset -k delete
EOF

  cat >"$RULES_DIR/50-MAC-policy.rules" <<'EOF'
-w /etc/apparmor/ -p wa -k MAC-policy
-w /etc/apparmor.d/ -p wa -k MAC-policy
EOF

  cat >"$RULES_DIR/50-perm_chng.rules" <<EOF
-a always,exit -F path=/usr/bin/setfacl -F perm=x -F auid>=$UID_MIN -F auid!=unset -k perm_chng
-a always,exit -F path=/usr/bin/chacl   -F perm=x -F auid>=$UID_MIN -F auid!=unset -k perm_chng
EOF

  cat >"$RULES_DIR/50-usermod.rules" <<EOF
-a always,exit -F path=/usr/sbin/usermod -F perm=x -F auid>=$UID_MIN -F auid!=unset -k usermod
EOF

  cat >"$RULES_DIR/50-kernel_modules.rules" <<EOF
-a always,exit -F arch=b64 -S init_module,delete_module,finit_module -F auid>=$UID_MIN -F auid!=unset -k kernel_modules
-a always,exit -F path=/usr/bin/kmod -F perm=x -F auid>=$UID_MIN -F auid!=unset -k kernel_modules
EOF

  cat >"$RULES_DIR/99-finalize.rules" <<'EOF'
-e 2
EOF

  chmod 640 "$RULES_DIR"/*.rules
}
