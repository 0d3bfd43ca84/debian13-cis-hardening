#!/usr/bin/env bash
#
# Instalación y configuración básica de AIDE alineada con CIS
# Probado para Debian 12/13 con AIDE 0.19

set -euo pipefail

AIDE_CONF="/etc/aide/aide.conf"
AIDE_DB_DIR="/var/lib/aide"
CRON_JOB="/etc/cron.daily/aide"

if [ "$(id -u)" -ne 0 ]; then
    echo "Este script debe ejecutarse como root."
    exit 1
fi

echo "[+] Instalando paquetes necesarios (aide, mailx)..."
apt-get update -y
apt-get install -y aide aide-common bsd-mailx

echo "[+] Haciendo copia de seguridad de configuración AIDE previa (si existe)..."
if [ -f "$AIDE_CONF" ]; then
    cp -a "$AIDE_CONF" "${AIDE_CONF}.$(date +%Y%m%d%H%M%S).bak"
fi

echo "[+] Escribiendo configuración AIDE alineada con CIS en $AIDE_CONF..."

cat >"$AIDE_CONF" <<'EOF'
# ======================================================
# AIDE - Configuración base alineada con CIS
# Debian 12/13 - AIDE 0.19
# ======================================================

# Bases de datos
database_in=file:/var/lib/aide/aide.db
database_out=file:/var/lib/aide/aide.db.new
gzip_dbout=yes

# ------------------------------------------------------
# REGLAS
# ------------------------------------------------------

# Regla general para binarios / librerías del sistema
NORMAL = p+i+n+u+g+s+m+c+acl+xattrs+sha512

# Regla para ficheros de configuración (no esperamos cambios de permisos/owner a menudo)
CONFIG = p+i+n+u+g+m+c+acl+xattrs+sha512

# Regla estricta (por si se usa en algo puntual)
STRICT = p+i+n+u+g+s+m+c+acl+xattrs+sha512

# ------------------------------------------------------
# ÁRBOLES DEL SISTEMA (CRÍTICOS)
# ------------------------------------------------------

# Configuración del sistema
/etc                    CONFIG

# Binarios y librerías del sistema
/bin                    NORMAL
/sbin                   NORMAL
/usr/bin                NORMAL
/usr/sbin               NORMAL
/usr/lib                NORMAL

# Bootloader y kernel
/boot                   NORMAL

# Directorio root (scripts/admin)
/root                   CONFIG

# SSH (muy sensible)
/etc/ssh                CONFIG
/var/lib/ssh            CONFIG

# ------------------------------------------------------
# ZONAS A IGNORAR (ALTA VOLATILIDAD / POCAS GARANTÍAS)
# ------------------------------------------------------

# Directorios de usuario y temporales
!/home
!/tmp
!/var/tmp

# Logs, cachés y colas
!/var/log
!/var/cache
!/var/spool

# Áreas volátiles del sistema
!/run
!/var/run
!/dev
!/proc
!/sys

# Montajes externos / removibles
!/media
!/mnt

# Basura de fs
!/lost+found

# ------------------------------------------------------
# CASOS ESPECIALES DE SISTEMA
# ------------------------------------------------------

# Seguimiento de estado de los paquetes instalados
/var/lib/dpkg/status        CONFIG

# Ignoramos detalles finos de info (demasiado ruido)
!/var/lib/dpkg/info
EOF

chmod 600 "$AIDE_CONF"

echo "[+] Inicializando base de datos AIDE..."
mkdir -p "$AIDE_DB_DIR"

# Generar base de datos inicial
aide -c "$AIDE_CONF" --init

if [ ! -f "${AIDE_DB_DIR}/aide.db.new" ]; then
    echo "[-] ERROR: no se ha generado ${AIDE_DB_DIR}/aide.db.new. Revisa la salida de AIDE."
    exit 1
fi

mv "${AIDE_DB_DIR}/aide.db.new" "${AIDE_DB_DIR}/aide.db"
chmod 600 "${AIDE_DB_DIR}/aide.db"

echo "[+] Creando tarea diaria de integridad en $CRON_JOB..."

cat >"$CRON_JOB" <<'EOF'
#!/bin/sh

AIDE_BIN="/usr/bin/aide"
AIDE_CONF="/etc/aide/aide.conf"
HOSTNAME="$(hostname)"

# Ejecutar check de integridad
REPORT="$($AIDE_BIN -c "$AIDE_CONF" --check 2>&1)"
RET=$?

# Enviar siempre informe a root (correo local)
/usr/bin/printf "%s\n" "$REPORT" | /usr/bin/mail -s "AIDE integrity check [$HOSTNAME] (exit=$RET)" root

# Registrar en syslog
/usr/bin/logger -t AIDE "Daily integrity check finished with exit code $RET"

exit 0
EOF

chmod 700 "$CRON_JOB"

echo "[+] Prueba rápida: ejecutando check manual..."
aide -c "$AIDE_CONF" --check || true

echo
echo "[OK] AIDE instalado, configurado e inicializado."
echo "    - Config:     $AIDE_CONF"
echo "    - DB:         ${AIDE_DB_DIR}/aide.db"
echo "    - Cron daily: $CRON_JOB"
echo
echo "Los informes diarios se enviarán al buzón local de root (/var/mail/root)."
