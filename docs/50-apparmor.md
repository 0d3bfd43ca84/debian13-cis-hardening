
AppArmor es el mecanismo MAC (Mandatory Access Control) por defecto en Debian 13.  
Este módulo describe cómo reforzar AppArmor, habilitar perfiles estrictos y cumplir los controles CIS relacionados con MAC (sección 1.x y 4.1.x).

El objetivo es limitar el impacto de compromisos locales y reducir la superficie de ataque de servicios expuestos.

---

## 1. Objetivos

- Garantizar que AppArmor está habilitado al arranque.
- Asegurar que todos los perfiles cargados operan en modo **enforce**, no complain.  
- Activar perfiles adicionales para servicios comunes.  
- Auditar modificaciones y eventos relevantes mediante auditd.  
- Mantener una configuración compatible con el resto del hardening del sistema.

---

## 2. Verificación del estado de AppArmor

```bash
aa-status
```

Salida esperada:

- AppArmor **enabled**
- Perfiles cargados en **enforce mode**
- 0 perfiles en complain (o lo mínimo posible)

---

## 3. Habilitar AppArmor desde GRUB

Archivo: `/etc/default/grub`

Debe contener:

```ini
GRUB_CMDLINE_LINUX="apparmor=1 security=apparmor"
```

Aplicar cambios:

```bash
update-grub
reboot
```

---

## 4. Cargar perfiles recomendados

Debian 13 incluye perfiles por defecto situados en:

```
/etc/apparmor.d/
```

Activar todo lo disponible:

```bash
sudo apparmor_parser -r /etc/apparmor.d/*
```

---

## 5. Comprobación de perfiles en complain mode

Listarlos:

```bash
aa-status --complaining
```

Convertirlos a **enforce**:

```bash
aa-enforce /etc/apparmor.d/<perfil>
```

---

## 6. Perfiles recomendados para servidores

Dependiendo del rol, se recomienda activar:

### 6.1 Systemd-Resolved (si está habilitado)

```bash
aa-enforce /etc/apparmor.d/usr.lib.systemd.systemd-resolved
```

### 6.2 Nginx

```bash
aa-enforce /etc/apparmor.d/usr.sbin.nginx
```

### 6.3 OpenSSH Server

```bash
aa-enforce /etc/apparmor.d/usr.sbin.sshd
```

### 6.4 Chrony

```bash
aa-enforce /etc/apparmor.d/usr.sbin.chronyd
```

### 6.5 System tools

```bash
aa-enforce /etc/apparmor.d/usr.bin.man
aa-enforce /etc/apparmor.d/usr.bin.ping
```

> Ajustar según servicios instalados.

---

## 7. Creación de overrides locales

Para ajustes específicos:

```
/etc/apparmor.d/local/<perfil>
```

Ejemplo:

```bash
echo "/etc/myapp/** r," >> /etc/apparmor.d/local/usr.sbin.nginx
apparmor_parser -r /etc/apparmor.d/usr.sbin.nginx
```

---

## 8. Integración con auditd

AppArmor genera eventos MAC relevantes.  
Asegurar que auditd registra cambios de política (CIS 4.1.15):

Regla incluida en 30-auditd.md:

```audit
-w /etc/apparmor -p wa -k mac_policy
-w /etc/apparmor.d -p wa -k mac_policy
```

Ver eventos:

```bash
ausearch -k mac_policy
```

---

## 9. Logs de AppArmor

```bash
journalctl -t apparmor
```

Errores relacionados con denials se registran como:

```
AVC apparmor="DENIED"
```

Utilizar para ajustar perfiles en modo enforce.

---

## 10. Validación

### 10.1 Confirmar que no quedan perfiles en complain

```bash
aa-status | grep complain
```

Salida deseada: vacío.

### 10.2 Probar perfiles individualmente

```bash
aa-complain /etc/apparmor.d/usr.sbin.nginx
aa-enforce /etc/apparmor.d/usr.sbin.nginx
```

---

## 11. Mapeo rápido a CIS Benchmark

| CIS Control | Implementación |
|-------------|----------------|
| 1.6.x       | MAC policy habilitada y reforzada |
| 4.1.15      | Auditoría de cambios en AppArmor |
| 5.x         | Aislamiento de servicios críticos |
| 3.x         | Complemento a firewall + servicios reducidos |

El mapeo completo aparecerá en `../cis/mapping-level2.md`.

---

## 12. Referencias

- CIS Debian Benchmark v1.1.0 – sección 1.6 y 4.1.15  
- AppArmor Documentation  
- Debian Security Guide  

