#!/usr/bin/env bash

step_40_file_perms() {
  log_step "[40] Ajustando permisos de ficheros y directorios sensibles..."

  # --- SSH --------------------------------------------------------
  if [[ -f /etc/ssh/sshd_config ]]; then
    chown root:root /etc/ssh/sshd_config
    chmod 600 /etc/ssh/sshd_config
  fi

  # Directorio de configs adicionales de SSH (si existe)
  if [[ -d /etc/ssh/sshd_config.d ]]; then
    chown root:root /etc/ssh/sshd_config.d
    chmod 750 /etc/ssh/sshd_config.d
    # Ficheros dentro: legibles solo por root o root:root 640
    find /etc/ssh/sshd_config.d -type f -exec chown root:root {} \; -exec chmod 640 {} \; 2>/dev/null || true
  fi

  # --- Cron / Anacron ---------------------------------------------
  if [[ -f /etc/crontab ]]; then
    chown root:root /etc/crontab
    chmod 600 /etc/crontab
  fi

  if [[ -f /etc/anacrontab ]]; then
    chown root:root /etc/anacrontab
    chmod 600 /etc/anacrontab
  fi

  # Directorios cron.*
  for d in /etc/cron.hourly /etc/cron.daily /etc/cron.weekly /etc/cron.monthly /etc/cron.d; do
    if [[ -d "$d" ]]; then
      chown root:root "$d"
      chmod 700 "$d"
    fi
  done

  # Ficheros cron.allow / cron.deny
  if [[ -f /etc/cron.allow ]]; then
    chown root:root /etc/cron.allow
    chmod 600 /etc/cron.allow
  fi

  if [[ -f /etc/cron.deny ]]; then
    chown root:root /etc/cron.deny
    chmod 600 /etc/cron.deny
  fi

  # Ficheros at.allow / at.deny
  if [[ -f /etc/at.allow ]]; then
    chown root:root /etc/at.allow
    chmod 600 /etc/at.allow
  fi

  if [[ -f /etc/at.deny ]]; then
    chown root:root /etc/at.deny
    chmod 600 /etc/at.deny
  fi

  # --- sudoers ----------------------------------------------------
  if [[ -f /etc/sudoers ]]; then
    chown root:root /etc/sudoers
    chmod 440 /etc/sudoers
  fi

  if [[ -d /etc/sudoers.d ]]; then
    chown root:root /etc/sudoers.d
    chmod 750 /etc/sudoers.d
    # Ficheros dentro: 440 root:root
    find /etc/sudoers.d -type f -exec chown root:root {} \; -exec chmod 440 {} \; 2>/dev/null || true
  fi

  # --- Bases de cuentas del sistema -------------------------------
  if [[ -f /etc/passwd ]]; then
    chown root:root /etc/passwd
    chmod 644 /etc/passwd
  fi

  if [[ -f /etc/group ]]; then
    chown root:root /etc/group
    chmod 644 /etc/group
  fi

  if [[ -f /etc/shadow ]]; then
    chown root:shadow /etc/shadow 2>/dev/null || chown root:root /etc/shadow
    chmod 640 /etc/shadow
  fi

  if [[ -f /etc/gshadow ]]; then
    chown root:shadow /etc/gshadow 2>/dev/null || chown root:root /etc/gshadow
    chmod 640 /etc/gshadow
  fi
}
