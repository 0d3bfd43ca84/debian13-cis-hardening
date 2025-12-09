# Debian 13 Hardening – Production Grade (2025) 🔒🐧

Hardening baseline para servidores Debian 13 (Trixie), diseñada para entornos de alta seguridad, auditorías formales y despliegues en producción.  
Alineada con CIS Debian Benchmark (Level 2) y reforzada con medidas adicionales inspiradas en PCI-DSS, ISO 27001 y prácticas modernas de seguridad.

Este repositorio incluye:
- Scripts de hardening listos para producción.
- Configuración auditd, nftables, SSH y sysctl.
- Documentación técnica y mapeo a CIS Benchmark.

---

## ✨ Características principales

### 🔐 Seguridad del sistema
- AppArmor activado y reforzado.  
- auditd + reglas alineadas con CIS 4.1.x  
- Endurecimiento sysctl para red y kernel  
- Permisos reforzados en:
  - `/etc/ssh/sshd_config`
  - `/etc/sudoers.d/`
  - `/etc/cron.*`
  - Ficheros sensibles de sistema  

---

### 🔑 SSH Hardening
- Protocol 2 únicamente  
- Kex modernos:  
  `sntrup761x25519-sha512@openssh.com`, `curve25519-sha256`  
- Ciphers seguros:  
  `chacha20-poly1305@openssh.com`, `aes256-gcm@openssh.com`  
- MACs ETM reforzados  
- Compatibilidad garantizada con OpenSSH ≥ 9.x  

**Resultado:** configuración SSH resistente frente a ataques criptográficos actuales y legacy downgrade attacks.

---

### 🔥 Firewall nftables (baseline segura)
- Política por defecto: `DROP`  
- IPv6 completamente bloqueado  
- Conntrack endurecido  
- Mitigación de scans: NULL / XMAS / SYN-FIN / SYN-RST  
- Rate-limit inteligente para SSH (compatible con Ansible)

---

### 🧰 Política de contraseñas y cuentas

| Componente       | Configuración |
|------------------|---------------|
| pwquality        | minlen 12, difok 3 |
| Password aging   | maxdays 180, warndays 30 |
| umask            | 027 global |
| pam_unix         | sha512 + rounds cuando aplica |

---

### 🕒 Sincronización horaria segura
- Chrony con NTS (Network Time Security)  
- Servidores: Netnod + Cloudflare  
- Hardening adicional: jitter, distancia, selección estricta de muestras, rate-limit  

---

### 🚫 Servicios innecesarios (opcional)
El script permite deshabilitar con seguridad:

- `cups`
- `avahi-daemon`
- `bluetooth`
- `rpcbind`
- `systemd-resolved`

Ideal para servidores minimalistas o expuestos a Internet.

---

## 🎯 Objetivos del proyecto
- Alinear Debian 13 con **CIS Level 2 – Server**  
- Elevar Hardening Index de Lynis (normalmente > 80–90)  
- Reducir superficie de ataque en VPS / bare-metal  
- Servir como base para auditorías PCI-DSS / ISO 27001  
> *No sustituye una auditoría formal.*

---

## ⚠️ Advertencias importantes

Este hardening está diseñado **solo para servidores dedicados**.  
Puede romper servicios como:

- Contenedores Docker/Podman  
- Snaps  
- Escritorios gráficos  
- Sistemas que dependan de:
  - overlayfs
  - squashfs
  - usb-storage  
  - IPv6

**Ejecutar únicamente si:**
- Dispones de acceso físico o consola de rescate  
- Has leído y entendido el script  
- Aceptas el bloqueo de módulos y desactivación total de IPv6  

---

## 🚀 Instalación y uso

```bash
git clone https://github.com/tuusuario/debian-cis-hardening-2025.git
cd debian-cis-hardening-2025
chmod +x cis_hardening_base.sh
sudo ./cis_hardening_base.sh
```

---

## 📁 Estructura del repositorio

```
/
├── docs/
│   ├── ssh-hardening.md
│   ├── nftables-baseline.md
│   ├── auditd-rules.md
│   ├── sysctl-hardening.md
│   └── cis/ (mapeo a CIS Benchmark)
├── src/
│   ├── firewall/
│   ├── auditd/
│   ├── ssh/
│   └── system/
├── cis_hardening_base.sh
├── LICENSE
├── SECURITY.md
└── README.md
```

---

## 📘 Referencias

- **CIS Benchmark for Debian Linux 12 v1.1.0**  
- *Debian Administrator’s Handbook*  
- AppArmor Documentation  
- OpenSSH Security Guidelines  
- *draft-ietf-ntp-using-nts-for-ntp*

---

## 📌 Roadmap
- [ ] Compatibilidad parcial con sistemas dual-stack IPv6  
- [ ] Versión “workstation” (menos restrictiva)  
- [ ] Integración automática con Falco / Wazuh  
- [ ] Scripts de revert / rollback  

---

## 📄 Licencia
GPL-3.0 License  
