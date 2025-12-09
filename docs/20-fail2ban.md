# Fail2Ban + nftables — Hardening para Debian 13

Integración avanzada entre Fail2Ban y nftables diseñada para entornos de alta seguridad: servidores Debian, nodos Bitcoin, infra crítica y sistemas expuestos a Internet.  
El objetivo es implementar un **drop temprano**, eficiente y consistente con CIS Level 2.

---

## 1. Objetivos del sistema

- Protección anti-bruteforce robusta para SSH
- Integración Fail2Ban → nftables mediante sets dinámicos
- Baja carga sobre journald y CPU
- Compatibilidad con despliegues automatizados
- Auditoría completa (si auditd está habilitado)

---

## 2. Arquitectura

SSH → journald → Fail2Ban → acción nft → set blacklist → DROP temprano

Fail2Ban detecta accesos fallidos y añade la IP atacante al set dinámico `blacklist`.  
nftables descarta paquetes antes del handshake SSH.

---

## 3. Requisitos

```bash
apt install fail2ban nftables
systemctl enable --now nftables
```

## 4. Configuración nftables

Crear /etc/nftables-f2b.conf:
````bash table inet f2b {
    set blacklist {
        type ipv4_addr
        timeout 24h
        flags timeout
    }

    set blacklist6 {
        type ipv6_addr
        timeout 24h
        flags timeout
    }

    chain input {
        type filter hook input priority -5;

        ip  saddr @blacklist  drop
        ip6 saddr @blacklist6 drop
    }
}
````

Incluirlo desde /etc/nftables.conf:
````bash
include "/etc/nftables-f2b.conf"
````

Aplicar:
````bash
nft -f /etc/nftables.conf
````

## 5. Acción Fail2Ban personalizada

Crear /etc/fail2ban/action.d/nftables.conf:
````bash
[Definition]
actionstart = nft add table inet f2b 2>/dev/null || true

actionban   = nft add element inet f2b blacklist { <ip> timeout <bantime>s }
actionunban = nft delete element inet f2b blacklist { <ip> }

[Init]
nftables_family = inet
nftables_table  = f2b
nftables_set    = blacklist
````

## 6. jail.local recomendado

Archivo /etc/fail2ban/jail.local:

````bash
[DEFAULT]
backend   = systemd
banaction = nftables
bantime   = 3600
findtime  = 600
maxretry  = 5

[sshd]
enabled = true
port    = ssh
logpath = %(sshd_log)s
````
Validacion
````bash
fail2ban-client -t
systemctl restart fail2ban
````

## 8. Hardening SSH complementario

MaxAuthTries 3

AllowUsers <usuario>

Deshabilitar autenticación por contraseña cuando sea posible

AppArmor para /usr/sbin/sshd

Registros auditd activados para execve y sudo

## 9. Conclusión

La combinación Fail2Ban → nftables reduce el coste de mitigación de ataques SSH hasta niveles mínimos.
Es la solución recomendada para Debian 13 en entornos críticos con exposición pública.
