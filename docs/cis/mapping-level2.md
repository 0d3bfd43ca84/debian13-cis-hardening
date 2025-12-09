# CIS Debian Benchmark – Mapping Level 2
Este documento mapea cada control relevante del **CIS Debian Linux Benchmark (Level 2)** con la implementación realizada en esta baseline de hardening para Debian 13.

Los controles se agrupan por secciones:  
1.x – Configuración inicial del sistema  
2.x – Servicios  
3.x – Red y firewall  
4.x – Auditoría y logging  
5.x – Acceso y autenticación  
6.x – Configuración del sistema  
7.x – Scripts y automatización

---

# 1 – Configuración inicial del sistema

| CIS ID | Descripción | Implementado en | Estado |
|-------|-------------|-----------------|--------|
| 1.1.x | Permisos en ficheros críticos del sistema | 60-kernel-tuning / configuración base Debian | ✔ |
| 1.3.x | Banner legal | 40-ssh-hardening.md | ✔ |
| 1.4.1 | Asegurar bootloader | Requiere configuración opcional (no incluida por defecto) | ◐ |
| 1.6.x | Habilitar MAC (AppArmor) | 50-apparmor.md | ✔ |
| 1.7.x | Configuración de acciones automáticas | No aplicable para servidores minimalistas | N/A |

---

# 2 – Servicios

| CIS ID | Descripción | Implementado en | Estado |
|-------|-------------|-----------------|--------|
| 2.1.x | Deshabilitar servicios innecesarios | A elección del usuario (cups, avahi, bluetooth, rpcbind…) | ✔ / opcional |
| 2.2.1 | Solo servidores autoritativos deben activar NTP | 60-kernel-tuning + configuración chrony | ✔ |
| 2.2.2 | Configuración segura de NTP | chrony + NTS (externo al CIS) | ✔+ |

---

# 3 – Configuración de red y firewall

| CIS ID | Descripción | Implementado en | Estado |
|-------|-------------|-----------------|--------|
| 3.1.x | Configuración de red básica segura | 60-kernel-tuning | ✔ |
| 3.2.x | Spoofing, redirects, source routing | 60-kernel-tuning | ✔ |
| 3.3.x | Configuración de IPv6 | 10-nftables + 60-kernel-tuning | ✔ |
| 3.4.x | Firewall obligatorio | 10-nftables.md | ✔ |
| 3.5.1 | Política por defecto DROP | 10-nftables.md | ✔ |
| 3.5.2 | Configuración explícita de puertos | 10-nftables.md | ✔ |
| 3.6.x | Logging del firewall | 10-nftables.md (opcional) | ✔ / opcional |

---

# 4 – Logging y auditoría

| CIS ID | Descripción | Implementado en | Estado |
|-------|-------------|-----------------|--------|
| 4.1.1 | Activar auditoría en el kernel | 30-auditd.md | ✔ |
| 4.1.2 | Asegurar configuración de auditd | 30-auditd.md | ✔ |
| 4.1.3 | Auditoría de identidad | 30-auditd.md | ✔ |
| 4.1.4 | Auditoría de accesos a ficheros críticos | 30-auditd.md | ✔ |
| 4.1.5 | Cambios en kernel y sysctl | 30-auditd.md | ✔ |
| 4.1.6 | Auditoría de módulos del kernel | 30-auditd.md | ✔ |
| 4.1.7 | Uso de privilegios (sudo, su) | 30-auditd.md | ✔ |
| 4.1.8 | Auditoría de montajes | 30-auditd.md | ✔ |
| 4.1.9 | Acceso a claves privadas | 30-auditd.md | ✔ |
| 4.1.10 | Cambios de hora del sistema | 30-auditd.md | ✔ |
| 4.1.15 | MAC policy (AppArmor) | 50-apparmor.md / 30-auditd.md | ✔ |
| 4.2.x | Configuración de logging del sistema | journald + defaults Debian | ✔ |

---

# 5 – Acceso y autenticación

| CIS ID | Descripción | Implementado en | Estado |
|-------|-------------|-----------------|--------|
| 5.1.x | Hardening SSH | 40-ssh-hardening.md | ✔ |
| 5.2.x | Configuración de PAM | Política de contraseñas (script general) | ✔ |
| 5.3.x | Control de privilegios (sudo) | auditd + permisos reforzados | ✔ |
| 5.4.x | Password aging | Script de hardening principal | ✔ |
| 5.5.x | Configuración de cuentas inactivas | Script principal (opcional) | ◐ |
| 5.6.x | Control de sesiones y login | 40-ssh-hardening.md | ✔ |

---

# 6 – Configuración del sistema

| CIS ID | Descripción | Implementado en | Estado |
|-------|-------------|-----------------|--------|
| 6.1.x | Permisos en ficheros del sistema | 60-kernel-tuning + Debian defaults | ✔ |
| 6.2.x | Cron jobs y permisos | script principal | ✔ |
| 6.3.x | Seguridad del kernel | 60-kernel-tuning.md | ✔ |
| 6.4.x | Protección contra cargadores inseguros | 60-kernel-tuning.md | ✔ |

---

# 7 – Scripts y automatización

| CIS ID | Descripción | Implementado en | Estado |
|-------|-------------|-----------------|--------|
| 7.1.x | Asegurar scripts del sistema | Script principal | ✔ |
| 7.2.x | Integración con automatización | Hardening compatible con Ansible | ✔ |

---

# Estado general de cumplimiento

| Categoría | Cumplimiento estimado |
|-----------|------------------------|
| Configuración base del sistema | ✔ 100% |
| Firewall y red | ✔ 100% |
| SSH | ✔ 100% |
| Auditoría y logging | ✔ 100% |
| PAM y autenticación | ✔ ~95% (depende de políticas del usuario) |
| Bootloader y seguridad de arranque | ◐ 50% (pendiente por no aplicarse por defecto) |

---

# Notas

- El **bootloader hardening** no se aplica automáticamente para evitar dejar sistemas inaccesibles, por lo que su control se marca como **parcial**.  
- Algunos controles CIS no son aplicables a servidores minimalistas Debian 13 (escritorios, servicios innecesarios, impresión, etc.).  
- El nivel de cumplimiento exacto puede verificarse mediante:

```
lynis audit system
```

---

# Referencias

- CIS Debian Benchmark v1.1.0  
- Debian Security Guide  
- Más detalles en los módulos individuales del directorio `docs/`.
