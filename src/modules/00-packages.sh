#!/usr/bin/env bash

step_00_packages() {
  log_step "[1/12] Instalando paquetes necesarios ..."

  DEBIAN_FRONTEND=noninteractive apt-get update -y >/dev/null
  DEBIAN_FRONTEND=noninteractive apt-get install -y \
    apparmor apparmor-utils \
    auditd audispd-plugins \
    chrony \
    libpam-tmpdir \
    libpam-pwquality \
    nftables \
    fail2ban >/dev/null
}
