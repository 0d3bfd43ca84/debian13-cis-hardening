# Changelog – Debian 13 CIS Hardening

Este documento sigue el formato *Keep a Changelog* y versionado semántico (SemVer).

---

## [1.0.0] – 2025-02-XX
### Initial Production Release

#### 📦 Nueva arquitectura modular
- Añadida estructura completa de documentación:
  - `00-overview.md`
  - `10-nftables.md`
  - `20-fail2ban.md`
  - `30-auditd.md`
  - `40-ssh-hardening.md`
  - `50-apparmor.md`
  - `60-kernel-tuning.md`
  - `cis/mapping-level2.md`

#### 🔐 Seguridad del sistema
- Creada baseline de nftables con:
  - Política por defecto DROP.
  - Bloqueo completo IPv6 (opcional).
  - Mitigación de scans (NULL, XMAS, SYN-FIN, SYN-RST).
  - Rate-limit SSH compatible con automatización.

- Integración Fail2ban → nftables (`harden_fail2ban_nft.sh`).

- Añadida configuración segura de auditd:
  - Reglas CIS 4.1.x completas.
  - Protección de identidad, privilegios, kernel, MAC policy y claves SSH.
  - Configuración de overflow segura (`keep_logs`, `halt_on_full`).

- Añadido hardening de kernel/sysctl:
  - Protección spoofing, redirects, source routing.
  - ASLR, ptrace_scope, kexec disabled, dmesg_restrict.
  - Hardlinks/symlinks protegidos.

#### 🔑 SSH Hardening
- Baseline moderna con:
  - Kex híbridos post-cuánticos (sntrup761x25519).
  - Ciphers seguros (chacha20-poly1305, aes256-gcm).
  - MACs ETM reforzados.
  - RootLogin deshabilitado, passwords deshabilitadas.
  - Logging VERBOSE.

#### 🛡 MAC Policy (AppArmor)
- Habilitación obligatoria de AppArmor al arranque.
- Reglas para enforcement y auditoría (`mac_policy`).

#### 🧰 Scripts
- Añadido script principal `debian13-cis-hardening.sh`.
- Integración modular con nftables, sysctl, auditd y SSH.

#### 📚 Documentación
- README.md completamente reescrito para alinearse con:
  - CIS Level 2
  - Producción y auditorías reales
  - Estructura modular del repositorio

#### 🏷 Metadata del repositorio
- Tagline profesional añadido:
  > Production-ready CIS Level 2 Hardening Baseline for Debian 13 (Server Edition)
- Topics optimizados para visibilidad en GitHub.

---

## [Unreleased]
- Hardening bootloader (GRUB) opcional.
- Compatibilidad avanzada IPv6 hardened.
- Perfil "High Security" opcional.
- Integración con Wazuh/Falco (opcional).
- Testing automatizado (serverspec/ansible).
---

