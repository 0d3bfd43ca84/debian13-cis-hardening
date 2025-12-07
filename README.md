# Debian 13 CIS Hardening – Production Grade (2025) 🔒🐧

Script de hardening para **servidores Debian 13** diseñado para proporcionar una **base segura, estable y auditable**.  
Alineado con las recomendaciones del **CIS Debian Linux Benchmark v2.0.1**, incrementa el **Hardening Index de Lynis** y refuerza la superficie de ataque del sistema para entornos exigentes.

---

## ✨ Características principales

### 🔐 Seguridad del sistema

- **AppArmor** activado y reforzado  
- **auditd + reglas CIS 4.1.x**  
- **sysctl hardening** (kernel y red) con medidas adicionales tipo PCI/ISO  
- Restricciones de permisos en `sshd_config`, `sudoers.d`, cron y ficheros sensibles  

---

### 🔑 SSH Hardening

- **Protocol 2**  
- **Kex modernos:**  
  `sntrup761x25519-sha512@openssh.com`, `curve25519-sha256`
- **Ciphers seguros:**  
  `chacha20-poly1305@openssh.com`, `aes256-gcm@openssh.com`
- **MACs ETM modernos**  
- Compatible con **OpenSSH 9.x**  

Resultado esperado: **SSH moderno, seguro y resistente a ataques criptográficos conocidos**.

---

### 🔥 Firewall nftables (baseline segura)

- Política por defecto: **DROP**  
- **IPv6 completamente bloqueado**  
- **Conntrack endurecido**  
- Detección y bloqueo de scans (NULL, XMAS, SYN-FIN, SYN-RST)  
- Rate-limit en SSH → seguro **pero compatible con Ansible**

---

### 🧰 Política de contraseñas y cuentas

| Componente          | Configuración                     |
|---------------------|-----------------------------------|
| pwquality           | minlen 12, difok 3                |
| Password aging      | maxdays 180, warndays 30          |
| umask               | 027 para todos los usuarios       |
| pam_unix            | sha512 + rounds cuando aplica     |

---

### 🕒 Sincronización horaria segura

- **Chrony con NTS (Network Time Security)**  
- Servidores **Netnod** + **Cloudflare**  
- Hardening adicional: jitter, distancia, muestras mínimas y rate-limit  

---

### 🚫 Servicios innecesarios (opcional)

Durante la ejecución se ofrece deshabilitar:

- `cups`  
- `avahi-daemon`  
- `bluetooth`  
- `rpcbind`  
- `systemd-resolved`  

Ideal para servidores minimalistas o con alta exposición en Internet.

---

## 🎯 Objetivos del script

- Alinear el sistema con **CIS Debian Benchmark v2.0.1 – Level 2**  
- Elevar el **Hardening Index de Lynis** (habitualmente **>80–90**)  
- Reducir superficie de ataque en entornos VPS / bare-metal  
- Servir como base para auditorías **PCI-DSS / ISO 27001**  
  *(no sustituye una auditoría formal)*

---

## ⚠️ Advertencias importantes

Este script está diseñado para **servidores dedicados**.  
Puede romper o inutilizar:

- contenedores Docker/Podman  
- snaps  
- escritorios gráficos  
- sistemas que dependan de overlay/squashfs/usb-storage  

Ejecutar solo si:

- Tienes **consola de rescate o acceso físico**  
- Has leído el script completo  
- Aceptas que **bloquea módulos críticos y desactiva IPv6**

---

## 🚀 Instalación y uso

```bash
git clone https://github.com/tuusuario/debian-cis-hardening-2025.git
cd debian-cis-hardening-2025
chmod +x cis_hardening_base.sh
sudo ./cis_hardening_base.sh
