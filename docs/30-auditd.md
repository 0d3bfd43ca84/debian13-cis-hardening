
Este documento define la configuración reforzada de **auditd** para servidores Debian 13.  
Incluye ajustes del demonio, reglas recomendadas y alineación con los controles CIS (sección 4.1.x).

La auditoría del sistema es obligatoria en entornos con requisitos de trazabilidad, cumplimiento o análisis forense.

---

## 1. Objetivos

- Registrar eventos críticos del sistema (autenticación, cambios de permisos, accesos a claves, modificaciones en políticas, uso de privilegios).
- Cumplir controles CIS 4.1.x.
- Garantizar que auditd se ejecuta desde el arranque y no puede ser deshabilitado sin dejar rastro.
- Preservar logs en situaciones de overflow mediante políticas estrictas.
- Minimizar falsos positivos manteniendo trazabilidad completa.

---

## 2. Instalación

```bash
apt install auditd audispd-plugins
systemctl enable --now auditd
```

Verificar estado:

```bash
auditctl -s
```

---

## 3. Configuración del demonio (`/etc/audit/auditd.conf`)

Se aplican valores CIS y buenas prácticas:

```ini
log_file = /var/log/audit/audit.log
log_format = RAW
flush = INCREMENTAL_ASYNC
freq = 50

max_log_file = 50
max_log_file_action = keep_logs
space_left_action = email
action_mail_acct = root
admin_space_left_action = halt
disk_full_action = halt
disk_error_action = halt
```

### Rationale:
- **keep_logs** evita sobrescritura (CIS).  
- **halt** ante disco lleno → comportamiento seguro y rastreable.  
- **freq=50** → rendimiento adecuado sin perder eventos.  

---

## 4. Reglas de auditoría (CIS 4.1.x)

Las reglas deben almacenarse en:

```
/etc/audit/rules.d/50-hardening.rules
```

La numeración 50– asegura precedencia sin interferir con reglas del sistema.

---

## 5. Conjunto principal de reglas (CIS)

### 5.1 Modificación de identidad y grupos (CIS 4.1.3)

```audit
-w /etc/group -p wa -k identity
-w /etc/passwd -p wa -k identity
-w /etc/gshadow -p wa -k identity
-w /etc/shadow -p wa -k identity
-w /etc/security/opasswd -p wa -k identity
```

---

### 5.2 Acceso no autorizado a archivos críticos (CIS 4.1.4)

```audit
-w /etc/sudoers -p wa -k scope
-w /etc/sudoers.d -p wa -k scope
-w /var/log/sudo.log -p wa -k actions
```

---

### 5.3 Modificación del kernel y sysctl (CIS 4.1.5)

```audit
-w /etc/sysctl.conf -p wa -k sysctl
-w /etc/sysctl.d -p wa -k sysctl
-w /boot -p wa -k boot
```

---

### 5.4 Actividad de modprobe y carga de módulos (CIS 4.1.6)

```audit
-w /usr/sbin/modprobe -p x -k modules
-w /bin/kmod -p x -k modules
```

---

### 5.5 Uso de privilegios (sudo, su) (CIS 4.1.7)

```audit
-w /bin/su -p x -k priv_esc
-w /usr/bin/sudo -p x -k priv_esc
-w /usr/bin/sudoedit -p x -k priv_esc
```

---

### 5.6 Cambios en hora del sistema (CIS 4.1.10)

```audit
-w /etc/localtime -p wa -k time_change
-a always,exit -F arch=b64 -S adjtimex,settimeofday,clock_settime -k time_change
```

---

### 5.7 Monitoreo de accesos a claves privadas (CIS 4.1.9)

```audit
-w /etc/ssh/ssh_host_key -p wa -k ssh_keys
-w /etc/ssh/ssh_host_* -p wa -k ssh_keys
```

---

### 5.8 Auditoría de procesos privilegiados (CIS 4.1.14)

```audit
-a always,exit -F arch=b64 -S execve -C uid!=euid -k privileges
```

---

### 5.9 Montajes de filesystem (CIS 4.1.8)

```audit
-a always,exit -F arch=b64 -S mount -k mounts
```

---

### 5.10 Manipulación de MAC policy (AppArmor) (CIS 4.1.15)

```audit
-w /etc/apparmor -p wa -k mac_policy
-w /etc/apparmor.d -p wa -k mac_policy
```

---

### 5.11 Desactivación de auditd (CIS 4.1.1)

Protección al arranque:

```
/etc/default/grub
```

Debe incluir:

```ini
GRUB_CMDLINE_LINUX="audit=1"
```

Aplicar:

```bash
update-grub
```

---

## 6. Activar reglas

```bash
augenrules --load
systemctl restart auditd
```

Verificar:

```bash
auditctl -l
```

---

## 7. Validación y uso

### 7.1 Buscar eventos por clave (ejemplo)

```bash
ausearch -k identity
```

### 7.2 Ver resumen de actividad

```bash
aureport
```

### 7.3 Monitorizar en tiempo real

```bash
tail -f /var/log/audit/audit.log
```

---

## 8. Mapeo rápido a CIS Benchmark

| CIS Control | Implementación |
|-------------|----------------|
| 4.1.1       | auditd habilitado desde el arranque |
| 4.1.2–4.1.15 | Reglas completas auditadas |
| 5.x         | Auditoría complementaria de autenticación |
| 1.x         | Trazabilidad de cambios en configuraciones críticas |

El mapeo completo se documentará en `../cis/mapping-level2.md`.

---

## 9. Referencias

- CIS Debian Benchmark v1.1.0 – sección 4.1  
- Auditd Documentation  
- Linux Audit Framework Notes  
