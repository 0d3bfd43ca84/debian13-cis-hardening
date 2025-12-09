
Este módulo aplica una configuración endurecida de parámetros del kernel mediante **sysctl**.  
Incluye medidas del CIS Benchmark combinadas con recomendaciones adicionales para entornos de alta seguridad.

Los ajustes cubren:  
- Protección de red (IPv4/IPv6, spoofing, redirects, RFC compliance).  
- Kernel hardening (ptrace, kexec, dmesg restrictions).  
- Memoria y mitigaciones de explotación (ASLR).  
- Protección frente a SYN floods y tráfico malicioso.

---

## 1. Objetivos

- Reducir superficie de ataque a nivel de kernel.  
- Endurecer pila TCP/IP y evitar comportamientos inseguros por defecto.  
- Mitigar ataques de spoofing, redirects, SYN floods y scanning pasivo.  
- Activar restricciones adicionales de seguridad a procesos.  
- Deshabilitar mecanismos inseguros como kexec o ptrace sin control.

---

## 2. Ubicación de configuración

Ajustes persistentes:

```
/etc/sysctl.d/60-hardening.conf
```

El prefijo **60-** asegura orden lógico junto al resto del hardening.

Aplicación manual:

```bash
sysctl --system
```

---

## 3. Configuración sysctl recomendada

### 3.1 Protección contra spoofing

```conf
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
```

---

### 3.2 Deshabilitar ICMP redirects inseguros

```conf
net.ipv4.conf.all.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.default.secure_redirects = 0
```

---

### 3.3 Deshabilitar source routing

```conf
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0
```

---

### 3.4 Protección contra SYN floods

```conf
net.ipv4.tcp_syncookies = 1
```

---

### 3.5 Logging de paquetes sospechosos

```conf
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1
```

---

### 3.6 Forwarding (deshabilitado en servidores no router)

```conf
net.ipv4.ip_forward = 0
net.ipv6.conf.all.forwarding = 0
```

> Activar solo en servidores que realmente enrutan tráfico.

---

### 3.7 Deshabilitar IPv6 (si no se utiliza)

```conf
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
```

> Importante: coherente con política nftables (IPv6 DROP).

---

### 3.8 Restricciones de ptrace (CIS + hardening extra)

```conf
kernel.yama.ptrace_scope = 2
```

Valores:
- `2` → ptrace estrictamente limitado (recomendado).  
- `3` → aún más restrictivo (puede romper debugging).

---

### 3.9 Restringir acceso a dmesg

```conf
kernel.dmesg_restrict = 1
```

---

### 3.10 Endurecer ASLR

```conf
kernel.randomize_va_space = 2
```

---

### 3.11 Evitar uso no autorizado de kexec

```conf
kernel.kexec_load_disabled = 1
```

Mitigación relevante para entornos donde se previenen bypasses del bootloader.

---

### 3.12 Protección de enlaces simbólicos y hardlinks

```conf
fs.protected_hardlinks = 1
fs.protected_symlinks = 1
```

Mitiga ataques de escalada mediante manipulación de ficheros temporales.

---

### 3.13 Tiempo de espera TCP

```conf
net.ipv4.tcp_fin_timeout = 15
```

Reduce exhaustión de sockets.

---

### 3.14 Deshabilitar broadcast ping

```conf
net.ipv4.icmp_echo_ignore_broadcasts = 1
```

---

### 3.15 Rechazar RFC1918 mal formados

```conf
net.ipv4.conf.all.route_localnet = 0
```

---

## 4. Aplicar la configuración

```bash
sysctl --system
```

---

## 5. Verificación

```bash
sysctl -a | grep hardening
sysctl net.ipv4.conf.all.rp_filter
```

---

## 6. Compatibilidad y advertencias

- Puede afectar contenedores si se aplican valores globales en host.
- Algunos valores son innecesarios en entornos cloud con red virtualizada.
- Si usas IPv6, no debes activar `disable_ipv6 = 1`.

---

## 7. Mapeo rápido a CIS Benchmark

| CIS Control | Implementación |
|-------------|----------------|
| 3.x         | Protección IPv4/IPv6, spoofing y redirects |
| 4.x         | Restricciones de kernel y syscalls |
| 5.x         | Endurecimiento complementario a servicios |
| 1.x         | Seguridad base del sistema |

El mapeo completo aparecerá en `../cis/mapping-level2.md`.

---

## 8. Referencias

- CIS Debian Benchmark v1.1.0 (network + kernel sections)  
- Kernel.org Documentation – Sysctl  
- Debian Security Guide  
