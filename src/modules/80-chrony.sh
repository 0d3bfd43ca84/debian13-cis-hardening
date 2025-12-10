#!/usr/bin/env bash

step_80_chrony() {
  log_step "[80] Configurando Chrony (NTS + hardening)..."

  local CHRONY_CONF="/etc/chrony/chrony.conf"
  local CHRONY_KEYS="/etc/chrony/chrony.keys"
  local CH_USER
  local CH_GROUP

  # Backup de configuración previa si existe
  if [[ -f "${CHRONY_CONF}" ]]; then
    echo "  -> Backup de ${CHRONY_CONF} en ${CHRONY_CONF}.bak.${timestamp}"
    cp "${CHRONY_CONF}" "${CHRONY_CONF}.bak.${timestamp}"
  fi

  mkdir -p /etc/chrony

  # Detectar usuario/grupo de chrony de forma robusta
  if [[ -d /var/lib/chrony ]]; then
    CH_USER="$(stat -c '%U' /var/lib/chrony 2>/dev/null || true)"
    CH_GROUP="$(stat -c '%G' /var/lib/chrony 2>/dev/null || true)"
  fi

  # Fallback si stat no dio nada útil
  if [[ -z "${CH_USER:-}" || "${CH_USER}" = "UNKNOWN" ]]; then
    if id -u chrony >/dev/null 2>&1; then
      CH_USER="chrony"
    elif id -u _chrony >/dev/null 2>&1; then
      CH_USER="_chrony"
    else
      CH_USER="root"
    fi
  fi

  if [[ -z "${CH_GROUP:-}" || "${CH_GROUP}" = "UNKNOWN" ]]; then
    if getent group chrony >/dev/null 2>&1; then
      CH_GROUP="chrony"
    elif getent group _chrony >/dev/null 2>&1; then
      CH_GROUP="_chrony"
    else
      CH_GROUP="root"
    fi
  fi

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

# Servidores Netnod (NTS)
server gbg1.nts.netnod.se  iburst nts maxdelay 0.3
server sth1.nts.netnod.se  iburst nts maxdelay 0.3
server svl1.nts.netnod.se  iburst nts maxdelay 0.3
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

  chown root:root "${CHRONY_CONF}"
  chmod 640 "${CHRONY_CONF}"

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

  if [[ ! -f "${CHRONY_KEYS}" ]]; then
    echo "  -> Creando fichero de claves ${CHRONY_KEYS}..."
    touch "${CHRONY_KEYS}"
  fi

  chown "${CH_USER}:root" "${CHRONY_KEYS}"
  chmod 0600 "${CHRONY_KEYS}"

  # Opcional: deshabilitar otros servicios NTP para evitar conflictos
  if systemctl list-unit-files systemd-timesyncd.service >/dev/null 2>&1; then
    systemctl disable --now systemd-timesyncd.service >/dev/null 2>&1 || true
  fi
  if systemctl list-unit-files ntp.service >/dev/null 2>&1; then
    systemctl disable --now ntp.service >/dev/null 2>&1 || true
  fi

  echo "  -> Habilitando y reiniciando chrony.service..."
  systemctl enable chrony.service >/dev/null 2>&1 || true
  systemctl restart chrony.service || true

  echo "  -> Estado de chrony:"
  systemctl --no-pager --full status chrony.service || true

  # Comandos de verificación solo si chronyc está disponible
  if command -v chronyc >/dev/null 2>&1; then
    echo "  -> Esperando muestras NTS..."
    sleep 8
    chronyc tracking || true
    chronyc sources -v || true
  fi
}
