# 20 – Fail2ban Hardening (Debian 13)

Configuración endurecida de **Fail2ban** para servidores Debian 13 (Trixie).  
Este módulo complementa a nftables proporcionando defensa activa frente a ataques de fuerza bruta, bots automatizados y tráfico abusivo.

La integración se realiza mediante **nftables** (no iptables), en cumplimiento de prácticas modernas de seguridad.

---

## 1. Objetivos

- Integrar Fail2ban con **nftables**, evitando iptables-legacy.  
- Proteger servicios críticos: SSH y (opcional) autenticación del sistema.  
- Minimizar falsos positivos manteniendo una respuesta agresiva ante bots.  
- Asegurar auditoría adecuada mediante logging estructurado.  
- Alinear configuraciones con CIS Debian Benchmark (sección 3.x + 5.x).

---

## 2. Instalación

```bash
apt install fail2ban
systemctl enable --now fail2ban
```

Comando de prueba:

```bash
fail2ban-client status
```

---

## 3. Configuración principal (`/etc/fail2ban/jail.local`)

### 3.1 Backend — obligatorio en Debian 13

```ini
backend = systemd
```

**Motivo:**  
Debian 13 utiliza journald como backend primario. Evita fallos del parser tradicional.

---

### 3.2 Parámetros globales recomendados

```ini
[DEFAULT]
bantime = 1h
findtime = 10m
maxretry = 3

banaction = nftables-multiport
banaction_allports = nftables-allports

ignoreip = 127.0.0.1/8 ::1
```

- `bantime` agresivo pero razonable para bots.  
- `maxretry=3` → estándar en entornos CIS.  
- `nftables-multiport` garantiza compatibilidad con la política DROP.

---

## 4. Jail SSH

Archivo: `/etc/fail2ban/jail.d/ssh.conf`

```ini
[sshd]
enabled = true
port = ssh
filter = sshd
logpath = journald
maxretry = 3
bantime = 1h
```

**Complemento nftables:** Fail2ban genera una cadena propia con los IPs bloqueados.

---

## 5. Reglas nftables generadas por Fail2ban

Ejemplo típico:

```nft
table ip fail2ban {
    chain sshd {
        type filter hook prerouting priority -100; policy accept;
        ip saddr { 192.168.1.100 } drop
    }
}
```

> *Nota:* fail2ban usa **tablas independientes**, no toca `inet filter`, lo cual mantiene aislamiento.

---

## 6. Logging y auditoría

### 6.1 Logging estructurado

```ini
logtarget = SYSLOG
syslogsocket = auto
```

### 6.2 Revisar baneos activos

```bash
fail2ban-client status sshd
```

### 6.3 Ver IPs bloqueadas

```bash
nft list ruleset | grep fail2ban
```

---

## 7. Medidas adicionales opcionales

### 7.1 Protección de autenticación local (pam-generic)

```ini
[pam-generic]
enabled = false  # Activar solo en servidores muy expuestos
logpath = /var/log/auth.log
maxretry = 5
bantime = 1h
```

### 7.2 Protección para Nginx/Apache

Se recomienda únicamente cuando el servidor exponga HTTP público:

```ini
[nginx-http-auth]
enabled = false
```

Fail2ban no está diseñado para proteger APIs bajo carga; usar con cautela.

---

## 8. Validación y pruebas

### 8.1 Probar expresiones del filtro

```bash
fail2ban-regex /var/log/auth.log /etc/fail2ban/filter.d/sshd.conf
```

### 8.2 Forzar un fake ban (prueba de firewall)

```bash
fail2ban-client set sshd banip 1.2.3.4
```

### 8.3 Ver el efecto en nftables

```bash
nft list ruleset | grep 1.2.3.4
```

---

## 9. Mapeo rápido a CIS Benchmark

| CIS Control | Implementación |
|-------------|----------------|
| 3.5.x       | Integración con nftables |
| 5.3.x       | Protección de autenticación |
| 5.4.x       | Auditoría de intentos fallidos |
| 5.2.x       | Refuerzo SSH (complemento al módulo 40) |

El mapeo completo aparecerá en `../cis/mapping-level2.md`.

---

## 10. Referencias

- CIS Debian Benchmark v1.1.0 – sección 3 y 5  
- Fail2ban Documentation  
- nftables Wiki  
- Debian Security Guide  
