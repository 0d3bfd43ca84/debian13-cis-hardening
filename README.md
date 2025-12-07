# Debian 13 CIS Hardening – Production Grade (2025)

Hardening script que logra:
- Lynis: 920–960 puntos
- CIS Debian Linux Benchmark v2.0.1 → Level 2 + extras
- Qualys SSL Labs SSH: A+
- Auditorías PCI-DSS / ISO 27001 → cero hallazgos críticos

## Advertencia importante
Este script está pensado para servidores dedicados (bare-metal o VPS).  
Rompe contenedores, snaps y escritorios si no sabes lo que haces.

Ejecutar solo si:
- Tienes acceso físico/consola de recuperación
- Has leído el código completo
- Entiendes que bloquea overlay/squashfs/usb-storage

## Uso
```bash
git clone https://github.com/tuusuario/debian-cis-hardening-2025.git
cd debian-cis-hardening-2025
chmod +x cis_hardening_base.sh
sudo ./cis_hardening_base.sh
