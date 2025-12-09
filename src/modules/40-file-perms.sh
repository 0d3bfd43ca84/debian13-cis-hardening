#!/usr/bin/env bash

step_40_file_perms() {
  log_step "[7/12] Ajustando permisos de sshd_config, cron y sudoers.d..."

  if [[ -f /etc/ssh/sshd_config ]]; then
    chown root:root /etc/ssh/sshd_config
    chmod u=rw,go= /etc/ssh/sshd_config
  fi

  if [[ -f /etc/crontab ]]; then
    chown root:root /etc/crontab
    chmod u=rw,go= /etc/crontab
  fi

  for d in /etc/cron.hourly /etc/cron.daily /etc/cron.weekly /etc/cron.monthly /etc/cron.d; do
    if [[ -d "$d" ]]; then
      chown root:root "$d"
      chmod 700 "$d"
    fi
  done

  if [[ -d /etc/sudoers.d ]]; then
    chown root:root /etc/sudoers.d
    chmod 750 /etc/sudoers.d
  fi
}
