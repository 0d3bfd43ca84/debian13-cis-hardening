#!/usr/bin/env bash

require_root() {
  if [[ "$(id -u)" -ne 0 ]]; then
    echo "Este script debe ejecutarse como root." >&2
    exit 1
  fi
}

require_apt() {
  if ! command -v apt-get >/dev/null 2>&1; then
    echo "Este script está pensado para Debian/derivados con apt-get." >&2
    exit 1
  fi
}

log_step() {
  # $1: texto
  echo
  echo ">>> $1"
}
