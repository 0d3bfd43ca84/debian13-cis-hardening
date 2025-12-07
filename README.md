Debian 13 CIS Hardening – Production Grade (2025) 🔒🐧

Script de hardening para servidores Debian 13 diseñado para ofrecer una base segura, estable y auditable.
Su objetivo es acercar el sistema a las recomendaciones del CIS Debian Linux Benchmark v2.0.1, mejorar el Hardening Index de Lynis, y proporcionar una configuración lista para entornos serios de producción.

✨ Características principales

Este script aplica endurecimiento sobre:

🔐 Seguridad del sistema

AppArmor activado y reforzado

auditd + reglas CIS 4.1.x

sysctl hardening (kernel/network) con medidas adicionales tipo PCI/ISO

Restricciones de permisos en SSHD, sudoers.d, cron y ficheros sensibles

🛡️ SSH Hardening

Protocol 2 forzado

Kex modernos: sntrup761x25519, curve25519-sha256

Ciphers seguros: chacha20-poly1305, aes256-gcm

MACs ETM modernos

Compatible con OpenSSH 9.x (cliente/servidor)

🔥 Firewall nftables (baseline segura)

Política por defecto DROP

IPv6 totalmente bloqueado

Conntrack endurecido

Detección y bloqueo de scans (NULL, XMAS, SYN-FIN, SYN-RST)

Rate-limit en SSH → seguro pero compatible con Ansible

🔑 Política de contraseñas y cuentas

pwquality (minlen 12, difok 3)

Password aging: 180 días, aviso 30 días

umask 027 para todos los usuarios

pam_unix con hashing sha512 + rounds si procede

🕒 Sincronización horaria segura

Chrony configurado con NTS (Network Time Security)

Servidores Netnod + Cloudflare

Hardening del motor NTP (limitación de jitter, delay y samples)

🚫 Servicios innecesarios (opcional)

Preguntas interactivas para deshabilitar y maskear:

cups

avahi-daemon

bluetooth

rpcbind

systemd-resolved

👊 Protección adicional

BPF JIT hardened

Protección ARP (announce/ignore)

ASLR forzado

dmesg restringido

mmap_min_addr endurecido

Core dumps de SUID deshabilitados

🎯 Objetivos

Alinear el sistema con prácticas del CIS Debian Benchmark v2.0.1 (orientado a Level 2)

Aumentar el Hardening Index de Lynis típicamente por encima de 80–90, según rol del servidor

Reducir superficie de ataque en servidores bare-metal y VPS

Proveer una base técnica compatible con entornos auditables (PCI-DSS / ISO 27001)
(Nota: este script no sustituye una auditoría formal ni otros controles organizativos.)

⚠️ Advertencia importante

Este script está diseñado para servidores dedicados.
Podría romper:

contenedores (Docker/Podman)

sistemas con snaps

escritorios GNOME/KDE

hosts que dependan de overlay/squashfs/usb-storage

Ejecutar solo si:

Tienes acceso físico o consola de rescate

Has leído y entendido el código completo

Aceptas que deshabilita módulos críticos y bloquea IPv6

🚀 Instalación y uso
git clone https://github.com/tuusuario/debian-cis-hardening-2025.git
cd debian-cis-hardening-2025
chmod +x cis_hardening_base.sh
sudo ./cis_hardening_base.sh
