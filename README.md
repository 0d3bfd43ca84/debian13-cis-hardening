Debian 13 CIS Hardening – Production Grade (2025) 🔒🐧

Script de hardening para servidores Debian 13 diseñado para proporcionar una base segura, estable y auditable.
Alineado con las recomendaciones del CIS Debian Linux Benchmark v2.0.1, incrementa el Hardening Index de Lynis y refuerza la superficie de ataque del sistema para entornos exigentes.

✨ Características principales
🔐 Seguridad del sistema

AppArmor activado y reforzado

auditd + reglas CIS 4.1.x

sysctl hardening (kernel + red) con medidas adicionales tipo PCI/ISO

Permisos reforzados en sshd_config, sudoers.d, cron y ficheros críticos

🔑 SSH Hardening

Protocol 2

Kex modernos:
sntrup761x25519-sha512@openssh.com, curve25519-sha256

Ciphers seguros:
chacha20-poly1305@openssh.com, aes256-gcm@openssh.com

MACs modernos (modo ETM)

Compatible con OpenSSH 9.x

Resultado esperado: SSH moderno y resistente a ataques criptográficos conocidos.

🔥 Firewall nftables (baseline segura)

Política por defecto: DROP

IPv6 completamente bloqueado

Conntrack endurecido

Detección de scans (NULL, XMAS, SYN-FIN, SYN-RST)

Rate-limit en SSH → seguro pero compatible con Ansible

🧰 Política de contraseñas y cuentas
Componente	Configuración
pwquality	minlen 12, difok 3
Password aging	180 días, aviso 30
umask	027 global
pam_unix	sha512 + rounds cuando aplica
🕒 Sincronización horaria segura

Chrony con NTS (Network Time Security)

Servidores Netnod + Cloudflare

Parámetros estrictos de jitter, distancia y sampleo

Tiempo seguro → logs fiables → auditorías felices.

🚫 Servicios innecesarios (opcional)

Durante la ejecución se pregunta si deseas deshabilitar:

cups

avahi-daemon

bluetooth

rpcbind

systemd-resolved

Ideal para entornos minimalistas o de alta exposición.

🎯 Objetivos del script

Alinear el sistema con CIS Debian Benchmark v2.0.1 (orientado a Level 2)

Elevar el Hardening Index de Lynis (generalmente >80–90)

Reducir la superficie de ataque en servidores VPS / bare-metal

Crear una base técnica compatible con marcos como PCI-DSS o ISO 27001
(nota: no sustituye una auditoría oficial)

⚠️ Advertencias importantes

Este script está pensado para servidores dedicados.

Puede romper:

contenedores Docker/Podman

snaps

escritorios gráficos

máquinas que dependan de overlay/squashfs/usb-storage

Ejecutar solo si:

Tienes consola de rescate o acceso físico

Has leído el script completo

Aceptas que desactiva IPv6 y bloquea módulos críticos

🚀 Instalación y uso
git clone https://github.com/tuusuario/debian-cis-hardening-2025.git
cd debian-cis-hardening-2025
chmod +x cis_hardening_base.sh
sudo ./cis_hardening_base.sh
